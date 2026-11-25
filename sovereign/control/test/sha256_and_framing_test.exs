# Copyright (C) 2026 AHMADALIPARR
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, version 3 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Sha256AndFramingTest do
  # Replaces the old kernel mirror test.
  # Same coverage, in the stack's own language: Elixir/OTP stdlib
  # only (ExUnit, :crypto, KernelPort). No extra dep.
  # The Mojo kernels are checked two ways: their own self-tests
  # (field_ops) and, for SHA-256, against :crypto through the
  # holo_verify Port worker.
  use ExUnit.Case, async: false

  alias SovereignBeamMojo.KernelPort

  @p 18_446_744_069_414_584_321

  defp sha256_hex(data), do: :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)

  defp verify_with_worker(data) do
    path = Path.join(System.tmp_dir!(), "sbm-sha256-#{:erlang.unique_integer([:positive])}.bin")
    File.write!(path, data)

    try do
      assert {:ok, %{sha256: digest}} = KernelPort.verify_artifact(path, sha256_hex(data))
      digest
    after
      File.rm(path)
    end
  end

  test "sha256 vectors: holo_verify matches :crypto" do
    vectors = [
      {"", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"},
      {"abc", "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"},
      {"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq", nil},
      {String.duplicate("a", 1_000_000),
       "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0"},
      {:binary.list_to_bin(Enum.to_list(0..255)), nil}
    ]

    for {data, known} <- vectors do
      hex = sha256_hex(data)
      if known, do: assert(hex == known)
      assert verify_with_worker(data) == hex
    end
  end

  test "sha256 random data: holo_verify matches :crypto" do
    for _ <- 1..50 do
      data = :crypto.strong_rand_bytes(:rand.uniform(5000))
      assert verify_with_worker(data) == sha256_hex(data)
    end
  end

  test "framing round-trip: u32_be length + opcode + payload" do
    encode = fn opcode, payload ->
      <<(1 + byte_size(payload))::32-big, opcode::8, payload::binary>>
    end

    decode = fn <<len::32-big, opcode::8, payload::binary>> ->
      assert len == 1 + byte_size(payload)
      {opcode, payload}
    end

    cases = [
      {0x01, <<123::64-big, 456::64-big>>},
      {0x02, <<4_294_967_296::64-big, 4_294_967_296::64-big>>},
      {0x10, <<0, 4>> <> "test" <> String.duplicate("0", 64)}
    ]

    for {op, pay} <- cases, do: assert(decode.(encode.(op, pay)) == {op, pay})
  end

  test "fp edge: (p-1)*(p-1) mod p == 1" do
    assert KernelPort.fp_mul(@p - 1, @p - 1) == {:ok, 1}
  end

  test "field_ops self-test passes" do
    assert KernelPort.field_ops_self_test() == {:ok, %{checks: 9}}
  end
end
