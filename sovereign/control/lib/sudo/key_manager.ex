defmodule Sudo.KeyManager do
  @moduledoc "Stub for `sudo-key-manager-*` (Key Manager SDK). Keys are never logged or returned in plaintext by a stub."
  alias Sudo.Common

  @spec create_key(map()) :: Common.result(map())
  def create_key(attrs) do
    with :ok <- Common.validate_map(attrs), do: Common.not_implemented(:create_key)
  end

  @spec get_key(String.t()) :: Common.result(map())
  def get_key(id) do
    with :ok <- Common.validate_id(id), do: Common.not_implemented(:get_key)
  end

  @spec delete_key(String.t()) :: Common.result(:ok)
  def delete_key(id) do
    with :ok <- Common.validate_id(id), do: Common.not_implemented(:delete_key)
  end

  @spec rotate_key(String.t()) :: Common.result(map())
  def rotate_key(id) do
    with :ok <- Common.validate_id(id), do: Common.not_implemented(:rotate_key)
  end
end
