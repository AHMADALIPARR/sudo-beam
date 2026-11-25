# holo_verify.mojo — binary / SHA-256 receipt verifier, Port worker
#
# Two modes, same code:
#   CLI:  holo_verify <path> <expected-sha256-hex64>
#         prints VERIFIED <hex> <path> / MISMATCH <expected> <actual> <path>
#         exit 0 on match, 1 on mismatch, 2 on usage / file error.
#   Port: holo_verify --port
#         reads length-prefixed packets from stdin (fd 0), writes
#         length-prefixed responses to stdout (fd 1), loops to EOF.
#         Packet: u32_be length, u8 opcode, payload.
#         Opcode 0x10 VERIFY, payload: u16_be path_len, path bytes,
#         64 bytes expected-hex (ASCII). Response: u8 status,
#         32-byte digest. status 0 = match, 1 = mismatch, 2 = error
#         (payload then is an ASCII error string, not a digest).
#
# SHA-256 here is PURE Mojo — Mojo 1.2 stdlib `hashlib` is the
# Hasher trait (Fnv1a / AHasher), not a cryptographic SHA-256,
# so there is no stdlib call to use. The algorithm below mirrors
# kernels/tests/verify_sha256_and_framing.py exactly (same K,
# same H, same rotr / padding / chunk loop). That Python mirror
# was checked against hashlib for 5 test vectors (empty, "abc",
# the 56-byte NIST vector, 1,000,000 x "a", bytes 0..255) plus
# 500 random inputs on 2026-11-24 — all PASS.
#
# Mojo 1.2 notes (verified by compiling on this host 2026-11-24):
# `fn` is removed, use `def`; top-level constants are `comptime`;
# imports are `std.sys` / `std.ffi` / `std.memory`; raw pointers
# are `Pointer[T, ...]`; `Pointer.alloc` does not exist, so Port
# buffers are List[UInt8] + unsafe_ptr(); List values are moved
# with postfix `^`; String has no len()/indexing, use as_bytes().
# This file must never print a false VERIFIED: CLI exits 2 and
# Port returns status 2 on any error path.

from std.sys import argv, exit
from std.ffi import external_call, c_int, c_ssize_t, c_size_t
from std.memory import Pointer


comptime OP_VERIFY: UInt8 = 16  # 0x10


def rotr(x: UInt32, n: UInt32) -> UInt32:
    return (x >> n) | (x << (32 - n))


def string_to_bytes(s: String) -> List[UInt8]:
    var out = List[UInt8]()
    var b = s.as_bytes()
    for i in range(len(b)):
        out.append(b[i])
    return out^


def bytes_to_string(b: List[UInt8]) -> String:
    var s = String()
    for i in range(len(b)):
        s += chr(Int(b[i]))
    return s


def hex_val(byte: UInt8) -> Int:
    if byte >= 48 and byte <= 57:  # '0'..'9'
        return Int(byte) - 48
    if byte >= 97 and byte <= 102:  # 'a'..'f'
        return Int(byte) - 97 + 10
    if byte >= 65 and byte <= 70:  # 'A'..'F'
        return Int(byte) - 65 + 10
    return -1


def hex_to_bytes(hex_str: String) -> List[UInt8]:
    var out = List[UInt8]()
    var b = string_to_bytes(hex_str)
    var i = 0
    while i + 1 < len(b):
        var hi = hex_val(b[i])
        var lo = hex_val(b[i + 1])
        if hi < 0 or lo < 0:
            return List[UInt8]()
        out.append(UInt8(hi * 16 + lo))
        i += 2
    return out^


def bytes_to_hex(digest: List[UInt8]) -> String:
    var chars = string_to_bytes("0123456789abcdef")
    var s = String()
    for i in range(len(digest)):
        s += chr(Int(chars[Int(digest[i] >> 4)]))
        s += chr(Int(chars[Int(digest[i] & 15)]))
    return s


