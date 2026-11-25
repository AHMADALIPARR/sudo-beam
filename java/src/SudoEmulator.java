import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.TimeUnit;

public final class SudoEmulator {
    static final int MAX_FRAME = 16384, MAX_NODES = 256, MAX_FILE = 4096;
    static final List<String> COMMANDS = List.of("id", "whoami", "pwd", "ls", "cat", "mkdir", "touch", "write", "echo");
    static final Map<String,Integer> UIDS = Map.of("root",0,"operator",1000,"guest",1001,"service",1002);
    record Result(int exit, String stdout, String stderr) {
        static Result ok(String s) { return new Result(0,s,""); }
        static Result err(int n,String s) { return new Result(n,"",s+"\n"); }
        String json() { return "{\"exit\":"+exit+",\"stdout\":"+quote(stdout)+",\"stderr\":"+quote(stderr)+"}"; }
    }
    record Node(String owner, boolean dir, String data) {}
    final Map<String,Node> fs = new TreeMap<>();
    final String caller;
    final Path awkScript, policy;
    SudoEmulator(String caller, Path awkScript, Path policy) {
        if (!UIDS.containsKey(caller) || caller.equals("root")) throw new IllegalArgumentException("invalid session principal");
        this.caller=caller; this.awkScript=awkScript.toAbsolutePath(); this.policy=policy.toAbsolutePath();
        fs.put("/",new Node("root",true,"")); fs.put("/etc",new Node("root",true,""));
        fs.put("/etc/identity",new Node("root",false,"sudo-beam virtual system\n"));
        fs.put("/home",new Node("root",true,""));
        for (String u: UIDS.keySet()) if (!u.equals("root")) fs.put("/home/"+u,new Node(u,true,""));
        fs.put("/root",new Node("root",true,""));
        fs.put("/root/notes",new Node("root",false,"virtual root workspace\n"));
    }
    static String quote(String s) {
        StringBuilder b=new StringBuilder("\"");
        for (int i=0;i<s.length();i++) { char c=s.charAt(i); switch(c) {
            case '"' -> b.append("\\\""); case '\\' -> b.append("\\\\"); case '\n' -> b.append("\\n");
            case '\r' -> b.append("\\r"); case '\t' -> b.append("\\t");
            default -> { if(c<32 || Character.isSurrogate(c)) b.append(String.format("\\u%04x",(int)c)); else b.append(c); }
        }} return b.append('"').toString();
    }
    static List<String> tokenize(String s) {
        List<String> a=new ArrayList<>(); StringBuilder b=new StringBuilder(); char q=0; boolean active=false;
        for(int i=0;i<s.length();i++) { char c=s.charAt(i);
            if(c=='\n'||c=='\r'||c==0) throw new IllegalArgumentException("one command per request");
            if(q!=0) { if(c==q) q=0; else b.append(c); active=true; }
            else if(c=='\''||c=='"') { q=c; active=true; }
            else if(Character.isWhitespace(c)) { if(active){a.add(b.toString());b.setLength(0);active=false;} }
            else { b.append(c); active=true; }
        }
        if(q!=0) throw new IllegalArgumentException("unclosed quote"); if(active)a.add(b.toString());
        if(a.size()>64) throw new IllegalArgumentException("too many arguments"); return a;
    }
    boolean allowed(String target,String cmd) {
        if(!UIDS.containsKey(target)||!COMMANDS.contains(cmd)) return false;
        Process p=null;
        try {
            p=new ProcessBuilder("/usr/bin/awk","-v","caller="+caller,"-v","target="+target,"-v","cmd="+cmd,"-f",awkScript.toString(),policy.toString()).redirectError(ProcessBuilder.Redirect.DISCARD).start();
            p.getOutputStream().close();
            if(!p.waitFor(1,TimeUnit.SECONDS)) return false;
            return p.exitValue()==0 && new String(p.getInputStream().readNBytes(16),StandardCharsets.UTF_8).trim().equals("allow");
        } catch(IOException e){return false;} catch(InterruptedException e){Thread.currentThread().interrupt();return false;}
        finally { if(p!=null){p.destroyForcibly();try{p.getInputStream().close();}catch(IOException ignored){}} }
    }
    Result request(String input) {
        try {
            if(input.getBytes(StandardCharsets.UTF_8).length>MAX_FRAME) return Result.err(2,"request too large");
            List<String> a=tokenize(input); if(a.isEmpty())return Result.err(2,"empty command");
            String user=caller; int pos=0;
            if(a.get(0).equals("sudo")) {
                pos=1; user="root";
                if(pos<a.size() && a.get(pos).equals("-u")){ if(pos+1>=a.size())return Result.err(2,"sudo -u requires a user");user=a.get(pos+1);pos+=2; }
                if(!UIDS.containsKey(user))return Result.err(1,"sudo: unknown user");
                if(pos<a.size() && a.get(pos).equals("-l")) {
                    if(pos+1!=a.size())return Result.err(2,"usage: sudo [-u USER] -l");
                    StringBuilder out=new StringBuilder();for(String c:COMMANDS)if(allowed(user,c))out.append(user).append(": ").append(c).append('\n');
                    return out.length()==0?Result.err(1,"sudo: no permitted commands"):Result.ok(out.toString());
                }
                if(pos<a.size() && a.get(pos).equals("--"))pos++;
                if(pos>=a.size())return Result.err(2,"usage: sudo [-u USER] COMMAND [ARGS]");
                if(!allowed(user,a.get(pos)))return Result.err(1,"sudo: policy denied");
            }
            return command(user,a.get(pos),a.subList(pos+1,a.size()));
        }catch(IllegalArgumentException e){return Result.err(2,e.getMessage());}
    }
    static String home(String u){return u.equals("root")?"/root":"/home/"+u;}
    static String path(String u,String s){
        if(s.length()>512 || s.isEmpty())throw new IllegalArgumentException("invalid path");
        Deque<String> parts=new ArrayDeque<>();
        for(String x:(s.startsWith("/")?s:home(u)+"/"+s).split("/")){
            if(x.isEmpty()||x.equals("."))continue;
            if(x.equals("..")){if(!parts.isEmpty())parts.removeLast();continue;}
            if(!x.matches("[A-Za-z0-9._-]{1,64}"))throw new IllegalArgumentException("invalid path component");parts.add(x);
        }return "/"+String.join("/",parts);
    }
    static String parent(String p){int i=p.lastIndexOf('/');return i<=0?"/":p.substring(0,i);}
    boolean visible(String u,String p){
        if(u.equals("root"))return true;
        for(String x=p;!x.equals("/");x=parent(x)){
            Node n=fs.get(x);if(n!=null && (x.equals("/root")||x.startsWith("/root/")||x.startsWith("/home/"))&&!n.owner.equals(u))return false;
        }return true;
    }
    boolean writable(String u,String p){Node n=fs.get(p);return n!=null&&(u.equals("root")||n.owner.equals(u))&&visible(u,p);}
    static void arity(List<String> a,int n,String usage){if(a.size()!=n)throw new IllegalArgumentException("usage: "+usage);}
    Result command(String u,String c,List<String> a){
        switch(c){
            case "whoami": arity(a,0,c);return Result.ok(u+"\n");
            case "id": arity(a,0,c);return Result.ok("uid="+UIDS.get(u)+"("+u+") gid="+UIDS.get(u)+"("+u+") [virtual]\n");
            case "pwd": arity(a,0,c);return Result.ok(home(u)+"\n");
            case "echo": return Result.ok(String.join(" ",a)+"\n");
            case "ls": {
                if(a.size()>1)throw new IllegalArgumentException("usage: ls [PATH]");String p=path(u,a.isEmpty()?home(u):a.get(0));Node n=fs.get(p);
                if(n==null||!visible(u,p))return Result.err(1,"ls: inaccessible path");if(!n.dir)return Result.ok(p+"\n");
                StringBuilder out=new StringBuilder();for(String x:fs.keySet())if(!x.equals(p)&&parent(x).equals(p)&&visible(u,x))out.append(x.substring(x.lastIndexOf('/')+1)).append(fs.get(x).dir?"/":"").append('\n');return Result.ok(out.toString());
            }
            case "cat": {
                arity(a,1,"cat PATH");String p=path(u,a.get(0));Node n=fs.get(p);if(n==null||n.dir||!visible(u,p))return Result.err(1,"cat: inaccessible file");return Result.ok(n.data);
            }
            case "mkdir": case "touch": case "write": {
                arity(a,c.equals("write")?2:1,c.equals("write")?"write PATH TEXT":c+" PATH");String p=path(u,a.get(0));Node old=fs.get(p), par=fs.get(parent(p));
                if(old!=null){if(c.equals("mkdir")||old.dir||!writable(u,p))return Result.err(1,c+": permission denied or path exists");if(c.equals("touch"))return Result.ok("");}
                else if(par==null||!par.dir||!writable(u,parent(p))||fs.size()>=MAX_NODES)return Result.err(1,c+": parent inaccessible or capacity reached");
                String data=c.equals("write")?a.get(1):"";if(data.getBytes(StandardCharsets.UTF_8).length>MAX_FILE)return Result.err(1,"file too large");
                fs.put(p,new Node(old==null?u:old.owner,c.equals("mkdir"),data));return Result.ok("");
            }
            default: return Result.err(127,"unknown virtual command: "+c);
        }
    }
    void serve() throws IOException {
        DataInputStream in=new DataInputStream(new BufferedInputStream(System.in));DataOutputStream out=new DataOutputStream(new BufferedOutputStream(System.out));
        while(true){int n;try{n=in.readInt();}catch(EOFException e){return;}if(n<0||n>MAX_FRAME)return;byte[] bytes=in.readNBytes(n);if(bytes.length!=n)return;
            byte[] result=request(new String(bytes,StandardCharsets.UTF_8)).json().getBytes(StandardCharsets.UTF_8);out.writeInt(result.length);out.write(result);out.flush();}
    }
    public static void main(String[] args)throws IOException {
        if(args.length<4||args.length>5)throw new IllegalArgumentException("usage: SudoEmulator CALLER AWK POLICY port|cli [COMMAND]");
        SudoEmulator e=new SudoEmulator(args[0],Path.of(args[1]),Path.of(args[2]));
        if(args[3].equals("port")&&args.length==4)e.serve();
        else if(args[3].equals("cli")&&args.length==5){Result r=e.request(args[4]);System.out.print(r.stdout);System.err.print(r.stderr);System.exit(r.exit);}
        else throw new IllegalArgumentException("invalid mode");
    }
}
