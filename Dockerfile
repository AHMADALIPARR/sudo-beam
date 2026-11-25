FROM erlang:27-bookworm AS build
RUN apt-get update && apt-get install -y --no-install-recommends openjdk-17-jdk-headless && rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY java java
RUN mkdir -p /out/classes && javac --release 17 -Xlint:all -Werror -d /out/classes java/src/SudoEmulator.java && jar --create --file /out/sudo.jar --main-class SudoEmulator -C /out/classes .
COPY beam beam
RUN cd beam && rebar3 compile

FROM erlang:27-bookworm
RUN apt-get update && apt-get install -y --no-install-recommends openjdk-17-jre-headless mawk && rm -rf /var/lib/apt/lists/* && useradd --system --user-group --uid 10001 --create-home emulator
WORKDIR /app
COPY --from=build /out/sudo.jar /app/sudo.jar
COPY --from=build /src/beam/_build/default/lib /app/lib
COPY awk /app/awk
USER 10001:10001
EXPOSE 8080
CMD ["sh", "-c", "exec erl +S 2:2 -pa /app/lib/*/ebin -noshell -eval 'case application:ensure_all_started(sudo_beam) of {ok,_} -> receive stop -> ok end; Error -> io:format(\"~p~n\", [Error]), halt(1) end.'"]
