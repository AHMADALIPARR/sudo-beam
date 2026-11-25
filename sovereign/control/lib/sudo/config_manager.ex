defmodule Sudo.ConfigManager do
  @moduledoc "Stub for `sudo-config-manager-*` (Config Manager SDK)."
  alias Sudo.Common

  @spec get_config() :: Common.result(map())
  def get_config, do: Common.not_implemented(:get_config)

  @spec refresh_config() :: Common.result(map())
  def refresh_config, do: Common.not_implemented(:refresh_config)
end
