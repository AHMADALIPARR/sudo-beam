defmodule Sudo.Logging do
  @moduledoc """
  Stub for `sudo-logging-*` (Logging SDK). Local-only: writes to
  Elixir Logger. No remote sink, no PII — callers must not pass
  secrets, tokens, or message bodies here.
  """
  require Logger

  @spec log(atom(), String.t()) :: :ok
  def log(level, message) when is_atom(level) and is_binary(message) do
    Logger.log(level, message)
    :ok
  end
end
