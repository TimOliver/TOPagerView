//
//  TOAppDelegate.m
//  TOPagerView
//
//  Created by Timothy OLIVER on 20/11/13.
//  Copyright (c) 2013-2017 Timothy Oliver. All rights reserved.
//

#import "TOAppDelegate.h"
#import "TOViewController.h"

@implementation TOAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:[TOViewController new]];
    [self.window makeKeyAndVisible];
    
    return YES;
}

@end
