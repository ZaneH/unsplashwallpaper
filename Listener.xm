#include <objc/runtime.h>
#import <libactivator/libactivator.h>
#import "Reachability.h"
#import <substrate.h>

#define CHANGEWALLPAPER_ID @"com.zanehelton.unsplashwallpaper.changewallpaper"
#define SAVEWALLPAPER_ID @"com.zanehelton.unsplashwallpaper.savewallpaper"

@interface UnsplashWallpaperListener : NSObject <LAListener, UIAlertViewDelegate> {
	BOOL _isVisible;
	NSString *_bundleID;
}

+ (id)sharedInstance;

- (BOOL)present;
- (BOOL)dismiss;
@end

// this is an enum specified by Apple, I'm going to use it to make my life a little easier
// I could just use 0, 1, and 2, but it's not obvious what those mean.
typedef NS_ENUM(NSUInteger, PLWallpaperMode) {
	PLWallpaperModeBoth,
	PLWallpaperModeHomeScreen,
	PLWallpaperModeLockScreen
};

// making sure the tweak knows about these classes
@interface PLStaticWallpaperImageViewController
@property BOOL saveWallpaperData;
- (void)_savePhoto;
- (instancetype)initWithUIImage:(UIImage *)image;
+ (id)alloc;
@end

extern "C" CFArrayRef CPBitmapCreateImagesFromData(CFDataRef cpbitmap, void*, int, void*);

/*
	Heavily documented for education purposes
*/

static LAActivator *sharedActivatorIfExists(void) {
	static LAActivator *_LASharedActivator = nil;
	static dispatch_once_t token = 0;
	dispatch_once(&token, ^{
		void *la = dlopen("/usr/lib/libactivator.dylib", RTLD_LAZY);
		if ((char *)la) {
			_LASharedActivator = (LAActivator *)[objc_getClass("LAActivator") sharedInstance];
		}
	});
	return _LASharedActivator;
}

@implementation UnsplashWallpaperListener

+ (id)sharedInstance {
	static id sharedInstance = nil;
	static dispatch_once_t token = 0;
	dispatch_once(&token, ^{
		sharedInstance = [self new];
	});
	return sharedInstance;
}

+ (void)load {
	[self sharedInstance];
}

- (id)init {
	if ((self = [super init])) {
		// Register our listener
		LAActivator *_LASharedActivator = sharedActivatorIfExists();
		if (_LASharedActivator) {
			if (_LASharedActivator.isRunningInsideSpringBoard) {
				[_LASharedActivator registerListener:self forName:CHANGEWALLPAPER_ID];
				[_LASharedActivator registerListener:self forName:SAVEWALLPAPER_ID];
			}
		}
	}
	return self;
}

- (void)dealloc {
	LAActivator *_LASharedActivator = sharedActivatorIfExists();
	if (_LASharedActivator) {
		if (_LASharedActivator.runningInsideSpringBoard) {
			[_LASharedActivator unregisterListenerWithName:CHANGEWALLPAPER_ID];
			[_LASharedActivator unregisterListenerWithName:SAVEWALLPAPER_ID];
		}
	}
}

#pragma mark - Listener custom methods

- (BOOL)presentOrDismiss {
	if (_isVisible) {
		return [self dismiss];
	} else {
		return [self present];
	}
}

- (BOOL)present {
	// Do UI stuff before this comment
	_isVisible = YES;
	return NO;
}

- (BOOL)dismiss {
	// Do UI stuff before this comment
	_isVisible = NO;
	return NO;
}

#pragma mark - LAListener protocol methods

- (void)activator:(LAActivator *)activator didChangeToEventMode:(NSString *)eventMode {
	[self dismiss];
}

#pragma mark - Incoming events

