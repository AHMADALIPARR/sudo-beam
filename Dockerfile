# Copyright (C) 2026 AHMADALIPARR
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, version 3 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# SPDX-License-Identifier: AGPL-3.0-only

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
