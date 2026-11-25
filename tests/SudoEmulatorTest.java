// SudoEmulatorTest — framed IPC tests for the Java worker.
// JDK standard library only: no external test framework, no
// extra dependency. Run with `make test` (from the
// repo root). Same 10 cases as the old test suite:
// identity, policy, filesystem, isolation, guest, no-shell,
// invalid policy, last-rule-wins, unicode/JSON, limits.
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.TimeUnit;

public final class SudoEmulatorTest {
    static final Path ROOT = Path.of("").toAbsolutePath();

    record Result(int exit, String stdout, String stderr) {
        static Result parse(String json) {
            int exit = Integer.parseInt(between(json, "\"exit\":", ","));
            return new Result(exit, stringVal(json, "\"stdout\":"), stringVal(json, "\"stderr\":"));
        }

        static String between(String s, String key, String end) {
            int i = s.indexOf(key) + key.length();
            return s.substring(i, s.indexOf(end, i)).trim();
        }

        // Minimal JSON string reader: handles backslash escapes.
        static String stringVal(String json, String key) {
            int i = json.indexOf(key) + key.length();
            while (json.charAt(i) != '"') i++;
            StringBuilder b = new StringBuilder();
            i++;
            while (true) {
                char c = json.charAt(i++);
                if (c == '"') break;
                if (c == '\\') {
                    char e = json.charAt(i++);
                    switch (e) {
                        case '"' -> b.append('"');
                        case '\\' -> b.append('\\');
                        case 'n' -> b.append('\n');
                        case 'r' -> b.append('\r');
                        case 't' -> b.append('\t');
                        case 'u' -> b.append((char) Integer.parseInt(json.substring(i, i + 4), 16));
                        default -> throw new IllegalArgumentException("bad escape \\" + e);
                    }
                    if (e == 'u') i += 4;
                } else {
                    b.append(c);
                }
            }
            return b.toString();
        }
    }

    static final class Worker implements AutoCloseable {
        final Process p;
        final DataInputStream in;
        final DataOutputStream out;

        Worker(String caller, Path policy) throws IOException {
            Path pol = policy == null ? ROOT.resolve("awk/sudoers") : policy;
            p = new ProcessBuilder("java", "-jar", ROOT.resolve("build/sudo.jar").toString(),
                    caller, ROOT.resolve("awk/policy.awk").toString(), pol.toString(), "port")
                    .redirectError(ProcessBuilder.Redirect.INHERIT).start();
            in = new DataInputStream(new BufferedInputStream(p.getInputStream()));
            out = new DataOutputStream(new BufferedOutputStream(p.getOutputStream()));
        }

        Worker(String caller) throws IOException {
            this(caller, null);
        }

        Result request(String text) throws IOException {
            byte[] b = text.getBytes(StandardCharsets.UTF_8);
            out.writeInt(b.length);
            out.write(b);
            out.flush();
            int n = in.readInt();
            byte[] r = in.readNBytes(n);
            if (r.length != n) throw new EOFException("short frame");
            return Result.parse(new String(r, StandardCharsets.UTF_8));
        }

        public void close() {
            try {
                out.close();
            } catch (IOException ignored) {
            }
            try {
                if (!p.waitFor(5, TimeUnit.SECONDS)) p.destroyForcibly();
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                p.destroyForcibly();
            }
        }
    }

    static void check(boolean cond, String what) {
        if (!cond) throw new AssertionError("FAIL: " + what);
    }

    static void eq(Object want, Object got, String what) {
        if (!Objects.equals(want, got))
            throw new AssertionError("FAIL: " + what + " want=[" + want + "] got=[" + got + "]");
    }

    static void eqExit(Result r, int want, String what) {
        eq(want, r.exit(), what + " (exit)");
    }

    static void eqOut(Result r, String want, String what) {
        eqExit(r, 0, what);
        eq(want, r.stdout(), what + " (stdout)");
    }

    static void testIdentity() throws Exception {
        try (Worker w = new Worker("operator")) {
            eqOut(w.request("whoami"), "operator\n", "whoami");
            eqOut(w.request("sudo whoami"), "root\n", "sudo whoami");
            eqOut(w.request("whoami"), "operator\n", "whoami again");
            check(w.request("sudo id").stdout().contains("uid=0(root)"), "sudo id");
            eqOut(w.request("sudo -u service whoami"), "service\n", "sudo -u service whoami");
        }
    }

    static void testPolicy() throws Exception {
        try (Worker w = new Worker("operator")) {
            check(w.request("sudo -l").stdout().contains("root: id"), "sudo -l lists id");
            eqExit(w.request("sudo -u service write /etc/a x"), 1, "service cannot write /etc");
            eqExit(w.request("sudo bash"), 1, "sudo bash denied");
            eqExit(w.request("sudo -u nobody id"), 1, "sudo unknown user");
        }
    }

