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

JAR = build/sudo.jar
.PHONY: all test smoke clean beam
all: $(JAR)
$(JAR): java/src/SudoEmulator.java
	mkdir -p build/classes
	javac --release 17 -Xlint:all -Werror -d build/classes $<
	jar --create --file $@ --main-class SudoEmulator -C build/classes .
test: $(JAR)
	mkdir -p build/test-classes
	javac --release 17 -Xlint:all -Werror -d build/test-classes tests/SudoEmulatorTest.java
	java -cp build/test-classes SudoEmulatorTest
smoke: $(JAR)
	mkdir -p build/test-classes
	javac --release 17 -Xlint:all -Werror -d build/test-classes tests/WsSmoke.java
	java -cp build/test-classes WsSmoke
beam:
	cd beam && rebar3 compile
clean:
	rm -rf build beam/_build
