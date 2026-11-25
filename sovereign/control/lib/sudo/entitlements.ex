defmodule Sudo.Entitlements do
  @moduledoc """
  Stub for `sudo-entitlements-*` and `sudo-entitlements-admin-*`:
  managing consumption of Sudo capabilities.
  Docs: guides/entitlements.md, end-user-api/ (redeem, retrieve),
  administrative-api/ (definitions, sets, sequences, user entitlements).
  """

  alias Sudo.Common

  @spec get_entitlements(String.t()) :: Common.result([map()])
  def get_entitlements(user_id) do
    with :ok <- Common.validate_id(user_id), do: Common.not_implemented(:get_entitlements)
  end

  @spec redeem_entitlement(String.t(), String.t()) :: Common.result(map())
  def redeem_entitlement(user_id, entitlement_id) do
    with :ok <- Common.validate_id(user_id),
         :ok <- Common.validate_id(entitlement_id),
         do: Common.not_implemented(:redeem_entitlement)
  end

  @spec list_entitlement_definitions(Common.list_input()) :: Common.result(Common.page())
  def list_entitlement_definitions(_input \\ %{}),
    do: Common.not_implemented(:list_entitlement_definitions)

  @spec create_entitlement_set(map()) :: Common.result(map())
  def create_entitlement_set(attrs) do
    with :ok <- Common.validate_map(attrs), do: Common.not_implemented(:create_entitlement_set)
  end

  @spec apply_entitlements_sequence(String.t(), String.t()) :: Common.result(map())
  def apply_entitlements_sequence(user_id, sequence_id) do
    with :ok <- Common.validate_id(user_id),
         :ok <- Common.validate_id(sequence_id),
         do: Common.not_implemented(:apply_entitlements_sequence)
  end

  @spec get_user_entitlements(String.t()) :: Common.result([map()])
  def get_user_entitlements(user_id) do
    with :ok <- Common.validate_id(user_id), do: Common.not_implemented(:get_user_entitlements)
  end
end
