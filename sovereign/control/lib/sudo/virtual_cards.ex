defmodule Sudo.VirtualCards do
  @moduledoc """
  Stub for `sudo-virtual-cards-*`, `sudo-virtual-cards-simulator-*`,
  and `sudo-virtual-cards-admin-*` (Virtual Cards SDK).
  """

  alias Sudo.Common

  @spec create_card(map()) :: Common.result(map())
  def create_card(attrs) do
    with :ok <- Common.validate_map(attrs), do: Common.not_implemented(:create_card)
  end

  @spec list_cards(Common.list_input()) :: Common.result(Common.page())
  def list_cards(_input \\ %{}), do: Common.not_implemented(:list_cards)

  @spec get_card(String.t()) :: Common.result(map())
  def get_card(id) do
    with :ok <- Common.validate_id(id), do: Common.not_implemented(:get_card)
  end

  @spec update_card(String.t(), map()) :: Common.result(map())
  def update_card(id, attrs) do
    with :ok <- Common.validate_id(id),
         :ok <- Common.validate_map(attrs),
         do: Common.not_implemented(:update_card)
  end

  @spec suspend_card(String.t()) :: Common.result(map())
  def suspend_card(id) do
    with :ok <- Common.validate_id(id), do: Common.not_implemented(:suspend_card)
  end

  @spec list_transactions(String.t(), Common.list_input()) :: Common.result(Common.page())
  def list_transactions(card_id, _input \\ %{}) do
    with :ok <- Common.validate_id(card_id), do: Common.not_implemented(:list_transactions)
  end
end
