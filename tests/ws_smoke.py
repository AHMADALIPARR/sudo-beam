"""Live gateway test, using only Python's standard library."""
import base64, hashlib, json, os, socket, struct
TOKEN = os.environ['SUDO_BEAM_TOKEN']
with socket.create_connection(('127.0.0.1', 8080), timeout=20) as s:
    f = s.makefile('rb')
    key = base64.b64encode(os.urandom(16)).decode()
    s.sendall((f'GET /sudo HTTP/1.1\r\nHost: 127.0.0.1:8080\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\nAuthorization: Bearer {TOKEN}\r\n\r\n').encode())
    assert b' 101 ' in f.readline(), 'upgrade failed'
    headers = {}
    while True:
        line = f.readline()
        if line == b'\r\n': break
        if not line: raise EOFError('incomplete upgrade')
        name, value = line.decode().split(':',1); headers[name.lower()] = value.strip()
    expected = base64.b64encode(hashlib.sha1((key+'258EAFA5-E914-47DA-95CA-C5AB0DC85B11').encode()).digest()).decode()
    assert headers['sec-websocket-accept'] == expected
    def request(text):
        b=text.encode(); mask=os.urandom(4); assert len(b)<126
        s.sendall(bytes([0x81,0x80|len(b)])+mask+bytes(v^mask[i%4] for i,v in enumerate(b)))
        a,n=f.read(2); assert a==0x81 and n<128
        if n==126: n=struct.unpack('>H',f.read(2))[0]
        elif n==127: n=struct.unpack('>Q',f.read(8))[0]
        return json.loads(f.read(n))
    caller=os.getenv('SUDO_BEAM_CALLER','operator')
    assert request('whoami')['stdout']==caller+'\n'
    assert request('sudo id')['exit']==(0 if caller=='operator' else 1)
    assert request('write example "hello beam"')['exit']==0
    assert request('cat example')['stdout']=='hello beam'
    assert request('sudo /bin/sh')['exit']==1
    print('Live WebSocket smoke test: PASS')
