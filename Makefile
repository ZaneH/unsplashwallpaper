include $(THEOS)/makefiles/common.mk

TWEAK_NAME = UnsplashWallpaper
UnsplashWallpaper_CFLAGS = -fobjc-arc
UnsplashWallpaper_FILES = Listener.xm Reachability.m
UnsplashWallpaper_FRAMEWORKS = Foundation UIKit SystemConfiguration
UnsplashWallpaper_PRIVATE_FRAMEWORKS = PhotoLibrary AppSupport
UnsplashWallpaper_LIBRARIES = activator

include $(THEOS_MAKE_PATH)/tweak.mk

internal-stage::
	#Filter plist
	$(ECHO_NOTHING)if [ -f Filter.plist ]; then mkdir -p $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/; cp Filter.plist $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/UnsplashWallpaper.plist; fi$(ECHO_END)
	#PreferenceLoader plist
	$(ECHO_NOTHING)if [ -f Preferences.plist ]; then mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/UnsplashWallpaper; cp Preferences.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/UnsplashWallpaper/; fi$(ECHO_END)

after-install::
	install.exec "killall -9 SpringBoard"

SUBPROJECTS += unsplashwallpaper
include $(THEOS_MAKE_PATH)/aggregate.mk