// Normal assigned events
- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event forListenerName:(NSString *)listenerName {
	if ([listenerName isEqualToString:CHANGEWALLPAPER_ID]) {
		// checks for internet connection with Apple's reachability. Otherwise the tweak will boot into safe mode
		Reachability *networkReachability = [Reachability reachabilityForInternetConnection];
		NetworkStatus networkStatus = [networkReachability currentReachabilityStatus];
		if (networkStatus == NotReachable) {
			// user is not connected to the internet, make them aware of it
			[[[UIAlertView alloc] initWithTitle:@"Whoops!" message:@"Please ensure you're connected to the Internet to use UnsplashWallpaper." delegate:self cancelButtonTitle:@"Dismiss" otherButtonTitles:nil] show];
			[event setHandled:YES];
			return;
		}

		// craft a url build on the unsplash 'api' that requests an image the same size as the users device
		// doing this for 2 reasons. 1: it makes download times faster 2: the image is cropped for us
		NSURL *pageURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://source.unsplash.com/random/%ix%i",
		(int)([[UIScreen mainScreen] bounds].size.width * [[UIScreen mainScreen] scale]),
		(int)([[UIScreen mainScreen] bounds].size.height * [[UIScreen mainScreen] scale])]];
		// sent a request to the url asking for the image data
		[NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:pageURL] queue:[[NSOperationQueue alloc] init] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
			// if there seems to be any kind of hiccup in the request, just alert the user
			if (error) {
				[[[UIAlertView alloc] initWithTitle:@"Whoops!" message:@"Unsplash may be temporarily down. Please try again a few minutes." delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil] show];
				return;
			}

			// create a UIImage based off of the data
			UIImage *image = [UIImage imageWithData:data];
			// create a PLStaticWallpaperImageViewController which will be used to set the wallpaper
			PLStaticWallpaperImageViewController *wallpaperViewController = [[PLStaticWallpaperImageViewController alloc] initWithUIImage:image];
			wallpaperViewController.saveWallpaperData = YES;
			// check if the user wants to set the wallpaper for their home screen, lock screen, or both
			NSDictionary *bundleDefaults = [[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.zanehelton.unsplashwallpaper"];
			NSString *saveMode = [bundleDefaults valueForKey:@"wallmode"];
			if ([saveMode isEqualToString:@"both"]) {
				MSHookIvar<PLWallpaperMode>(wallpaperViewController, "_wallpaperMode") = PLWallpaperModeBoth;
			} else if ([saveMode isEqualToString:@"home"]) {
				MSHookIvar<PLWallpaperMode>(wallpaperViewController, "_wallpaperMode") = PLWallpaperModeHomeScreen;
			} else if ([saveMode isEqualToString:@"lock"]) {
				MSHookIvar<PLWallpaperMode>(wallpaperViewController, "_wallpaperMode") = PLWallpaperModeLockScreen;
			}
			// sets the wallpaper
			[wallpaperViewController _savePhoto];

			// checks if the user wants to save it their photos
			if ([[bundleDefaults valueForKey:@"savetophotos"] boolValue]) {
				// if they do, save it
				UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
			}
		}];
	} else if ([listenerName isEqualToString:SAVEWALLPAPER_ID]) {
		UIAlertView *askWhichWallpaper = [[UIAlertView alloc] initWithTitle:@"Select Wallpaper" message:@"Which wallpaper do you want to save?" delegate:self cancelButtonTitle:@"Nevermind" otherButtonTitles:@"Lockscreen", @"Homescreen", @"Both", nil];
		[askWhichWallpaper show];
	}

	if ([self presentOrDismiss]) {
		[event setHandled:YES];
	}
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex == 1) {
		// save the lockscreen wallpaper
		NSData *homeWallpaperData = [NSData dataWithContentsOfFile:@"/var/mobile/Library/SpringBoard/LockBackground.cpbitmap"];
		// do a bunch of low level stuff that I don't even want to talk about
		CFDataRef homeWallpaperDataRef = (__bridge CFDataRef)homeWallpaperData;
		NSArray *imageArray = (__bridge NSArray *)CPBitmapCreateImagesFromData(homeWallpaperDataRef, NULL, 1, NULL);
		UIImage *homeWallpaper = [UIImage imageWithCGImage:(CGImageRef)imageArray[0]];
		UIImageWriteToSavedPhotosAlbum(homeWallpaper, nil, nil, nil);
		//CFRelease(homeWallpaperDataRef);
	} else if (buttonIndex == 2) {
		// save the homescreen wallpaper
		NSData *homeWallpaperData = [NSData dataWithContentsOfFile:@"/var/mobile/Library/SpringBoard/HomeBackground.cpbitmap"];
		if (!homeWallpaperData) {
			// the homescreen uses the lockscreen wallpaper if they're the same, this essentially checks if they're the same, and then uses the lockscreen
			// wallpaper if they are
			homeWallpaperData = [NSData dataWithContentsOfFile:@"/var/mobile/Library/SpringBoard/LockBackground.cpbitmap"];
		}
		// do a bunch of low level stuff that I don't even want to talk about
		CFDataRef homeWallpaperDataRef = (__bridge CFDataRef)homeWallpaperData;
		NSArray *imageArray = (__bridge NSArray *)CPBitmapCreateImagesFromData(homeWallpaperDataRef, NULL, 1, NULL);
		UIImage *homeWallpaper = [UIImage imageWithCGImage:(CGImageRef)imageArray[0]];
		UIImageWriteToSavedPhotosAlbum(homeWallpaper, nil, nil, nil);
	} else if (buttonIndex == 3) {
		// save the homescreen wallpaper
		BOOL sameWallpaper = NO;
		NSData *homeWallpaperData = [NSData dataWithContentsOfFile:@"/var/mobile/Library/SpringBoard/HomeBackground.cpbitmap"];
		if (!homeWallpaperData) {
			// the homescreen uses the lockscreen wallpaper if they're the same, this essentially checks if they're the same, and then uses the lockscreen
			// wallpaper if they are
			sameWallpaper = YES;
			homeWallpaperData = [NSData dataWithContentsOfFile:@"/var/mobile/Library/SpringBoard/LockBackground.cpbitmap"];
		}
		// do a bunch of low level stuff that I don't even want to talk about
		CFDataRef homeWallpaperDataRef = (__bridge CFDataRef)homeWallpaperData;
		NSArray *imageArray = (__bridge NSArray *)CPBitmapCreateImagesFromData(homeWallpaperDataRef, NULL, 1, NULL);
		UIImage *homeWallpaper = [UIImage imageWithCGImage:(CGImageRef)imageArray[0]];
		UIImageWriteToSavedPhotosAlbum(homeWallpaper, nil, nil, nil);
		if (!sameWallpaper) {
			homeWallpaperData = [NSData dataWithContentsOfFile:@"/var/mobile/Library/SpringBoard/LockBackground.cpbitmap"];
			CFDataRef homeWallpaperDataRef = (__bridge CFDataRef)homeWallpaperData;
			NSArray *imageArray = (__bridge NSArray *)CPBitmapCreateImagesFromData(homeWallpaperDataRef, NULL, 1, NULL);
			UIImage *homeWallpaper = [UIImage imageWithCGImage:(CGImageRef)imageArray[0]];
			UIImageWriteToSavedPhotosAlbum(homeWallpaper, nil, nil, nil);
			return;
		}
	}
}

