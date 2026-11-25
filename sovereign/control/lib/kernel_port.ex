defmodule SovereignBeamMojo.KernelPort do
  @moduledoc """
  GenServer owning persistent, binary-framed Mojo worker Ports.

  One Port per worker, opened in `init/1` with
  `{:spawn_executable, bin}`, `[:binary, :exit_status,
  {:packet, 4}, args: ["--port"]]`. Erlang's `{:packet, 4}`
  adds the 4-byte big-endian length on send and strips it on
  receive, so the bytes on the wire are exactly the protocol
  in docs/PORT_PROTOCOL.md:

    request  = <<len::32-big, opcode::8, payload::binary>>
    response = <<len::32-big, status::8, payload::binary>>
    status 0 = ok, 1 = mismatch / error, 2 = worker error

  Workers:
  - `:field_ops` — opcodes 0x01 add, 0x02 mul, 0x03 neg.
    Payloads are 8-byte big-endian u64s; response is 8 bytes.
  - `:holo_verify` — opcode 0x10 verify. Payload is
    `<<path_len::16-big, path::binary, expected_hex::binary>>`
    (64 ASCII hex chars). Response is a 32-byte SHA-256 digest.

  One call per Port at a time; a second call to the same
  worker returns `{:error, :worker_busy}`. Each call has a
  5s timeout: on timeout the Port is closed, the caller gets
  `{:error, :worker_timeout}`, and the Port is reopened.
  On `{:exit_status, code}` the pending caller (if any) gets
  `{:error, {:worker_exited, code}}` and the Port is reopened.
  Control-plane state lives in ReceiptStore, not in the
  worker, so a restart loses no receipts.

  If a binary is missing (e.g. on this host, before
  `run_pipeline.sh` in the guest), calls return
  `{:error, :worker_not_available}` — never a fake success.
  """
  use GenServer

  @timeout 5_000
  @workers [:field_ops, :holo_verify]

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  # --- Public API: field ops (via :field_ops Port) ---

  @spec fp_add(non_neg_integer(), non_neg_integer()) :: {:ok, non_neg_integer()} | {:error, term()}
  def fp_add(a, b), do: GenServer.call(__MODULE__, {:fp, 0x01, <<a::64-big, b::64-big>>}, @timeout + 1_000)

  @spec fp_mul(non_neg_integer(), non_neg_integer()) :: {:ok, non_neg_integer()} | {:error, term()}
  def fp_mul(a, b), do: GenServer.call(__MODULE__, {:fp, 0x02, <<a::64-big, b::64-big>>}, @timeout + 1_000)

  @spec fp_neg(non_neg_integer()) :: {:ok, non_neg_integer()} | {:error, term()}
  def fp_neg(a), do: GenServer.call(__MODULE__, {:fp, 0x03, <<a::64-big>>}, @timeout + 1_000)

  @spec field_ops_self_test() :: {:ok, map()} | {:error, term()}
  def field_ops_self_test do
    p = 18_446_744_069_414_584_321

    checks = [
      {fn -> fp_mul(2, 3) end, 6},
      {fn -> fp_mul(1, p - 1) end, p - 1},
      {fn -> fp_mul(p - 1, p - 1) end, 1},
      {fn -> fp_mul(4_294_967_296, 4_294_967_296) end, 4_294_967_295},
      {fn -> fp_mul(123_456_789, 987_654_321) end, 121_932_631_112_635_269},
      {fn -> fp_add(p - 1, p - 1) end, p - 2},
      {fn -> fp_add(p - 1, 1) end, 0},
      {fn -> fp_neg(1) end, p - 1},
      {fn -> fp_neg(0) end, 0}
    ]

    Enum.reduce_while(checks, {:ok, %{checks: 9}}, fn {call, expected}, _acc ->
      case call.() do
        {:ok, ^expected} -> {:cont, {:ok, %{checks: 9}}}
        {:ok, got} -> {:halt, {:error, {:self_test_failed, expected, got}}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  # --- Public API: verify (via :holo_verify Port) ---

  @spec verify_artifact(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def verify_artifact(path, expected_hex)
      when is_binary(path) and is_binary(expected_hex) do
    cond do
      path == "" -> {:error, :invalid_input}
      byte_size(expected_hex) != 64 -> {:error, :invalid_input}
      true -> GenServer.call(__MODULE__, {:verify, path, expected_hex}, @timeout + 1_000)
    end
  end

  # --- Public API: raw framed call (for debugging / future opcodes) ---

  @spec call(atom(), byte(), binary()) :: {:ok, binary()} | {:error, term()}
  def call(worker, opcode, payload)
      when worker in @workers and is_integer(opcode) and is_binary(payload) do
    GenServer.call(__MODULE__, {:raw, worker, opcode, payload}, @timeout + 1_000)
  end

  # --- GenServer ---

  @impl true
  def init(opts) do
    bin_dir =
      Keyword.get(opts, :bin_dir) ||
        Application.get_env(:sovereign_beam_mojo, :kernel_bin_dir) ||
        default_bin_dir()

    ports =
      Map.new(@workers, fn worker ->
        {worker, open_port(bin_dir, worker)}
      end)

    {:ok, %{bin_dir: bin_dir, ports: ports, pending: %{}}}
  end

  # In a release the workers live in the app's priv dir
  # (lib/sovereign_beam_mojo-*/priv); in dev `mix run` from
  # control/ they live in control/priv. :code.priv_dir/1 finds
  # the first when it exists, otherwise fall back to "priv".
  defp default_bin_dir do
    case :code.priv_dir(:sovereign_beam_mojo) do
      {:error, _} -> "priv"
      dir -> to_string(dir)
    end
  end

  @impl true
  def handle_call({:fp, opcode, payload}, from, state) do
    send_framed(state, :field_ops, opcode, payload, :fp, from, %{})
  end

  def handle_call({:verify, path, expected_hex}, from, state) do
    payload = <<byte_size(path)::16-big, path::binary, expected_hex::binary>>
    send_framed(state, :holo_verify, 0x10, payload, :verify, from, %{path: path})
  end

  def handle_call({:raw, worker, opcode, payload}, from, state) do
    send_framed(state, worker, opcode, payload, :raw, from, %{})
  end

  @impl true
  def handle_info({port, {:data, <<status, payload::binary>>}}, state) do
    case Map.pop(state.pending, port) do
      {nil, _} ->
        {:noreply, state}

      {pending, pending_rest} ->
        Process.cancel_timer(pending.timer)
        GenServer.reply(pending.from, parse_response(pending.kind, status, payload, pending))
        {:noreply, %{state | pending: pending_rest}}
    end
  end

  def handle_info({port, {:exit_status, code}}, state) do
    {pending, pending_rest} = Map.pop(state.pending, port)
    if pending, do: GenServer.reply(pending.from, {:error, {:worker_exited, code}})
    if pending, do: Process.cancel_timer(pending.timer)
    worker = worker_for_port(state.ports, port)
    ports = Map.put(state.ports, worker, open_port(state.bin_dir, worker))
    {:noreply, %{state | ports: ports, pending: pending_rest}}
  end

  def handle_info({:worker_timeout, port}, state) do
    case Map.pop(state.pending, port) do
      {nil, _} ->
        {:noreply, state}

      {pending, pending_rest} ->
        Port.close(port)
        GenServer.reply(pending.from, {:error, :worker_timeout})
        worker = worker_for_port(state.ports, port)
        ports = Map.put(state.ports, worker, open_port(state.bin_dir, worker))
        {:noreply, %{state | ports: ports, pending: pending_rest}}
    end
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # --- Helpers ---

  defp send_framed(state, worker, opcode, payload, kind, from, extra) do
    port = Map.get(state.ports, worker)

    cond do
      port == nil ->
        {:reply, {:error, :worker_not_available}, state}

      Map.has_key?(state.pending, port) ->
        {:reply, {:error, :worker_busy}, state}

      true ->
        Port.command(port, <<opcode, payload::binary>>)
        timer = Process.send_after(self(), {:worker_timeout, port}, @timeout)
        pending = Map.merge(%{from: from, timer: timer, kind: kind, worker: worker}, extra)
        {:noreply, %{state | pending: Map.put(state.pending, port, pending)}}
    end
  end

  defp open_port(bin_dir, worker) do
    bin = Path.join(bin_dir, Atom.to_string(worker))

    if File.exists?(bin) do
      Port.open(
        {:spawn_executable, bin},
        [:binary, :exit_status, {:packet, 4}, args: ["--port"]]
      )
    else
      nil
    end
  end

  defp worker_for_port(ports, port) do
    Enum.find_value(ports, fn {worker, p} -> if p == port, do: worker end)
  end

  defp parse_response(:fp, 0, <<value::64-big>>, _pending), do: {:ok, value}
  defp parse_response(:fp, status, payload, _pending), do: {:error, {:worker_error, status, payload}}

  defp parse_response(:verify, 0, digest, %{path: path}) when byte_size(digest) == 32 do
    {:ok, %{sha256: Base.encode16(digest, case: :lower), path: path}}
  end

  defp parse_response(:verify, 1, digest, _pending) when byte_size(digest) == 32 do
    {:error, {:checksum_mismatch, Base.encode16(digest, case: :lower)}}
  end

  defp parse_response(:verify, status, payload, _pending),
    do: {:error, {:worker_error, status, payload}}

  defp parse_response(:raw, 0, payload, _pending), do: {:ok, payload}
  defp parse_response(:raw, status, payload, _pending), do: {:error, {:worker_error, status, payload}}

  @doc false
  def timeout, do: @timeout
end
