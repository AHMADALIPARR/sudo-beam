defmodule Sudo.Email do
  @moduledoc """
  Stub for `sudo-email-*` (Email SDK): secure/private email —
  addresses, folders, send/receive, drafts, scheduled send,
  blocklists, and aliases. Docs: guides/email.md and its
  email-addresses / email-aliases sub-guides.
  """

  alias Sudo.Common

  @spec create_email_address(map()) :: Common.result(map())
  def create_email_address(attrs) do
    with :ok <- Common.validate_map(attrs), do: Common.not_implemented(:create_email_address)
  end

  @spec list_email_addresses(Common.list_input()) :: Common.result(Common.page())
  def list_email_addresses(_input \\ %{}), do: Common.not_implemented(:list_email_addresses)

  @spec list_folders(String.t()) :: Common.result([map()])
  def list_folders(address_id) do
    with :ok <- Common.validate_id(address_id), do: Common.not_implemented(:list_folders)
  end

  @spec send_message(map()) :: Common.result(map())
  def send_message(attrs) do
    with :ok <- Common.validate_map(attrs), do: Common.not_implemented(:send_message)
  end

  @spec list_messages(String.t(), Common.list_input()) :: Common.result(Common.page())
  def list_messages(address_id, _input \\ %{}) do
    with :ok <- Common.validate_id(address_id), do: Common.not_implemented(:list_messages)
  end

  @spec create_draft(map()) :: Common.result(map())
  def create_draft(attrs) do
    with :ok <- Common.validate_map(attrs), do: Common.not_implemented(:create_draft)
  end

  @spec schedule_send(map(), DateTime.t()) :: Common.result(map())
  def schedule_send(attrs, %DateTime{} = _at) do
    with :ok <- Common.validate_map(attrs), do: Common.not_implemented(:schedule_send)
  end

  @spec create_alias(map()) :: Common.result(map())
  def create_alias(attrs) do
    with :ok <- Common.validate_map(attrs), do: Common.not_implemented(:create_alias)
  end

  @spec block_address(String.t(), String.t()) :: Common.result(:ok)
  def block_address(address_id, blocked) do
    with :ok <- Common.validate_id(address_id),
         :ok <- Common.validate_id(blocked),
         do: Common.not_implemented(:block_address)
  end
end