#pragma mark - Metadata (may be cached)

- (NSString *)activator:(LAActivator *)activator requiresLocalizedTitleForListenerName:(NSString *)listenerName {
	if ([listenerName isEqualToString:CHANGEWALLPAPER_ID])
		return @"Change Wallpaper";
	else
		return @"Save Wallpaper";
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedDescriptionForListenerName:(NSString *)listenerName {
	if ([listenerName isEqualToString:CHANGEWALLPAPER_ID])
		return @"Change wallpaper to image from Unsplash";
	else
		return @"Save current wallpaper to photos";
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedGroupForListenerName:(NSString *)listenerName {
	return @"Unsplash Wallpaper";
}

- (NSArray *)activator:(LAActivator *)activator requiresCompatibleEventModesForListenerWithName:(NSString *)listenerName {
	return [NSArray arrayWithObjects:@"springboard", @"lockscreen", @"application", nil];
}

#pragma mark - Icons

- (NSData *)activator:(LAActivator *)activator requiresSmallIconDataForListenerName:(NSString *)listenerName scale:(CGFloat *)scale {
	if (*scale != 1.0f) {
		return [NSData dataWithContentsOfFile:@"/Library/PreferenceBundles/UnsplashWallpaper.bundle/UnsplashWallpaper@2x.png"];
	} else {
		return [NSData dataWithContentsOfFile:@"/Library/PreferenceBundles/UnsplashWallpaper.bundle/UnsplashWallpaper.png"];
	}
}

@end
