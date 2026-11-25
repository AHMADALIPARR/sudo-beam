defmodule Sudo.Common do
  @moduledoc """
  Shared types for all Sudo stubs. Mirrors `sudo-common-*`:
  tools/libraries shared by the other SDKs — here reduced to
  the result, error, and pagination shapes every stub uses.
  """

  @type result(t) :: {:ok, t} | {:error, term()}
  @type page :: %{items: [map()], next_token: String.t() | nil}
  @type list_input :: %{limit: pos_integer() | nil, next_token: String.t() | nil}

  @doc "Every stub returns this until it is implemented."
  @spec not_implemented(atom()) :: {:error, {:not_implemented, atom()}}
  def not_implemented(fun) when is_atom(fun), do: {:error, {:not_implemented, fun}}

  @spec validate_id(term()) :: :ok | {:error, :invalid_id}
  def validate_id(id) when is_binary(id) and byte_size(id) > 0, do: :ok
  def validate_id(_), do: {:error, :invalid_id}

  @spec validate_map(map()) :: :ok | {:error, :invalid_input}
  def validate_map(m) when is_map(m) and map_size(m) > 0, do: :ok
  def validate_map(_), do: {:error, :invalid_input}
end
