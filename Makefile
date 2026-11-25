JAR = build/sudo.jar
.PHONY: all test clean beam
all: $(JAR)
$(JAR): java/src/SudoEmulator.java
	mkdir -p build/classes
	javac --release 17 -Xlint:all -Werror -d build/classes $<
	jar --create --file $@ --main-class SudoEmulator -C build/classes .
test: $(JAR)
	python3 tests/test_port.py
beam:
	cd beam && rebar3 compile
clean:
	rm -rf build beam/_build
