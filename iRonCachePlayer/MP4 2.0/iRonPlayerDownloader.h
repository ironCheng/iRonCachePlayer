//
//  iRonPlayerDownloader.h
//  iRonCachePlayer
//
//  Created by iRonCheng on 2020/3/24.
//  Copyright © 2020 iRon. All rights reserved.
//

#import <Foundation/Foundation.h>
@class AVAssetResourceLoadingRequest;

NS_ASSUME_NONNULL_BEGIN

@interface iRonPlayerDownloader : NSObject

//下载中需要持有loadingRequest
@property (nonatomic,strong) AVAssetResourceLoadingRequest *loadingRequest;

- (instancetype)initWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest correctUrl:(NSURL *)correctUrl;

- (void)cancel;

@end

NS_ASSUME_NONNULL_END
