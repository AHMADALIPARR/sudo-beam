defmodule Sudo.Telephony do
  @moduledoc """
  Stub for `sudo-telephony-*` (Telephony SDK): phone numbers,
  text messaging, and subscriptions. Docs: guides/telephony.md,
  phone-numbers.md, text-messaging.md, subscriptions.md.
  """

  alias Sudo.Common

  @spec create_phone_number(map()) :: Common.result(map())
  def create_phone_number(attrs) do
    with :ok <- Common.validate_map(attrs), do: Common.not_implemented(:create_phone_number)
  end

  @spec list_phone_numbers(Common.list_input()) :: Common.result(Common.page())
  def list_phone_numbers(_input \\ %{}), do: Common.not_implemented(:list_phone_numbers)

  @spec send_message(map()) :: Common.result(map())
  def send_message(attrs) do
    with :ok <- Common.validate_map(attrs), do: Common.not_implemented(:send_message)
  end

  @spec list_messages(String.t(), Common.list_input()) :: Common.result(Common.page())
  def list_messages(number_id, _input \\ %{}) do
    with :ok <- Common.validate_id(number_id), do: Common.not_implemented(:list_messages)
  end

  @spec subscribe(map()) :: Common.result(map())
  def subscribe(attrs) do
    with :ok <- Common.validate_map(attrs), do: Common.not_implemented(:subscribe)
  end
end
