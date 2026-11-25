-module(sudo_beam_ffi).
-export([open/1, send/2, close/1]).

%% Erlang Port foreign-process interface: unsigned big-endian 32-bit length + UTF-8.
open(Caller) ->
    Java = os:getenv("SUDO_BEAM_JAVA", "/usr/bin/java"),
    Jar = os:getenv("SUDO_BEAM_JAR", "/app/sudo.jar"),
    Awk = os:getenv("SUDO_BEAM_AWK", "/app/awk/policy.awk"),
    Policy = os:getenv("SUDO_BEAM_POLICY", "/app/awk/sudoers"),
    open_port({spawn_executable, Java}, [binary, {packet, 4}, use_stdio, exit_status,
        {args, ["-Xms8m", "-Xmx32m", "-jar", Jar, Caller, Awk, Policy, "port"]}]).
send(Port, Data) when is_binary(Data), byte_size(Data) =< 16384 ->
    try erlang:port_command(Port, Data, [nosuspend]) of
        true -> ok;
        false -> {error, busy}
    catch error:badarg -> {error, closed} end;
send(_, _) -> {error, invalid_frame}.
close(Port) when is_port(Port) -> catch erlang:port_close(Port), ok;
close(_) -> ok.