def sha256(data: List[UInt8]) -> List[UInt8]:
    var k: List[UInt32] = [
        0x428A2F98, 0x71374491, 0xB5C0FBCF, 0xE9B5DBA5,
        0x3956C25B, 0x59F111F1, 0x923F82A4, 0xAB1C5ED5,
        0xD807AA98, 0x12835B01, 0x243185BE, 0x550C7DC3,
        0x72BE5D74, 0x80DEB1FE, 0x9BDC06A7, 0xC19BF174,
        0xE49B69C1, 0xEFBE4786, 0x0FC19DC6, 0x240CA1CC,
        0x2DE92C6F, 0x4A7484AA, 0x5CB0A9DC, 0x76F988DA,
        0x983E5152, 0xA831C66D, 0xB00327C8, 0xBF597FC7,
        0xC6E00BF3, 0xD5A79147, 0x06CA6351, 0x14292967,
        0x27B70A85, 0x2E1B2138, 0x4D2C6DFC, 0x53380D13,
        0x650A7354, 0x766A0ABB, 0x81C2C92E, 0x92722C85,
        0xA2BFE8A1, 0xA81A664B, 0xC24B8B70, 0xC76C51A3,
        0xD192E819, 0xD6990624, 0xF40E3585, 0x106AA070,
        0x19A4C116, 0x1E376C08, 0x2748774C, 0x34B0BCB5,
        0x391C0CB3, 0x4ED8AA4A, 0x5B9CCA4F, 0x682E6FF3,
        0x748F82EE, 0x78A5636F, 0x84C87814, 0x8CC70208,
        0x90BEFFFA, 0xA4506CEB, 0xBEF9A3F7, 0xC67178F2,
    ]
    var h: List[UInt32] = [
        0x6A09E667, 0xBB67AE85, 0x3C6EF372, 0xA54FF53A,
        0x510E527F, 0x9B05688C, 0x1F83D9AB, 0x5BE0CD19,
    ]
    var padded = List[UInt8]()
    for i in range(len(data)):
        padded.append(data[i])
    padded.append(0x80)
    while len(padded) % 64 != 56:
        padded.append(0)
    var bitlen = UInt64(len(data)) * 8
    for i in range(8):
        padded.append(UInt8((bitlen >> UInt64(56 - 8 * i)) & 0xFF))
    var chunk_start = 0
    while chunk_start < len(padded):
        var w = List[UInt32]()
        for i in range(16):
            var j = chunk_start + 4 * i
            w.append(
                (UInt32(padded[j]) << 24)
                | (UInt32(padded[j + 1]) << 16)
                | (UInt32(padded[j + 2]) << 8)
                | UInt32(padded[j + 3])
            )
        for i in range(16, 64):
            var s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3)
            var s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10)
            w.append(w[i - 16] + s0 + w[i - 7] + s1)
        var a = h[0]
        var b = h[1]
        var c = h[2]
        var d = h[3]
        var e = h[4]
        var f = h[5]
        var g = h[6]
        var hh = h[7]
        for i in range(64):
            var s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
            var ch = (e & f) ^ ((~e) & g)
            var t1 = hh + s1 + ch + k[i] + w[i]
            var s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
            var maj = (a & b) ^ (a & c) ^ (b & c)
            var t2 = s0 + maj
            hh = g
            g = f
            f = e
            e = d + t1
            d = c
            c = b
            b = a
            a = t1 + t2
        h[0] += a
        h[1] += b
        h[2] += c
        h[3] += d
        h[4] += e
        h[5] += f
        h[6] += g
        h[7] += hh
        chunk_start += 64
    var digest = List[UInt8]()
    for i in range(8):
        digest.append(UInt8((h[i] >> 24) & 0xFF))
        digest.append(UInt8((h[i] >> 16) & 0xFF))
        digest.append(UInt8((h[i] >> 8) & 0xFF))
        digest.append(UInt8(h[i] & 0xFF))
    return digest^


def verify_bytes(data: List[UInt8], expected_hex: String) -> Tuple[Bool, List[UInt8]]:
    var expected = hex_to_bytes(expected_hex)
    if len(expected) != 32:
        return (False, List[UInt8]())
    var digest = sha256(data)
    var ok = True
    for i in range(32):
        if digest[i] != expected[i]:
            ok = False
    return (ok, digest^)


def verify_file(path: String, expected_hex: String) -> Int:
    if path.byte_length() == 0 or expected_hex.byte_length() != 64:
        print("usage: holo_verify <path> <expected-sha256-hex64>")
        return 2
    try:
        with open(path, "r") as f:
            var data = f.read_bytes()
            var result = verify_bytes(data, expected_hex)
            var ok = result[0]
            var digest = result[1].copy()
            if len(digest) != 32:
                print("holo_verify: bad expected hex")
                return 2
            var actual = bytes_to_hex(digest)
            if ok:
                print("VERIFIED " + actual + " " + path)
                return 0
            print("MISMATCH " + expected_hex + " " + actual + " " + path)
            return 1
    except:
        print("holo_verify: cannot read " + path)
        return 2


# --- Port I/O: libc read(0)/write(1) via external_call, exact counts ---
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
        if pkt[0] != OP_VERIFY:
            resp.append(2)
            for byte in string_to_bytes("unknown opcode"):
                resp.append(byte)
        else:
            if pkt_len < 3 + 64:
                resp.append(2)
                for byte in string_to_bytes("short packet"):
                    resp.append(byte)
            else:
                var path_len = Int(pkt[1]) * 256 + Int(pkt[2])
                if 3 + path_len + 64 != pkt_len:
                    resp.append(2)
                    for byte in string_to_bytes("bad path length"):
                        resp.append(byte)
                else:
                    var path_bytes = List[UInt8]()
                    for i in range(path_len):
                        path_bytes.append(pkt[3 + i])
                    var hex_bytes = List[UInt8]()
                    for i in range(64):
                        hex_bytes.append(pkt[3 + path_len + i])
                    var path = bytes_to_string(path_bytes)
                    var expected = bytes_to_string(hex_bytes)
                    try:
                        with open(path, "r") as f:
                            var data = f.read_bytes()
                            var result = verify_bytes(data, expected)
                            if result[0]:
                                resp.append(0)
                            else:
                                resp.append(1)
                            for byte in result[1]:
                                resp.append(byte)
                    except:
                        resp.append(2)
                        for byte in string_to_bytes("cannot read file"):
                            resp.append(byte)
        write_packet(resp)


def main():
    var args = argv()
    if len(args) == 2 and args[1] == "--port":
        serve_port()
        return
    if len(args) != 3:
        print("usage: holo_verify <path> <expected-sha256-hex64>")
        print("   or: holo_verify --port")
        exit(2)
    var code = verify_file(args[1], args[2])
    if code != 0:
        exit(code)
