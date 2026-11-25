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
