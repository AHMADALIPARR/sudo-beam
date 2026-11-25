defmodule SovereignBeamMojo.ReceiptStore do
  @moduledoc """
  Content-addressed SHA-256 build/run receipt tracker.

  A receipt is `%{sha256: hex, path: path, at: DateTime.t()}`.
  `record/2` hashes the file at `path` with `:crypto.hash/2`
  (BEAM-side, small files only — large artifacts go through the
  Mojo `holo_verify` worker via KernelPort once implemented).
  """
  use GenServer

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @type receipt :: %{sha256: String.t(), path: String.t(), at: DateTime.t()}

  @spec record(String.t()) :: {:ok, receipt()} | {:error, term()}
  def record(path) when is_binary(path) do
    case File.read(path) do
      {:ok, bytes} ->
        receipt = %{
          sha256: Base.encode16(:crypto.hash(:sha256, bytes), case: :lower),
          path: path,
          at: DateTime.utc_now()
        }

        GenServer.call(__MODULE__, {:put, receipt})

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec get(String.t()) :: {:ok, receipt()} | {:error, :not_found}
  def get(sha256), do: GenServer.call(__MODULE__, {:get, sha256})

  @spec list() :: [receipt()]
  def list, do: GenServer.call(__MODULE__, :list)

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  def handle_call({:put, receipt}, _from, state) do
    {:reply, {:ok, receipt}, Map.put(state, receipt.sha256, receipt)}
  end

  def handle_call({:get, sha256}, _from, state) do
    case Map.fetch(state, sha256) do
      {:ok, receipt} -> {:reply, {:ok, receipt}, state}
      :error -> {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call(:list, _from, state), do: {:reply, Map.values(state), state}
end
