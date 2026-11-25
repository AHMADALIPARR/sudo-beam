defmodule Sudo.SecureIdVerification do
  @moduledoc "Stub for `sudo-secure-id-verification-*` (Secure ID Verification SDK)."
  alias Sudo.Common

  @spec start_verification(map()) :: Common.result(map())
  def start_verification(attrs) do
    with :ok <- Common.validate_map(attrs), do: Common.not_implemented(:start_verification)
  end

  @spec get_verification(String.t()) :: Common.result(map())
  def get_verification(id) do
    with :ok <- Common.validate_id(id), do: Common.not_implemented(:get_verification)
  end

  @spec cancel_verification(String.t()) :: Common.result(:ok)
  def cancel_verification(id) do
    with :ok <- Common.validate_id(id), do: Common.not_implemented(:cancel_verification)
  end
end
