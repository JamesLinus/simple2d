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
	XCPRETTY_STATUS=$(shell xcpretty -v &>/dev/null; echo $$?)
	ifeq ($(XCPRETTY_STATUS),0)
		XCPRETTY=xcpretty
	else
		XCPRETTY=cat
	endif
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

VERSION=$(shell bash bin/simple2d.sh -v)

# Install directory and filename for the MinGW Windows installer
INSTALLER_DIR=build/win-installer-mingw
INSTALLER_FNAME=simple2d-windows-mingw-$(VERSION).zip

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
install-frameworks:
ifeq ($(shell test -d build/ios/Simple2D.framework && test -d build/tvos/Simple2D.framework; echo $$?),1)
	$(error Frameworks missing, run `release` target first)
endif
	$(call task_msg,Installing iOS and tvOS frameworks)
	mkdir -p $(PREFIX)/Frameworks/Simple2D/iOS/
	mkdir -p $(PREFIX)/Frameworks/Simple2D/tvOS/
	cp -R build/ios/Simple2D.framework  $(PREFIX)/Frameworks/Simple2D/iOS/
	cp -R build/tvos/Simple2D.framework $(PREFIX)/Frameworks/Simple2D/tvOS/
endif

ifeq ($(PLATFORM),apple)
release: clean all
	$(call task_msg,Building iOS and tvOS release)
ifneq ($(XCPRETTY_STATUS),0)
	$(call info_msg,xcpretty not found!)
	$(call info_msg,  Run \`gem install xcpretty\` for nicer xcodebuild output.)
endif
	cp -R deps/xcode/Simple2D.xcodeproj build
	cd build && \
	xcodebuild -sdk iphoneos         | $(XCPRETTY) && \
	xcodebuild -sdk iphonesimulator  | $(XCPRETTY) && \
	xcodebuild -sdk appletvos        | $(XCPRETTY) && \
	xcodebuild -sdk appletvsimulator | $(XCPRETTY)
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
	cp -R deps/ios/include/SDL2  build/ios/Simple2D.framework/Headers
	cp -R deps/tvos/include/SDL2 build/tvos/Simple2D.framework/Headers
	cp deps/xcode/Info.plist build/ios/Simple2D.framework/Info.plist
	cp deps/xcode/Info.plist build/tvos/Simple2D.framework/Info.plist
	mv build/ios/Simple2D  build/ios/Simple2D.framework
	mv build/tvos/Simple2D build/tvos/Simple2D.framework
	mkdir -p build/apple-frameworks/Simple2D/iOS
	mkdir -p build/apple-frameworks/Simple2D/tvOS
	cp -R build/ios/*  build/apple-frameworks/Simple2D/iOS/
	cp -R build/tvos/* build/apple-frameworks/Simple2D/tvOS/
	cd build/apple-frameworks; zip -r simple2d-apple-frameworks-$(VERSION).zip *
	mv build/apple-frameworks/simple2d-apple-frameworks-$(VERSION).zip build/
	$(call info_msg,iOS framework built at \`build/ios/Simple2D.framework\`)
	$(call info_msg,tvOS framework built at \`build/tvos/Simple2D.framework\`)
	$(call info_msg,Frameworks zipped at \`build/simple2d-apple-frameworks-$(VERSION).zip\`)
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
	rm -f  /usr/local/include/simple2d.h
	rm -f  /usr/local/lib/libsimple2d.a
	rm -f  /usr/local/bin/simple2d
ifeq ($(PLATFORM),apple)
	rm -rf /usr/local/Frameworks/Simple2D/
endif

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

ifeq ($(PLATFORM),apple)
ios:
ifeq ($(shell test -d build/ios/Simple2D.framework; echo $$?),1)
	$(error Simple2D.framework missing, run `release` target first)
endif
	$(call task_msg,Running iOS test)
	cp -R deps/xcode/ios/* build/ios
	cp test/triangle-ios-tvos.c build/ios/main.c
	cd build/ios && xcodebuild -sdk iphonesimulator | $(XCPRETTY)
	open -a Simulator
	xcrun simctl install booted build/ios/build/Release-iphonesimulator/MyApp.app
	xcrun simctl launch booted Simple2D.MyApp
endif

ifeq ($(PLATFORM),apple)
tvos:
ifeq ($(shell test -d build/tvos/Simple2D.framework; echo $$?),1)
	$(error Simple2D.framework missing, run `release` target first)
endif
	$(call task_msg,Running tvOS test)
	cp -R deps/xcode/tvos/* build/tvos
	cp test/triangle-ios-tvos.c build/tvos/main.c
	cd build/tvos && xcodebuild -sdk appletvsimulator | $(XCPRETTY)
	open -a Simulator
	xcrun simctl install booted build/tvos/build/Release-appletvsimulator/MyApp.app
	xcrun simctl launch booted Simple2D.MyApp
endif

.PHONY: build test
