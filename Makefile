# Makefile for Unix-like systems:
#   macOS, Linux, Raspberry Pi, MinGW

PREFIX?=/usr/local
CFLAGS=-std=c11

# ARM platforms
ifneq (,$(findstring arm,$(shell uname -m)))
	# Raspberry Pi includes
	INCLUDES=-I/opt/vc/include/
endif

# Apple
ifeq ($(shell uname),Darwin)
	PLATFORM=apple
endif

# Linux
ifeq ($(shell uname),Linux)
	CFLAGS+=-fPIC
endif

# MinGW
ifneq (,$(findstring MINGW,$(shell uname -s)))
	PLATFORM=mingw
	CC=gcc
	INCLUDES=-I/usr/local/include/
endif

SOURCES=$(notdir $(wildcard src/*.c))
OBJECTS=$(addprefix build/,$(notdir $(SOURCES:.c=.o)))

# Install directory and filename for the MinGW Windows installer
INSTALLER_DIR=build/win-installer-mingw
INSTALLER_FNAME=simple2d-windows-mingw.zip

# Helper functions

define task_msg
	@printf "\n\033[1;34m==>\033[39m $(1)\033[0m\n\n"
endef

define info_msg
	@printf "\033[1;36mInfo:\e[39m $(1)\033[0m\n"
endef

define run_test
	$(call task_msg,Running $(1).c)
	@cd test/; ./$(1)
endef

# Targets

all: prereqs install-deps $(SOURCES)
	ar -vq build/libsimple2d.a $(OBJECTS)
	cp bin/simple2d.sh build/simple2d
	chmod 0777 build/simple2d
	rm build/*.o

prereqs:
	$(call task_msg,Building)
	mkdir -p build

install-deps:
ifeq ($(PLATFORM),mingw)
	$(call task_msg,Installing dependencies for MinGW)
	mkdir -p $(PREFIX)/include/
	mkdir -p $(PREFIX)/lib/
	mkdir -p $(PREFIX)/bin/
	cp -R deps/mingw/include/* $(PREFIX)/include
	cp -R deps/mingw/lib/*     $(PREFIX)/lib
	cp -R deps/mingw/bin/*     $(PREFIX)/bin
endif

$(SOURCES):
	$(CC) $(CFLAGS) $(INCLUDES) src/$@ -c -o build/$(basename $@).o

install:
	$(call task_msg,Installing Simple 2D)
	mkdir -p $(PREFIX)/include/
	mkdir -p $(PREFIX)/lib/
	mkdir -p $(PREFIX)/bin/
	cp include/simple2d.h  $(PREFIX)/include/
	cp build/libsimple2d.a $(PREFIX)/lib/
	cp build/simple2d      $(PREFIX)/bin/

ifeq ($(PLATFORM),apple)
release: clean all
	$(call task_msg,Building iOS and tvOS release)
	cp -r deps/xcode/Simple2D.xcodeproj build
	# TODO: make xcpretty optional
	cd build && \
	xcodebuild -sdk iphoneos         | xcpretty && \
	xcodebuild -sdk iphonesimulator  | xcpretty && \
	xcodebuild -sdk appletvos        | xcpretty && \
	xcodebuild -sdk appletvsimulator | xcpretty
	mkdir -p build/Release-ios-universal
	mkdir -p build/Release-tvos-universal
	lipo build/Release-iphoneos/libsimple2d.a  build/Release-iphonesimulator/libsimple2d.a  -create -output build/Release-ios-universal/libsimple2d.a
	lipo build/Release-appletvos/libsimple2d.a build/Release-appletvsimulator/libsimple2d.a -create -output build/Release-tvos-universal/libsimple2d.a
	mkdir -p build/ios build/tvos
	libtool -static build/Release-ios-universal/libsimple2d.a  deps/ios/SDL2.framework/SDL2  -o build/ios/Simple2D
	libtool -static build/Release-tvos-universal/libsimple2d.a deps/tvos/SDL2.framework/SDL2 -o build/tvos/Simple2D
	mkdir -p build/ios/Simple2D.framework/Headers
	mkdir -p build/tvos/Simple2D.framework/Headers
	cp include/simple2d.h build/ios/Simple2D.framework/Headers
	cp include/simple2d.h build/tvos/Simple2D.framework/Headers
	cp -r deps/ios/include/SDL2  build/ios/Simple2D.framework/Headers
	cp -r deps/tvos/include/SDL2 build/tvos/Simple2D.framework/Headers
	cp deps/xcode/Info.plist build/ios/Simple2D.framework/Info.plist
	cp deps/xcode/Info.plist build/tvos/Simple2D.framework/Info.plist
	mv build/ios/Simple2D  build/ios/Simple2D.framework
	mv build/tvos/Simple2D build/tvos/Simple2D.framework
	$(call info_msg,iOS framework built at \`build/ios/Simple2D.framework\`)
	$(call info_msg,tvOS framework built at \`build/tvos/Simple2D.framework\`)
endif

ifeq ($(PLATFORM),mingw)
release: clean all
	mkdir -p $(INSTALLER_DIR)/include
	mkdir -p $(INSTALLER_DIR)/lib
	mkdir -p $(INSTALLER_DIR)/bin
	cp -R deps/mingw/include/*    $(INSTALLER_DIR)/include
	cp -R deps/mingw/lib/*        $(INSTALLER_DIR)/lib
	cp -R deps/mingw/bin/*        $(INSTALLER_DIR)/bin
	cp    deps/LICENSES.md        $(INSTALLER_DIR)
	cp include/simple2d.h         $(INSTALLER_DIR)/include
	cp build/libsimple2d.a        $(INSTALLER_DIR)/lib
	cp build/simple2d             $(INSTALLER_DIR)/bin
	cp bin/win-installer-mingw.sh $(INSTALLER_DIR)/install.sh
	PowerShell -Command "& { Add-Type -A 'System.IO.Compression.FileSystem'; [IO.Compression.ZipFile]::CreateFromDirectory('$(INSTALLER_DIR)', 'build\$(INSTALLER_FNAME)'); }"
endif

clean:
	$(call task_msg,Cleaning)
	rm -rf build/*
ifeq ($(PLATFORM),mingw)
	rm -rf $(INSTALLER_DIR)
	rm -f test/auto.exe
	rm -f test/triangle.exe
	rm -f test/testcard.exe
	rm -f test/audio.exe
	rm -f test/controller.exe
else
	rm -f test/auto
	rm -f test/triangle
	rm -f test/testcard
	rm -f test/audio
	rm -f test/controller
endif

uninstall:
	$(call task_msg,Uninstalling)
	rm -f /usr/local/include/simple2d.h
	rm -f /usr/local/lib/libsimple2d.a
	rm -f /usr/local/bin/simple2d

test:
	$(call task_msg,Building tests)
	$(CC) $(CFLAGS) test/auto.c       `simple2d --libs` -o test/auto
	$(CC) $(CFLAGS) test/triangle.c   `simple2d --libs` -o test/triangle
	$(CC) $(CFLAGS) test/testcard.c   `simple2d --libs` -o test/testcard
	$(CC) $(CFLAGS) test/audio.c      `simple2d --libs` -o test/audio
	$(CC) $(CFLAGS) test/controller.c `simple2d --libs` -o test/controller

rebuild: uninstall clean all install test

auto:
	$(call run_test,auto)

triangle:
	$(call run_test,triangle)

testcard:
	$(call run_test,testcard)

audio:
	$(call run_test,audio)

controller:
	$(call run_test,controller)

.PHONY: build test
