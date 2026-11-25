# field_ops.mojo — Goldilocks Fp arithmetic (IMPLEMENTED) + Port worker
#
# p = 2^64 - 2^32 + 1 = 18446744069414584321 (public mathematics).
#
# Two modes, same code:
#   CLI:  field_ops            (no args) runs the 9-check self-test
#   Port: field_ops --port     reads length-prefixed packets from
#         stdin (fd 0), writes length-prefixed responses to stdout
#         (fd 1), loops to EOF. Packet: u32_be length, u8 opcode,
#         payload. Response: u8 status (0=ok, 1=error), payload.
#         Opcodes: 0x01 add, 0x02 mul (payload 16 bytes, 2x u64 BE),
#         0x03 neg (payload 8 bytes, u64 BE). Response payload on
#         success is 8 bytes, u64 BE. Status 1 payload is ASCII.
#
# fp_add / fp_mul / fp_neg are real, for canonical inputs
# 0 <= a, b < p. They are NOT constant-time and NOT SIMD-tuned:
# fp_mul uses a data-dependent final subtraction loop and a
# 128-bit product, so do not use it for real crypto until it is
# constant-time, SIMD-tuned, and verified by compiling + running
# this file's self-test in the VirtualBox guest (Mojo 1.2).
#
# Reduction used by fp_mul (2^64 == 2^32 - 1 mod p, since
# p = 2^64 - 2^32 + 1):
#   a*b = hi * 2^64 + lo
#       == lo + hi * (2^32 - 1)          (mod p)
# Apply the same step once more to the 128-bit intermediate,
# then subtract p while the result is >= p (at most twice).
# The algorithm is checked by the field_ops self-test (9 checks,
# incl. the edge vectors in main()) and by
# control/test/sha256_and_framing_test.exs (fp edge:
# (p-1)*(p-1) mod p == 1), run by `mix test` in the pipeline.
#
# Mojo 1.2 notes (verified by compiling on this host 2026-11-24):
# `fn` is removed, use `def`; top-level constants are `comptime`;
# imports are `std.sys` / `std.ffi` / `std.memory`; raw pointers
# are `Pointer[T, ...]`; `Pointer.alloc` does not exist, so Port
# buffers are List[UInt8] + unsafe_ptr(); `out` is a reserved
# word and cannot be a parameter name.

from std.sys import argv
from std.ffi import external_call, c_int, c_ssize_t, c_size_t
from std.memory import Pointer

comptime P: UInt64 = 18446744069414584321  # 2^64 - 2^32 + 1
comptime MASK64: UInt128 = 18446744073709551615  # 2^64 - 1
comptime C32: UInt128 = 4294967295  # 2^32 - 1
comptime OP_ADD: UInt8 = 1
comptime OP_MUL: UInt8 = 2
comptime OP_NEG: UInt8 = 3


def fp_add(a: UInt64, b: UInt64) -> UInt64:
    # 128-bit sum, so a + b can never wrap: the old stub did
    # `s - P` on the wrapped 64-bit sum and was wrong when
    # a + b >= 2^64 (e.g. a = b = p - 1 gave a wrapped result).
    var s: UInt128 = UInt128(a) + UInt128(b)
    if s >= UInt128(P):
        return UInt64(s - UInt128(P))
    return UInt64(s)


def fp_mul(a: UInt64, b: UInt64) -> UInt64:
    var prod: UInt128 = UInt128(a) * UInt128(b)
    var hi: UInt64 = UInt64(prod >> 64)
    var lo: UInt64 = UInt64(prod & MASK64)
    # First reduction: prod == lo + hi * (2^32 - 1) (mod p).
    var t: UInt128 = UInt128(lo) + UInt128(hi) * C32
    # Second reduction on the 128-bit intermediate t.
    var t_hi: UInt64 = UInt64(t >> 64)
    var t_lo: UInt64 = UInt64(t & MASK64)
    var r: UInt128 = UInt128(t_lo) + UInt128(t_hi) * C32
    while r >= UInt128(P):
        r -= UInt128(P)
    return UInt64(r)


def fp_neg(a: UInt64) -> UInt64:
    if a == 0:
        return 0
    return P - a


def be64(buf: Pointer[UInt8, ...], off: Int) -> UInt64:
    var v: UInt64 = 0
    for i in range(8):
        v = (v << 8) | UInt64(buf.unsafe_offset(off + i)[])
    return v


