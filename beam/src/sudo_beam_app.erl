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

-module(sudo_beam_app).
-behaviour(application).
-export([start/2, stop/1]).

start(_Type, _Args) ->
    Token = os:getenv("SUDO_BEAM_TOKEN", ""),
    Caller = os:getenv("SUDO_BEAM_CALLER", "operator"),
    case length(Token) >= 16 andalso lists:member(Caller, ["operator", "guest", "service"]) of
        true ->
            Dispatch = cowboy_router:compile([{'_', [{"/sudo", sudo_beam_ws,
                #{token_hash => crypto:hash(sha256, Token), caller => Caller}}]}]),
            case cowboy:start_clear(sudo_http,
                #{socket_opts => [{port, 8080}], max_connections => 64},
                #{env => #{dispatch => Dispatch}}) of
                {ok, _} -> sudo_beam_sup:start_link();
                Error -> Error
            end;
        false -> {error, invalid_gateway_configuration}
    end.
stop(_State) -> cowboy:stop_listener(sudo_http), ok.
