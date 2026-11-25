import json, pathlib, struct, subprocess, tempfile, unittest
ROOT = pathlib.Path(__file__).resolve().parents[1]
class Worker:
    def __init__(self, caller='operator', policy=None):
        self.p = subprocess.Popen(['java','-jar',str(ROOT/'build/sudo.jar'),caller,str(ROOT/'awk/policy.awk'),str(policy or ROOT/'awk/sudoers'),'port'], stdin=subprocess.PIPE,stdout=subprocess.PIPE)
    def request(self, text):
        b = text.encode(); self.p.stdin.write(struct.pack('>I',len(b))+b); self.p.stdin.flush()
        n = struct.unpack('>I',self.p.stdout.read(4))[0]
        return json.loads(self.p.stdout.read(n))
    def close(self):
        self.p.stdin.close(); self.p.wait(timeout=5); self.p.stdout.close()
class Tests(unittest.TestCase):
    def setUp(self): self.w=Worker()
    def tearDown(self): self.w.close()
    def check(self, command, exit=0, stdout=None):
        r=self.w.request(command); self.assertEqual(r['exit'],exit,r)
        if stdout is not None: self.assertEqual(r['stdout'],stdout)
        return r
    def test_identity(self):
        self.check('whoami',stdout='operator\n'); self.check('sudo whoami',stdout='root\n'); self.check('whoami',stdout='operator\n')
        self.assertIn('uid=0(root)',self.check('sudo id')['stdout']); self.check('sudo -u service whoami',stdout='service\n')
    def test_policy(self):
        self.assertIn('root: id',self.check('sudo -l')['stdout']); self.check('sudo -u service write /etc/a x',1); self.check('sudo bash',1); self.check('sudo -u nobody id',1)
    def test_filesystem(self):
        self.check('mkdir work'); self.check('write work/a "hello world"'); self.check('cat work/a',stdout='hello world'); self.check('ls work',stdout='a\n'); self.check('touch work/b'); self.check('cat work/b',stdout='')
        self.check('cat /root/notes',1); self.check('write /etc/identity bad',1); self.check('sudo write /root/notes changed'); self.check('sudo cat /root/notes',stdout='changed'); self.check('cat /root/notes',1)
    def test_isolation(self):
        self.check('write private data'); w=Worker()
        try: self.assertEqual(w.request('cat private')['exit'],1)
        finally: w.close()
    def test_guest(self):
        w=Worker('guest')
        try: self.assertEqual(w.request('sudo id')['exit'],1); self.assertEqual(w.request('sudo -l')['exit'],1)
        finally: w.close()
    def test_no_shell(self):
        self.check('echo $(id) ; | & >',stdout='$(id) ; | & >\n'); self.check('sudo /bin/sh',1); self.check('cat /proc/self/status',1); self.check('id\nwhoami',2); self.check('echo "bad',2)
    def test_invalid_policy(self):
        with tempfile.TemporaryDirectory() as d:
            p=pathlib.Path(d)/'policy'; p.write_text('operator root id allow\nbroken\n'); w=Worker(policy=p)
            try: self.assertEqual(w.request('sudo id')['exit'],1)
            finally: w.close()
    def test_last_rule_wins(self):
        with tempfile.TemporaryDirectory() as d:
            p=pathlib.Path(d)/'policy'; p.write_text('operator root id allow\noperator root id deny\n'); w=Worker(policy=p)
            try: self.assertEqual(w.request('sudo id')['exit'],1)
            finally: w.close()
    def test_unicode_and_json(self): self.check('echo "雪 😀"',stdout='雪 😀\n'); self.check('echo \'a"b\'',stdout='a"b\n')
    def test_limits(self): self.check('write large '+('x'*4097),1); self.check('echo '+('x'*12000),stdout='x'*12000+'\n')
if __name__=='__main__': unittest.main(verbosity=2)
