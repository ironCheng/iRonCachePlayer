//
//  iRonPlayerView.h
//  iRonCachePlayer
//
//  Created by iRonCheng on 2020/3/23.
//  Copyright © 2020 iRon. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface iRonPlayerView : UIView

@property (nonatomic, copy) void (^loadFinishBlock)(NSURL *currentUrl);
@property (nonatomic, copy) void (^playFinishBlock)(NSURL *currentUrl);

- (instancetype)initWithFrame:(CGRect)frame videoUrl:(NSURL *)videoUrl;

- (void)resetToPlayNewVideo:(NSURL *)videoUrl;

- (void)play;
- (void)pause;

@end

NS_ASSUME_NONNULL_END
