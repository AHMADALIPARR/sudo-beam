defmodule Sudo.User do
  @moduledoc """
  Stub for `sudo-user-*` (User SDK): the glue between a user and
  their Sudo identities — registration and authentication.
  Docs: guides/users.md, guides/users/registration.md,
  guides/users/authentication.md. No network call is made here.
  """

  alias Sudo.Common

  @type user :: %{id: String.t(), username: String.t()}

  @spec register(map()) :: Common.result(user())
  def register(attrs) do
    with :ok <- Common.validate_map(attrs), do: Common.not_implemented(:register)
  end

  @spec sign_in(map()) :: Common.result(%{token: binary(), user: user()})
  def sign_in(creds) do
    with :ok <- Common.validate_map(creds), do: Common.not_implemented(:sign_in)
  end

  @spec sign_out() :: Common.result(:ok)
  def sign_out, do: Common.not_implemented(:sign_out)

  @spec get_user() :: Common.result(user())
  def get_user, do: Common.not_implemented(:get_user)

  @spec reset_password(map()) :: Common.result(:ok)
  def reset_password(attrs) do
    with :ok <- Common.validate_map(attrs), do: Common.not_implemented(:reset_password)
  end

  @spec delete_user() :: Common.result(:ok)
  def delete_user, do: Common.not_implemented(:delete_user)
end
