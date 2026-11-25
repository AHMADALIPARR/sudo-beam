defmodule Sudo.Relay do
  @moduledoc """
  Stub for `sudo-di-relay-*` and `sudo-di-edge-agent-*`
  (Decentralized Identity Relay / Edge Agent): postboxes, relay
  messages, and connections. Docs: guides/decentralized-identity.md.
  """
  alias Sudo.Common

  @spec create_postbox(map()) :: Common.result(map())
  def create_postbox(attrs) do
    with :ok <- Common.validate_map(attrs), do: Common.not_implemented(:create_postbox)
  end

  @spec list_postboxes(Common.list_input()) :: Common.result(Common.page())
  def list_postboxes(_input \\ %{}), do: Common.not_implemented(:list_postboxes)

  @spec send_message(map()) :: Common.result(map())
  def send_message(attrs) do
    with :ok <- Common.validate_map(attrs), do: Common.not_implemented(:send_message)
  end

  @spec list_messages(String.t(), Common.list_input()) :: Common.result(Common.page())
  def list_messages(postbox_id, _input \\ %{}) do
    with :ok <- Common.validate_id(postbox_id), do: Common.not_implemented(:list_messages)
  end

  @spec create_connection(map()) :: Common.result(map())
  def create_connection(attrs) do
    with :ok <- Common.validate_map(attrs), do: Common.not_implemented(:create_connection)
  end
end
