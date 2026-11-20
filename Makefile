DESTDIR = /
CONFIG = Release

build:
	xcodebuild -configuration $(CONFIG) -scheme passx build

install:
	xcodebuild -configuration $(CONFIG) -scheme passx install DSTROOT=$(DESTDIR)

clean:
	xcodebuild clean
	rm -rf build

# Packages build/passx-<version>.dmg; see scripts/build-dmg.sh for signing/notarization env vars
dmg:
	scripts/build-dmg.sh

.PHONY: build install clean dmg
