DESTDIR = /
CONFIG = Release

install:
	xcodebuild -configuration $(CONFIG) -scheme passx install DSTROOT=$(DESTDIR)

.PHONY: install
