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
