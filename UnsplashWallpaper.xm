//
//  UnsplashWallpaper.x
//  UnsplashWallpaper
//
//  Created by Zane Helton on 07.11.2015.
//  Copyright (c) 2015 Zane Helton. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <libactivator/libactivator.h>
#import "Reachability.h"
#include <substrate.h>

#define CHANGEWALLPAPER_ID @"com.zanehelton.changewallpaper"
#define SAVEWALLPAPER_ID @"com.zanehelton.changewallpaper"

// this is an enum specified by Apple, I'm going to use it to make my life a little easier
// I could just use 0, 1, and 2, but it's not obvious what those mean.
typedef NS_ENUM(NSUInteger, PLWallpaperMode) {
	PLWallpaperModeBoth,
	PLWallpaperModeHomeScreen,
	PLWallpaperModeLockScreen
};

// making sure the tweak knows about these classes
@interface PLStaticWallpaperImageViewController
- (void)_savePhoto;
- (instancetype)initWithUIImage:(UIImage *)image;
+ (id)alloc;

@property BOOL saveWallpaperData;
@end

extern "C" CFArrayRef CPBitmapCreateImagesFromData(CFDataRef cpbitmap, void*, int, void*);

/*
	Heavily documented for education purposes
*/

// creating our own interface that conforms to the LAListener protocol because Activator requires us to
// all activator information came from: http://iphonedevwiki.net/index.php/Libactivator
// highly suggested read if you're interested in activator
@interface ChangeWallpaperListener : NSObject <LAListener>
@end

@implementation ChangeWallpaperListener
// one of the methods defined in the protocol
- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event {
	// checks for internet connection with Apple's reachability. Otherwise the tweak will boot into safe mode
	Reachability *networkReachability = [Reachability reachabilityForInternetConnection];
	NetworkStatus networkStatus = [networkReachability currentReachabilityStatus];
	if (networkStatus == NotReachable) {
		// user is not connected to the internet, make them aware of it
		[[[UIAlertView alloc] initWithTitle:@"Whoops!" message:@"Please ensure you're connected to the Internet to use UnsplashWallpaper." delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil] show];
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

	// tells activator we've handled the user event, and no further action is required
	[event setHandled:YES];
}

// some data source methods to give our action a name and description in the activator application
- (NSString *)activator:(LAActivator *)activator requiresLocalizedGroupForListenerName:(NSString *)listenerName {
	return @"Unsplash Wallpaper";
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedTitleForListenerName:(NSString *)listenerName {
	return @"Change Wallpaper";
}
- (NSString *)activator:(LAActivator *)activator requiresLocalizedDescriptionForListenerName:(NSString *)listenerName {
	return @"Change wallpaper to image from Unsplash";
}

- (NSData *)activator:(LAActivator *)activator requiresIconDataForListenerName:(NSString *)listenerName scale:(CGFloat *)scale {
	// hard coding the file is never a good idea, but I couldn't find a way to load it dynamically
	NSString *iconPath = @"/Library/PreferenceBundles/UnsplashWallpaper.bundle/UnsplashWallpaper.png";
	return [NSData dataWithContentsOfFile:iconPath];
}

- (NSData *)activator:(LAActivator *)activator requiresSmallIconDataForListenerName:(NSString *)listenerName scale:(CGFloat *)scale {
	NSData *iconData;
	CGFloat imageScale = *scale;
	if (imageScale != 1.0f) {
		// same as above, don't hard code files
		NSString *iconPath = @"/Library/PreferenceBundles/UnsplashWallpaper.bundle/UnsplashWallpaper@2x.png";
		iconData = [NSData dataWithContentsOfFile:iconPath];
		if (iconData) {
			return iconData;
		}
	}
	iconData = [self activator:activator requiresIconDataForListenerName:listenerName];
	if (iconData) {
		*scale = 1.0f;
	}

	return iconData;
}

+ (void)load {
	// register our listener for activator if activator is running
	if ([LASharedActivator isRunningInsideSpringBoard]) {
		[[LAActivator sharedInstance] registerListener:[self new] forName:CHANGEWALLPAPER_ID];
	}
}
@end

@interface SaveWallpaperListener : NSObject <LAListener, UIAlertViewDelegate>
@end

@implementation SaveWallpaperListener
// one of the methods defined in the protocol
- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event {
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Select Wallpaper" message:@"Which wallpaper do you want to save?" delegate:self cancelButtonTitle:@"Dismiss" otherButtonTitles:@"Lockscreen", @"Homescreen", @"Both", nil];
	[alert setCancelButtonIndex:3];
	[alert show];
	// tells activator we've handled the user event, and no further action is required
	[event setHandled:YES];
}


- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex == 0) {
		NSLog(@"Lockscreen");
	} else if (buttonIndex == 1) {
		NSData *homeWallpaperData = [NSData dataWithContentsOfFile:@"/var/mobile/Library/SpringBoard/HomeBackground.cpbitmap"];
		CFDataRef homeWallpaperDataRef = (__bridge CFDataRef)homeWallpaperData;
		NSArray *imageArray = (__bridge NSArray *)CPBitmapCreateImagesFromData(homeWallpaperDataRef, nil, 1, nil);
		UIImage *homeWallpaper = [UIImage imageWithCGImage:(CGImageRef)imageArray[0]];
		UIImageWriteToSavedPhotosAlbum(homeWallpaper, nil, nil, nil);
	} else if (buttonIndex == 2) {
		NSLog(@"Both");
	}
}

// some data source methods to give our action a name and description in the activator application
- (NSString *)activator:(LAActivator *)activator requiresLocalizedGroupForListenerName:(NSString *)listenerName {
	return @"Unsplash Wallpaper";
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedTitleForListenerName:(NSString *)listenerName {
	return @"Save Wallpaper";
}
- (NSString *)activator:(LAActivator *)activator requiresLocalizedDescriptionForListenerName:(NSString *)listenerName {
	return @"Save the current wallpaper";
}

- (NSData *)activator:(LAActivator *)activator requiresIconDataForListenerName:(NSString *)listenerName scale:(CGFloat *)scale {
	// hard coding the file is never a good idea, but I couldn't find a way to load it dynamically
	NSString *iconPath = @"/Library/PreferenceBundles/UnsplashWallpaper.bundle/UnsplashWallpaper.png";
	return [NSData dataWithContentsOfFile:iconPath];
}

- (NSData *)activator:(LAActivator *)activator requiresSmallIconDataForListenerName:(NSString *)listenerName scale:(CGFloat *)scale {
	NSData *iconData;
	CGFloat imageScale = *scale;
	if (imageScale != 1.0f) {
		// same as above, don't hard code files
		NSString *iconPath = @"/Library/PreferenceBundles/UnsplashWallpaper.bundle/UnsplashWallpaper@2x.png";
		iconData = [NSData dataWithContentsOfFile:iconPath];
		if (iconData) {
			return iconData;
		}
	}
	iconData = [self activator:activator requiresIconDataForListenerName:listenerName];
	if (iconData) {
		*scale = 1.0f;
	}

	return iconData;
}

+ (void)load {
	// register our listener for activator if activator is running
	if ([LASharedActivator isRunningInsideSpringBoard]) {
		[[LAActivator sharedInstance] registerListener:[self new] forName:SAVEWALLPAPER_ID];
	}
}
@end