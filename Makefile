DESTDIR = /
CONFIG = Release

build:
	xcodebuild -configuration $(CONFIG) -scheme passx build

install:
	xcodebuild -configuration $(CONFIG) -scheme passx install DSTROOT=$(DESTDIR)

clean:
	xcodebuild clean

.PHONY: build install clean
