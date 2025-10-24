ZIG = zig
PREFIX ?=/usr

.PHONY: all install fmt


all:
	if ! [ -e "./src/external-bin" ]; then \
		mkdir ./src/external-bin -p; \
	fi
	cd ./external/minisign/ && zig build -Doptimize=ReleaseSmall --prefix "$$(realpath ../../src/external-bin)"
	zig build -Doptimize=ReleaseFast

distclean: clean

clean:
	rm -rf ./external/minisign/zig-out 
	rm -rf ./external/minisign/.zig-cache
	rm -rf ./src/external-bin
	rm -rf ./zig-out
	rm -rf ./.zig-cache

install:
	install -Dm755 ./zig-out/bin/hburg "$(PREFIX)/bin/hburg"

fmt:
	find src -type f -name '*.zig' -exec zig fmt {} +
