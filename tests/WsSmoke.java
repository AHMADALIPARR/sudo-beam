// WsSmoke — live gateway smoke test.
// JDK standard library only (java.net.http.WebSocket). Requires
// the gateway running on 127.0.0.1:8080 and SUDO_BEAM_TOKEN set.
// Run with `make smoke`.
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.WebSocket;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CompletionStage;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;

public final class WsSmoke {
    static final class Listener implements WebSocket.Listener {
        final BlockingQueue<String> messages = new LinkedBlockingQueue<>();
        final StringBuilder cur = new StringBuilder();

        @Override
        public CompletionStage<?> onText(WebSocket ws, CharSequence data, boolean last) {
            cur.append(data);
            if (last) {
                messages.add(cur.toString());
                cur.setLength(0);
            }
            ws.request(1);
            return CompletableFuture.completedFuture(null);
        }

        @Override
        public void onError(WebSocket ws, Throwable error) {
            messages.add("ERROR:" + error);
        }
    }

    // Minimal JSON string reader for the flat {"exit":N,"stdout":"...","stderr":"..."} replies.
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

    static int exitOf(String json) {
        int i = json.indexOf("\"exit\":") + 8;
        int j = json.indexOf(',', i);
        return Integer.parseInt(json.substring(i, j).trim());
    }

    public static void main(String[] args) throws Exception {
        String token = System.getenv("SUDO_BEAM_TOKEN");
        if (token == null || token.isEmpty()) {
            System.err.println("SUDO_BEAM_TOKEN not set");
            System.exit(2);
        }
        String caller = System.getenv().getOrDefault("SUDO_BEAM_CALLER", "operator");
        Listener listener = new Listener();
        WebSocket ws = HttpClient.newHttpClient().newWebSocketBuilder()
                .header("Authorization", "Bearer " + token)
                .buildAsync(URI.create("ws://127.0.0.1:8080/sudo"), listener)
                .get(20, TimeUnit.SECONDS);
        try {
            java.util.function.Function<String, String> request = text -> {
                try {
                    ws.sendText(text, true).join();
                    String msg = listener.messages.poll(20, TimeUnit.SECONDS);
                    if (msg == null) throw new IllegalStateException("no reply to: " + text);
                    if (msg.startsWith("ERROR:")) throw new IllegalStateException(msg);
                    return msg;
                } catch (RuntimeException e) {
                    throw e;
                } catch (Exception e) {
                    throw new RuntimeException(e);
                }
            };
            String whoami = request.apply("whoami");
            if (!stringVal(whoami, "\"stdout\":").equals(caller + "\n"))
                throw new AssertionError("whoami: " + whoami);
            String id = request.apply("sudo id");
            if (exitOf(id) != (caller.equals("operator") ? 0 : 1))
                throw new AssertionError("sudo id: " + id);
            if (exitOf(request.apply("write example \"hello beam\"")) != 0)
                throw new AssertionError("write example failed");
            String cat = request.apply("cat example");
            if (!stringVal(cat, "\"stdout\":").equals("hello beam"))
                throw new AssertionError("cat example: " + cat);
            if (exitOf(request.apply("sudo /bin/sh")) != 1)
                throw new AssertionError("sudo /bin/sh was not denied");
            System.out.println("Live WebSocket smoke test: PASS");
        } finally {
            ws.sendClose(WebSocket.NORMAL_CLOSURE, "").join();
        }
    }
}
