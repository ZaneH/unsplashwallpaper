ARCHS = armv7 armv7s arm64

TARGET = iphone:clang:latest:8.0

THEOS_BUILD_DIR = Packages

include theos/makefiles/common.mk

TWEAK_NAME = UnsplashWallpaper
UnsplashWallpaper_CFLAGS = -fobjc-arc
UnsplashWallpaper_LDFLAGS = -lactivator
UnsplashWallpaper_FILES = UnsplashWallpaper.xm Reachability.m
UnsplashWallpaper_FRAMEWORKS = Foundation UIKit SystemConfiguration
UnsplashWallpaper_PRIVATE_FRAMEWORKS = PhotoLibrary AppSupport
UnsplashWallpaper_LIBRARIES = activator

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 backboardd"

SUBPROJECTS += unsplashwallpaper
include $(THEOS_MAKE_PATH)/aggregate.mk
