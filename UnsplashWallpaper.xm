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

typedef NS_ENUM(NSUInteger, PLWallpaperMode) {
	PLWallpaperModeBoth,
	PLWallpaperModeHomeScreen,
	PLWallpaperModeLockScreen
};

@interface PLStaticWallpaperImageViewController
- (void)_savePhoto;
- (instancetype)initWithUIImage:(UIImage *)image;
+ (id)alloc;

@property BOOL saveWallpaperData;
@end

@interface ZHUWListener : NSObject <LAListener>
@end

@implementation ZHUWListener
- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event {
	Reachability *networkReachability = [Reachability reachabilityForInternetConnection];
	NetworkStatus networkStatus = [networkReachability currentReachabilityStatus];
	if (networkStatus == NotReachable) {
		// user is not connected to the internet.
		[[[UIAlertView alloc] initWithTitle:@"Error!" message:@"Please ensure you're connected to the Internet to use UnsplashWallpaper." delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil] show];
		[event setHandled:YES];
		return;
	}

	NSURL *pageURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://source.unsplash.com/random/%ix%i",
	(int)([[UIScreen mainScreen] bounds].size.width * [[UIScreen mainScreen] scale]),
	(int)([[UIScreen mainScreen] bounds].size.height * [[UIScreen mainScreen] scale])]];
	[NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:pageURL] queue:[[NSOperationQueue alloc] init] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
		if (error) {
			[[[UIAlertView alloc] initWithTitle:@"Error!" message:@"Unsplash may be temporarily down. Please try again a few minutes." delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil] show];
			return;
		}

		UIImage *image = [UIImage imageWithData:data];
		PLStaticWallpaperImageViewController *wallpaperViewController = [[PLStaticWallpaperImageViewController alloc] initWithUIImage:image];
		wallpaperViewController.saveWallpaperData = YES;
		NSString *saveMode = [[[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.zanehelton.unsplashwallpaper"] valueForKey:@"wallmode"];
		if ([saveMode isEqualToString:@"both"]) {
			MSHookIvar<PLWallpaperMode>(wallpaperViewController, "_wallpaperMode") = 0;
		} else if ([saveMode isEqualToString:@"home"]) {
			MSHookIvar<PLWallpaperMode>(wallpaperViewController, "_wallpaperMode") = 1;
		} else if ([saveMode isEqualToString:@"lock"]) {
			MSHookIvar<PLWallpaperMode>(wallpaperViewController, "_wallpaperMode") = 2;
		}
		[wallpaperViewController _savePhoto];
	}];

	[event setHandled:YES];
}

+ (void)load {
	[[LAActivator sharedInstance] registerListener:[self new] forName:LISTENER_ID];
}
@end