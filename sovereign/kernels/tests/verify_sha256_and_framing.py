import hashlib, random, struct
# Mirror of the Mojo SHA-256 to be written: same K, H, rotr, padding, chunk loop
K=[0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2]
H0=[0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19]
MASK=0xffffffff
def rotr(x,n): return ((x>>n)|(x<<(32-n))) & MASK
def sha256_mirror(data: bytes) -> bytes:
    h=H0[:]
    bitlen=len(data)*8
    msg=bytearray(data); msg.append(0x80)
    while len(msg)%64!=56: msg.append(0)
    msg+=struct.pack('>Q', bitlen)
    for off in range(0,len(msg),64):
        chunk=msg[off:off+64]
        w=[struct.unpack('>I',chunk[i*4:(i+1)*4])[0] for i in range(16)]
        for i in range(16,64):
            s0=rotr(w[i-15],7)^rotr(w[i-15],18)^(w[i-15]>>3)
            s1=rotr(w[i-2],17)^rotr(w[i-2],19)^(w[i-2]>>10)
            w.append((w[i-16]+s0+w[i-7]+s1)&MASK)
        a,b,c,d,e,f,g,hh=h
        for i in range(64):
            S1=rotr(e,6)^rotr(e,11)^rotr(e,25)
            ch=(e&f)^((~e)&g)
            t1=(hh+S1+ch+K[i]+w[i])&MASK
            S0=rotr(a,2)^rotr(a,13)^rotr(a,22)
            maj=(a&b)^(a&c)^(b&c)
            t2=(S0+maj)&MASK
            hh=g; g=f; f=e; e=(d+t1)&MASK; d=c; c=b; b=a; a=(t1+t2)&MASK
        h=[(x+y)&MASK for x,y in zip(h,[a,b,c,d,e,f,g,hh])]
    return struct.pack('>8I',*h)
# vectors
vecs=[b'',b'abc',b'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq',b'a'*1000000, bytes(range(256))]
for v in vecs:
    assert sha256_mirror(v)==hashlib.sha256(v).digest(), v[:20]
random.seed(1)
for _ in range(500):
    n=random.randrange(0,5000)
    d=random.randbytes(n)
    assert sha256_mirror(d)==hashlib.sha256(d).digest()
print("SHA-256 mirror: PASS", len(vecs), "vectors + 500 random")
# framing mirror: Elixir {:packet,4} + Mojo read
def encode(opcode, payload): return struct.pack('>I',1+len(payload))+bytes([opcode])+payload
def decode(buf):
    ln=struct.unpack('>I',buf[:4])[0]; assert ln==len(buf)-4
    return buf[4], buf[5:]
for op,pay in [(1,struct.pack('>QQ',123,456)),(2,struct.pack('>QQ',2**32,2**32)),(16,b'\x00\x04test'+b'0'*64)]:
    assert decode(encode(op,pay))==(op,pay)
print("framing: PASS")
# fp_mul mirror check already done previously, spot check
P=2**64-2**32+1
assert ( (P-1)*(P-1) )%P==1
print("fp edge: PASS")
