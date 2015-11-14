ARCHS = armv7 armv7s arm64

TARGET = iphone:clang:latest:9.0.2

THEOS_BUILD_DIR = Packages

include theos/makefiles/common.mk

BUNDLE_NAME = UnsplashWallpaper
UnsplashWallpaper_CFLAGS = -fobjc-arc
UnsplashWallpaper_FILES = UnsplashWallpaperListController.m
UnsplashWallpaper_INSTALL_PATH = /Library/PreferenceBundles
UnsplashWallpaper_FRAMEWORKS = Foundation UIKit
UnsplashWallpaper_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/UnsplashWallpaper.plist$(ECHO_END)
