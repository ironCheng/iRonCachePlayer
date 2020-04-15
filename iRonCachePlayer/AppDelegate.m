//
//  AppDelegate.m
//  iRonCachePlayer
//
//  Created by iRonCheng on 2020/1/9.
//  Copyright © 2020 iRon. All rights reserved.
//

#import "AppDelegate.h"
#import "iRonTestVideoListViewController.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:[iRonTestVideoListViewController new]];
    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    return YES;
}


@end
