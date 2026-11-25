-module(sudo_beam_ws).
-export([init/2, websocket_init/1, websocket_handle/2, websocket_info/2, terminate/3]).

init(Req, #{token_hash := Expected, caller := Caller}) ->
    case cowboy_req:header(<<"authorization">>, Req) of
        <<"Bearer ", Token/binary>> ->
            case crypto:hash_equals(crypto:hash(sha256, Token), Expected) of
                true -> {cowboy_websocket, Req, #{caller => Caller, port => undefined, pending => undefined},
                    #{idle_timeout => 60000, max_frame_size => 16384}};
                false -> unauthorized(Req)
            end;
        _ -> unauthorized(Req)
    end.
unauthorized(Req) -> {ok, cowboy_req:reply(401, #{<<"www-authenticate">> => <<"Bearer">>}, <<"Unauthorized">>, Req), #{}}.

websocket_init(State = #{caller := Caller}) ->
    process_flag(trap_exit, true),
    try sudo_beam_ffi:open(Caller) of
        Port -> {ok, State#{port => Port}}
    catch error:_ -> {reply, {close, 1011, <<"Java worker unavailable">>}, State} end.

websocket_handle({text, Data}, State = #{port := Port, pending := undefined}) ->
    case sudo_beam_ffi:send(Port, Data) of
        ok -> Ref = make_ref(), Timer = erlang:send_after(15000, self(), {worker_timeout, Ref}),
              {ok, State#{pending => {Ref, Timer}}};
        {error, _} -> {reply, {close, 1011, <<"Worker unavailable">>}, State}
    end;
websocket_handle({text, _}, State) ->
    {reply, {close, 1008, <<"Wait for previous response">>}, State};
websocket_handle({binary, _}, State) -> {reply, {close, 1003, <<"Text frames only">>}, State};
websocket_handle(_, State) -> {ok, State}.

websocket_info({Port, {data, Data}}, State = #{port := Port, pending := {_, Timer}}) ->
    erlang:cancel_timer(Timer), {reply, {text, Data}, State#{pending => undefined}};
websocket_info({worker_timeout, Ref}, State = #{pending := {Ref, _}}) ->
    {reply, {close, 1011, <<"Worker timeout">>}, State};
websocket_info({Port, {exit_status, _}}, State = #{port := Port}) ->
    {reply, {close, 1011, <<"Worker exited">>}, State};
websocket_info({'EXIT', Port, _}, State = #{port := Port}) ->
    {reply, {close, 1011, <<"Worker closed">>}, State};
websocket_info(_, State) -> {ok, State}.

terminate(_, _, State) ->
    case maps:get(pending, State, undefined) of {_, Timer} -> erlang:cancel_timer(Timer); _ -> ok end,
    sudo_beam_ffi:close(maps:get(port, State, undefined)).