    static void testFilesystem() throws Exception {
        try (Worker w = new Worker("operator")) {
            eqExit(w.request("mkdir work"), 0, "mkdir work");
            eqExit(w.request("write work/a \"hello world\""), 0, "write work/a");
            eqOut(w.request("cat work/a"), "hello world", "cat work/a");
            eqOut(w.request("ls work"), "a\n", "ls work");
            eqExit(w.request("touch work/b"), 0, "touch work/b");
            eqOut(w.request("cat work/b"), "", "cat work/b");
            eqExit(w.request("cat /root/notes"), 1, "cat /root/notes denied");
            eqExit(w.request("write /etc/identity bad"), 1, "write /etc/identity denied");
            eqExit(w.request("sudo write /root/notes changed"), 0, "sudo write /root/notes");
            eqOut(w.request("sudo cat /root/notes"), "changed", "sudo cat /root/notes");
            eqExit(w.request("cat /root/notes"), 1, "cat /root/notes still denied");
        }
    }

    static void testIsolation() throws Exception {
        try (Worker w1 = new Worker("operator")) {
            eqExit(w1.request("write private data"), 0, "write private");
            try (Worker w2 = new Worker("operator")) {
                eqExit(w2.request("cat private"), 1, "second session cannot see private");
            }
        }
    }

    static void testGuest() throws Exception {
        try (Worker w = new Worker("guest")) {
            eqExit(w.request("sudo id"), 1, "guest sudo id denied");
            eqExit(w.request("sudo -l"), 1, "guest sudo -l denied");
        }
    }

    static void testNoShell() throws Exception {
        try (Worker w = new Worker("operator")) {
            eqOut(w.request("echo $(id) ; | & >"), "$(id) ; | & >\n", "metacharacters literal");
            eqExit(w.request("sudo /bin/sh"), 1, "sudo /bin/sh denied");
            eqExit(w.request("cat /proc/self/status"), 1, "cat /proc denied");
            eqExit(w.request("id\nwhoami"), 2, "newline in request");
            eqExit(w.request("echo \"bad"), 2, "unclosed quote");
        }
    }

    static void testInvalidPolicy() throws Exception {
        Path d = Files.createTempDirectory("sudo-beam-test");
        Path p = d.resolve("policy");
        Files.writeString(p, "operator root id allow\nbroken\n");
        try (Worker w = new Worker("operator", p)) {
            eqExit(w.request("sudo id"), 1, "malformed policy denies");
        }
    }

    static void testLastRuleWins() throws Exception {
        Path d = Files.createTempDirectory("sudo-beam-test");
        Path p = d.resolve("policy");
        Files.writeString(p, "operator root id allow\noperator root id deny\n");
        try (Worker w = new Worker("operator", p)) {
            eqExit(w.request("sudo id"), 1, "last rule wins");
        }
    }

    static void testUnicodeAndJson() throws Exception {
        try (Worker w = new Worker("operator")) {
            eqOut(w.request("echo \"\u96ea \uD83D\uDE00\""), "\u96ea \uD83D\uDE00\n", "unicode echo");
            eqOut(w.request("echo 'a\"b'"), "a\"b\n", "quote in echo");
        }
    }

    static void testLimits() throws Exception {
        try (Worker w = new Worker("operator")) {
            eqExit(w.request("write large " + "x".repeat(4097)), 1, "file too large");
            eqOut(w.request("echo " + "x".repeat(12000)), "x".repeat(12000) + "\n", "12k echo");
        }
    }

    interface ThrowingRunnable {
        void run() throws Exception;
    }

    record T(String name, ThrowingRunnable run) {
    }

    public static void main(String[] args) {
        List<T> tests = List.of(
                new T("test_identity", SudoEmulatorTest::testIdentity),
                new T("test_policy", SudoEmulatorTest::testPolicy),
                new T("test_filesystem", SudoEmulatorTest::testFilesystem),
                new T("test_isolation", SudoEmulatorTest::testIsolation),
                new T("test_guest", SudoEmulatorTest::testGuest),
                new T("test_no_shell", SudoEmulatorTest::testNoShell),
                new T("test_invalid_policy", SudoEmulatorTest::testInvalidPolicy),
                new T("test_last_rule_wins", SudoEmulatorTest::testLastRuleWins),
                new T("test_unicode_and_json", SudoEmulatorTest::testUnicodeAndJson),
                new T("test_limits", SudoEmulatorTest::testLimits));
        int passed = 0;
        for (T t : tests) {
            try {
                t.run().run();
                System.out.println(t.name() + " ... ok");
                passed++;
            } catch (Throwable e) {
                System.out.println(t.name() + " ... FAIL: " + e.getMessage());
            }
        }
        System.out.println("\nRan " + tests.size() + " tests, " + passed + " passed");
        if (passed == tests.size()) {
            System.out.println("OK");
        } else {
            System.exit(1);
        }
    }
}