def append_be64(mut dst: List[UInt8], v: UInt64):
    for i in range(8):
        dst.append(UInt8((v >> UInt64(56 - 8 * i)) & 0xFF))


def read_exact(buf: Pointer[UInt8, ...], n: Int) -> Int:
    var total = 0
    while total < n:
        var r = external_call["read", Int](Int32(0), buf.unsafe_offset(total), n - total)
        if r <= 0:
            return total
        total += r
    return total


def write_all(buf: Pointer[UInt8, ...], n: Int) -> Int:
    var total = 0
    while total < n:
        var r = Int(
            external_call["write", c_ssize_t](
                c_int(1), buf.unsafe_offset(total), c_size_t(n - total)
            )
        )
        if r <= 0:
            return total
        total += r
    return total


def write_packet(resp: List[UInt8]):
    var len_buf = List[UInt8]()
    len_buf.append(UInt8((len(resp) >> 24) & 0xFF))
    len_buf.append(UInt8((len(resp) >> 16) & 0xFF))
    len_buf.append(UInt8((len(resp) >> 8) & 0xFF))
    len_buf.append(UInt8(len(resp) & 0xFF))
    _ = write_all(len_buf.unsafe_ptr(), 4)
    _ = write_all(resp.unsafe_ptr(), len(resp))


def serve_port():
    var len_buf = List[UInt8]()
    for _ in range(4):
        len_buf.append(0)
    while True:
        var n = read_exact(len_buf.unsafe_ptr(), 4)
        if n != 4:
            break
        var pkt_len = Int(
            (UInt32(len_buf[0]) << 24)
            | (UInt32(len_buf[1]) << 16)
            | (UInt32(len_buf[2]) << 8)
            | UInt32(len_buf[3])
        )
        if pkt_len < 1 or pkt_len > 65536:
            break
        var pkt = List[UInt8]()
        for _ in range(pkt_len):
            pkt.append(0)
        var m = read_exact(pkt.unsafe_ptr(), pkt_len)
        if m != pkt_len:
            break
        var resp = List[UInt8]()
        if pkt[0] == OP_ADD and pkt_len == 17:
            resp.append(0)
            append_be64(resp, fp_add(be64(pkt.unsafe_ptr(), 1), be64(pkt.unsafe_ptr(), 9)))
        elif pkt[0] == OP_MUL and pkt_len == 17:
            resp.append(0)
            append_be64(resp, fp_mul(be64(pkt.unsafe_ptr(), 1), be64(pkt.unsafe_ptr(), 9)))
        elif pkt[0] == OP_NEG and pkt_len == 9:
            resp.append(0)
            append_be64(resp, fp_neg(be64(pkt.unsafe_ptr(), 1)))
        else:
            resp.append(1)
            var msg = String("bad opcode or length")
            var msg_bytes = msg.as_bytes()
            for i in range(len(msg_bytes)):
                resp.append(msg_bytes[i])
        write_packet(resp)


def main():
    var args = argv()
    if len(args) == 2 and args[1] == "--port":
        serve_port()
        return
    print("field_ops: fp_add/fp_mul/fp_neg implemented (not constant-time)")
    print("p =", P)
    var failures: Int = 0
    if fp_mul(2, 3) != 6:
        print("FAIL fp_mul(2, 3)")
        failures += 1
    if fp_mul(1, P - 1) != P - 1:
        print("FAIL fp_mul(1, p-1)")
        failures += 1
    if fp_mul(P - 1, P - 1) != 1:
        print("FAIL fp_mul(p-1, p-1) != 1")
        failures += 1
    if fp_mul(4294967296, 4294967296) != 4294967295:
        print("FAIL fp_mul(2^32, 2^32) != 2^32-1")
        failures += 1
    if fp_mul(123456789, 987654321) != 121932631112635269:
        print("FAIL fp_mul(123456789, 987654321)")
        failures += 1
    if fp_add(P - 1, P - 1) != P - 2:
        print("FAIL fp_add(p-1, p-1) != p-2")
        failures += 1
    if fp_add(P - 1, 1) != 0:
        print("FAIL fp_add(p-1, 1) != 0")
        failures += 1
    if fp_neg(1) != P - 1:
        print("FAIL fp_neg(1) != p-1")
        failures += 1
    if fp_neg(0) != 0:
        print("FAIL fp_neg(0) != 0")
        failures += 1
    if failures == 0:
        print("field_ops self-test: PASS (9 checks)")
    else:
        print("field_ops self-test: FAIL,", failures, "checks failed")
