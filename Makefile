
all: build/Examator.build/Release

build/Examator.build/Release:
	xcodebuild

clean:
	rm -rf openssl-* libssh* build libcrypto*dylib libssh*dylib
