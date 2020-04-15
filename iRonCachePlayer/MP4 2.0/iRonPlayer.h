//
//  iRonPlayer.h
//  iRonCachePlayer
//
//  Created by iRonCheng on 2020/3/23.
//  Copyright © 2020 iRon. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface iRonPlayer : NSObject

+ (instancetype _Nonnull )shared;

/**
 使用此方法生成的playerItem，会从其代理<AVAssetResourceLoaderDelegate>中询问播放资源
 */
- (AVPlayerItem *)playerItemWithURL:(NSURL *)url;

- (void)cancelAllDownloaders;

@end

NS_ASSUME_NONNULL_END
