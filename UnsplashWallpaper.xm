//
//  UnsplashWallpaper.x
//  UnsplashWallpaper
//
//  Created by Zane Helton on 07.11.2015.
//  Copyright (c) 2015 Zane Helton. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <libactivator/libactivator.h>
#include <substrate.h>
#import "Reachability.h"

#define LISTENER_ID @"com.zanehelton.unsplashwallpaper"

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

// creating our own interface that conforms to the LAListener protocol because Activator requires us to
@interface ZHUWListener : NSObject <LAListener>
@end

@implementation ZHUWListener
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
		NSString *saveMode = [[[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.zanehelton.unsplashwallpaper"] valueForKey:@"wallmode"];
		if ([saveMode isEqualToString:@"both"]) {
			MSHookIvar<PLWallpaperMode>(wallpaperViewController, "_wallpaperMode") = PLWallpaperModeBoth;
		} else if ([saveMode isEqualToString:@"home"]) {
			MSHookIvar<PLWallpaperMode>(wallpaperViewController, "_wallpaperMode") = PLWallpaperModeHomeScreen;
		} else if ([saveMode isEqualToString:@"lock"]) {
			MSHookIvar<PLWallpaperMode>(wallpaperViewController, "_wallpaperMode") = PLWallpaperModeLockScreen;
		}
		// sets the wallpaper
		[wallpaperViewController _savePhoto];
	}];

	// tells activator we've handled the user event, and no further action is required
	[event setHandled:YES];
}

+ (void)load {
	// register our listener for activator
	[[LAActivator sharedInstance] registerListener:[self new] forName:LISTENER_ID];
}
@end
