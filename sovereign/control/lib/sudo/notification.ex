defmodule Sudo.Notification do
  @moduledoc "Stub for `sudo-notification-*` / `sudo-notification-web` (Notification SDK)."
  alias Sudo.Common

  @spec register_device(map()) :: Common.result(map())
  def register_device(attrs) do
    with :ok <- Common.validate_map(attrs), do: Common.not_implemented(:register_device)
  end

  @spec unregister_device(String.t()) :: Common.result(:ok)
  def unregister_device(device_id) do
    with :ok <- Common.validate_id(device_id), do: Common.not_implemented(:unregister_device)
  end

  @spec list_notifications(Common.list_input()) :: Common.result(Common.page())
  def list_notifications(_input \\ %{}), do: Common.not_implemented(:list_notifications)
end
