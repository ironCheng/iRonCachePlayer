//
//  iRonPlayerRangeManager.h
//  iRonCachePlayer
//
//  Created by iRonCheng on 2020/3/24.
//  Copyright © 2020 iRon. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "iRonPlayerRangeModel.h"
#import "iRonPlayerContentInfo.h"
@class AVAssetResourceLoadingRequest;

NS_ASSUME_NONNULL_BEGIN

@interface iRonPlayerRangeManager : NSObject


/**
    视频moov信息，若有保存则返回
 */
+ (iRonPlayerContentInfo *)contentInfoWithUrl:(NSURL *)url;
+ (void)saveContentInfoArchiver:(iRonPlayerContentInfo *)contentInfo withUrl:(NSURL *)url;

+ (instancetype)shared;

/**
 将loadingRequest请求的范围拆分成 '本地已缓存的部分' 和 '远程网络请求' 的部分,封装成rangeModel数组返回
 @param loadingRequest 需要处理的loadingRequest
 @return 处理后的rangeModel数组，包括本地跟远程的，按顺序排好
 */
- (NSMutableArray <iRonPlayerRangeModel *>*)calculateRangeModelArrayForLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest;

/**
记录已缓存的data的range并进行range合并
*/
- (void)addCachedRange:(NSRange)newRange withUrl:(NSURL *)url;
// 持久化
- (void)archiveWithUrl:(NSURL *)url;

@end

NS_ASSUME_NONNULL_END
