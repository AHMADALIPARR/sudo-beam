% Copyright (C) 2026 AHMADALIPARR
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU Affero General Public License as published by
% the Free Software Foundation, version 3 of the License.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU Affero General Public License for more details.
%
% You should have received a copy of the GNU Affero General Public License
% along with this program.  If not, see <https://www.gnu.org/licenses/>.
%
% SPDX-License-Identifier: AGPL-3.0-only

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
