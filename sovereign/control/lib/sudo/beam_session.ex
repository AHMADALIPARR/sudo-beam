defmodule Sudo.BeamSession do
  @moduledoc """
  Live bridge from the Elixir control plane to the sudo-beam Java
  worker — the sovereign layer on top of the sudo-beam base.

  This mirrors `sudo_beam_ffi` (Erlang) exactly, in Elixir: one
  GenServer owns one JVM worker started with
  `Port.open({:spawn_executable, java}, [:binary, {:packet, 4},
  :use_stdio, :exit_status, args: [...]])`. The BEAM adds and
  strips the 4-byte big-endian length header, so this module sends
  the raw UTF-8 command and receives the raw JSON response
  (`%{"exit" => n, "stdout" => s, "stderr" => s}`), decoded with
  `:json` (OTP 27+).

  One in-flight request per session, same as the gateway: the
  GenServer serializes calls. A session is started on demand and
  is NOT part of the root supervision tree — it is per-connection
  state, discarded when the worker closes.

  Paths mirror the Erlang FFI's environment variables and default
  to the layered tree:
    - `SUDO_BEAM_JAVA`   (default `/usr/bin/java`)
    - `SUDO_BEAM_JAR`    (default `sudo-beam/build/sudo.jar`,
      built by `make` at the tree root)
    - `SUDO_BEAM_AWK`    (default `sudo-beam/awk/policy.awk`)
    - `SUDO_BEAM_POLICY` (default `sudo-beam/awk/sudoers`)

  The worker itself is a virtual sudo: no host sudo, no setuid,
  no host shell. See `sudo-beam/README.md`.
  """

  use GenServer

  alias Sudo.Common

  @max_frame 16_384
  @callers ["operator", "guest", "service"]

  @type result :: %{exit: non_neg_integer(), stdout: binary(), stderr: binary()}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    caller = Keyword.get(opts, :caller, "operator")

    if caller in @callers do
      GenServer.start_link(__MODULE__, opts)
    else
      {:error, :invalid_caller}
    end
  end

  @spec request(GenServer.server(), binary(), timeout()) :: Common.result(result())
  def request(server, command, timeout \\ 15_000)

  def request(server, command, timeout)
      when is_binary(command) and byte_size(command) <= @max_frame do
    GenServer.call(server, {:request, command}, timeout)
  end

  def request(_server, _command, _timeout), do: {:error, :invalid_frame}

  @spec run_commands(String.t(), [binary()]) :: [Common.result(result())]
  def run_commands(caller, commands) when is_list(commands) do
    case start_link(caller: caller) do
      {:ok, pid} ->
        try do
          Enum.map(commands, &request(pid, &1))
        after
          stop(pid)
        end

      {:error, _} = err ->
        [err]
    end
  end

  @spec stop(GenServer.server()) :: :ok
  def stop(server) do
    if Process.alive?(server) do
      GenServer.stop(server, :normal, 5_000)
    else
      :ok
    end
  catch
    :exit, _ -> :ok
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    caller = Keyword.get(opts, :caller, "operator")
    java = System.get_env("SUDO_BEAM_JAVA", "/usr/bin/java")
    jar = System.get_env("SUDO_BEAM_JAR", default_jar())
    awk = System.get_env("SUDO_BEAM_AWK", default_awk())
    policy = System.get_env("SUDO_BEAM_POLICY", default_policy())

    args = [
      "-Xms8m",
      "-Xmx32m",
      "-jar",
      jar,
      caller,
      awk,
      policy,
      "port"
    ]

    port =
      Port.open({:spawn_executable, java}, [
        :binary,
        {:packet, 4},
        :use_stdio,
        :exit_status,
        {:args, args}
      ])

    {:ok, %{port: port, caller: caller, waiter: nil, dead: nil}}
  end

  @impl true
  def handle_call({:request, command}, from, %{port: port, waiter: nil} = state) do
    try do
      Port.command(port, command)
      {:noreply, %{state | waiter: from}}
    catch
      :error, :badarg -> {:reply, {:error, :worker_closed}, state}
    end
  end

  def handle_call({:request, _command}, _from, state) do
    {:reply, {:error, :busy}, state}
  end

  @impl true
  def handle_info({port, {:data, json}}, %{port: port, waiter: from} = state) do
    reply =
      case :json.decode(json) do
        %{"exit" => exit_code, "stdout" => out, "stderr" => err}
        when is_integer(exit_code) and is_binary(out) and is_binary(err) ->
          {:ok, %{exit: exit_code, stdout: out, stderr: err}}

        _ ->
          {:error, :bad_response}
      end

    if from, do: GenServer.reply(from, reply)
    {:noreply, %{state | waiter: nil}}
  end

  def handle_info({port, {:exit_status, code}}, %{port: port} = state) do
    if state.waiter, do: GenServer.reply(state.waiter, {:error, {:worker_exited, code}})
    {:noreply, %{state | waiter: nil, dead: code}}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, %{port: port}) do
    if Port.info(port), do: Port.close(port)
    :ok
  end

  # Defaults resolve against the layered tree:
  # sovereign/control/lib/sudo -> sudo-beam/<file>.
  defp default_jar, do: Path.expand("../../../../build/sudo.jar", __DIR__)
  defp default_awk, do: Path.expand("../../../../awk/policy.awk", __DIR__)
  defp default_policy, do: Path.expand("../../../../awk/sudoers", __DIR__)
end
