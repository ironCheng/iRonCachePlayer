//
//  iRonPlayerRangeManager.m
//  iRonCachePlayer
//
//  Created by iRonCheng on 2020/3/24.
//  Copyright © 2020 iRon. All rights reserved.
//

#import "iRonPlayerRangeManager.h"
#import <AVFoundation/AVFoundation.h>
#import "iRonPlayerCacheManager.h"

@interface iRonPlayerRangeManager()

/**
已缓存的data的range的数组
*/
@property (nonatomic, strong) NSMutableArray <NSValue *>*cachedRangeArray;
@property (nonatomic, strong) NSURL *videoUrl;

@end

@implementation iRonPlayerRangeManager

+ (instancetype)shared {
    static iRonPlayerRangeManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [iRonPlayerRangeManager new];
    });
    
    return instance;
}

+ (iRonPlayerContentInfo *)contentInfoWithUrl:(NSURL *)url {
    
    iRonPlayerContentInfo *contentInfo = [NSKeyedUnarchiver unarchiveObjectWithFile:[self p_contenInfoPathWithUrl:url]];
                                           
    return contentInfo;
}

+ (void)saveContentInfoArchiver:(iRonPlayerContentInfo *)contentInfo withUrl:(NSURL *)url {
        
    [NSKeyedArchiver archiveRootObject:contentInfo toFile:[self p_contenInfoPathWithUrl:url]];
}

/**
 将loadingRequest请求的范围拆分成 '本地已缓存的部分' 和 '远程网络请求' 的部分,封装成rangeModel数组返回
 @param loadingRequest 需要处理的loadingRequest
 @return 处理后的rangeModel数组，包括本地跟远程的，按顺序排好
 */
- (NSMutableArray <iRonPlayerRangeModel *>*)calculateRangeModelArrayForLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    
    if (![self.videoUrl.absoluteString isEqualToString:loadingRequest.request.URL.absoluteString]) {
        
        if (_cachedRangeArray.count > 0 && self.videoUrl.absoluteString.length > 0) {
            // 先保存一波
            [self p_saveArrayArchiveWithArray:self.cachedRangeArray url:self.videoUrl];
        }
        
        //重置
        _videoUrl = loadingRequest.request.URL;
        _cachedRangeArray = [[NSKeyedUnarchiver unarchiveObjectWithFile:[self p_rangeModelPathWithUrl:self.videoUrl]] mutableCopy];
        if (!_cachedRangeArray) {
            _cachedRangeArray = [NSMutableArray array];
        }
    }
    
    NSUInteger requestOffset = (NSUInteger)loadingRequest.dataRequest.requestedOffset;
    NSUInteger requestLength = (NSUInteger)loadingRequest.dataRequest.requestedLength;
    NSRange requestRange = NSMakeRange(requestOffset, requestLength);
    NSMutableArray <iRonPlayerRangeModel *>*returnRangModelArray = [NSMutableArray array];
    
    
    if (self.cachedRangeArray.count == 0) {
        // 一个都没缓存过
        
        iRonPlayerRangeModel *model = [[iRonPlayerRangeModel alloc] initWithRequestDataType:iRonPlayerDataTypeRemote requestRange:requestRange];
        
        [returnRangModelArray addObject:model];
        
    } else {
        // 有一些缓存
        
        //先处理 loadingRequest 和 本地缓存 所有有交集的部分
        NSMutableArray *intersectionModelArray = [NSMutableArray array];
        
        [self.cachedRangeArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSRange cacheRange = [obj rangeValue];
            
            NSRange intersectionRange = NSIntersectionRange(cacheRange, requestRange);
            if (intersectionRange.length > 0) {
                iRonPlayerRangeModel *model = [[iRonPlayerRangeModel alloc] initWithRequestDataType:iRonPlayerDataTypeLocal requestRange:intersectionRange];
                [intersectionModelArray addObject:model];
            }
        }];
        
        ///围绕交集，进行需要网络请求的range的拆解
        if (intersectionModelArray.count == 0) {
            //无交集
            
            iRonPlayerRangeModel *model = [[iRonPlayerRangeModel alloc] initWithRequestDataType:iRonPlayerDataTypeRemote requestRange:requestRange];

            [returnRangModelArray addObject:model];
            
        } else {
            //有一些交集
            
            [intersectionModelArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                
                iRonPlayerRangeModel *currenModel = obj;
                
                if (idx == 0) {
                    //第一个的前面还有一些要请求的
                    if (currenModel.requestRange.location > requestRange.location) {
                        iRonPlayerRangeModel *model = [[iRonPlayerRangeModel alloc] initWithRequestDataType:iRonPlayerDataTypeRemote requestRange:NSMakeRange(requestRange.location, currenModel.requestRange.location - requestRange.location)];
                        
                        [returnRangModelArray addObject:model];
                    }
                    
                    //加上本地的这块
                    [returnRangModelArray addObject:currenModel];
                    
                } else {
                    
                    iRonPlayerRangeModel *previousModel = intersectionModelArray[idx - 1];
                    NSUInteger previousEndOffst = previousModel.requestRange.location + previousModel.requestRange.length;
                    
                    if (currenModel.requestRange.location - previousEndOffst > 0) {
                        iRonPlayerRangeModel *model = [[iRonPlayerRangeModel alloc] initWithRequestDataType:iRonPlayerDataTypeRemote requestRange:NSMakeRange(previousEndOffst, currenModel.requestRange.location - previousEndOffst)];
                        [returnRangModelArray addObject:model];
                    }
                    
                    //加上本地的这块
                    [returnRangModelArray addObject:currenModel];
                }
                
                //最后一个交集Range后面可能还有一段需要网络请求
                if (idx == intersectionModelArray.count - 1) {
                    
                    iRonPlayerRangeModel *lastModel = intersectionModelArray.lastObject;
                    if (requestRange.location + requestRange.length > lastModel.requestRange.location + lastModel.requestRange.length) {
                        
                        iRonPlayerRangeModel *model = [[iRonPlayerRangeModel alloc] initWithRequestDataType:iRonPlayerDataTypeRemote requestRange:NSMakeRange(lastModel.requestRange.location + lastModel.requestRange.length, requestRange.location + requestRange.length - lastModel.requestRange.location - lastModel.requestRange.length)];
                        
                        [returnRangModelArray addObject:model];
                    }
                    
                }
            }];
            
        }
    }
    
    return returnRangModelArray;
}

/**
记录已缓存的data的range并进行range合并
*/
- (void)addCachedRange:(NSRange)newRange withUrl:(NSURL *)url {
    if (newRange.location == NSNotFound || newRange.length == 0) {
        NSLog(@"~~~合并缓存错误");
        return;
    }

    if (![url.absoluteString isEqualToString:self.videoUrl.absoluteString]) {
        
        if (_cachedRangeArray.count > 0 && self.videoUrl.absoluteString.length > 0) {
            // 先保存一波
            [self p_saveArrayArchiveWithArray:self.cachedRangeArray url:self.videoUrl];
        }
        
        //重置
        _videoUrl = url;
        _cachedRangeArray = [[NSKeyedUnarchiver unarchiveObjectWithFile:[self p_rangeModelPathWithUrl:url]] mutableCopy];
        if (!_cachedRangeArray) {
            _cachedRangeArray = [NSMutableArray array];
        }
    }
    
    ///
    @synchronized (self.cachedRangeArray) {
        
        if (self.cachedRangeArray.count == 0) {
            // 本身没缓存过
            
            [self.cachedRangeArray addObject:[NSValue valueWithRange:newRange]];
            
        } else {
            // 本身有一些缓存
                        
            // 有关联的index的集合（这些index都是有交集的range）
            NSMutableIndexSet *relativeIndexSet = [NSMutableIndexSet indexSet];
            
            [self.cachedRangeArray enumerateObjectsUsingBlock:^(NSValue * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                
                NSRange currentRange = [obj rangeValue];
                
                if ((newRange.location + newRange.length) <= currentRange.location) {
                    ///在当前range前面，满足无相交的条件，退出。 如果relativeIndexSet为空，则加这个index
                    
                    if (relativeIndexSet.count == 0) {
                        [relativeIndexSet addIndex:idx];
                    }
                    
                    *stop = YES;
                
                } else if (newRange.location <= (currentRange.location + currentRange.length) && (newRange.location + newRange.length) > currentRange.location) {
                    ///当前range有交集，满足相交条件。
                    
                    [relativeIndexSet addIndex:idx];
                
                } else if (newRange.location >= (currentRange.length + currentRange.location)) {
                    ///在当前range后面，满足无相交的条件
                    
                    // 如果是最后一个
                    if (idx == self.cachedRangeArray.count - 1) {
                        [relativeIndexSet addIndex:idx];
                        
                        *stop = YES;
                    }
                }
                
            }];
            
            if (relativeIndexSet.count == 1) {
                
                NSRange firstRange = self.cachedRangeArray[relativeIndexSet.firstIndex].rangeValue;
                NSRange expandFirstRange = NSMakeRange(firstRange.location, firstRange.length + 1);
                NSRange expandFragmentRange = NSMakeRange(newRange.location, newRange.length + 1);
                NSRange intersectionRange = NSIntersectionRange(expandFirstRange, expandFragmentRange); // 交叉范围
                
                
                if (intersectionRange.length > 0) { // Should combine
                    // 有交集
                    
                    NSInteger location = MIN(firstRange.location, newRange.location);
                    NSInteger endOffset = MAX(firstRange.location + firstRange.length, newRange.location + newRange.length);
                    
                    NSRange combineRange = NSMakeRange(location, endOffset - location);
                    [self.cachedRangeArray removeObjectAtIndex:relativeIndexSet.firstIndex];
                    [self.cachedRangeArray insertObject:[NSValue valueWithRange:combineRange] atIndex:relativeIndexSet.firstIndex];
                
                } else {
                    // 无交集
                    
                    if (firstRange.location > newRange.location) {
                        [self.cachedRangeArray insertObject:[NSValue valueWithRange:newRange] atIndex:[relativeIndexSet firstIndex]];
                    } else {
                        [self.cachedRangeArray insertObject:[NSValue valueWithRange:newRange] atIndex:[relativeIndexSet firstIndex] + 1];
                    }
                    
                }
                
                
            } else if (relativeIndexSet.count > 1) {
                
                NSRange firstRange = self.cachedRangeArray[relativeIndexSet.firstIndex].rangeValue;
                NSRange lastRange = self.cachedRangeArray[relativeIndexSet.lastIndex].rangeValue;
                
                NSInteger location = MIN(firstRange.location, newRange.location);
                NSInteger endOffset = MAX(lastRange.location + lastRange.length, newRange.location + newRange.length);
                
                NSRange combinRange = NSMakeRange(location, endOffset - location);
                [self.cachedRangeArray removeObjectsAtIndexes:relativeIndexSet];
                [self.cachedRangeArray insertObject:[NSValue valueWithRange:combinRange] atIndex:relativeIndexSet.firstIndex];
                
            }
            
        }
    }
    
}

// 持久化
- (void)archiveWithUrl:(NSURL *)url {
    
    if (![url.absoluteString isEqualToString:self.videoUrl.absoluteString]) {
        
        //重置
        _videoUrl = url;
        _cachedRangeArray = [[NSKeyedUnarchiver unarchiveObjectWithFile:[self p_rangeModelPathWithUrl:url]] mutableCopy];
        if (!_cachedRangeArray) {
            _cachedRangeArray = [NSMutableArray array];
        }
        
        return;
    }
    
    [self p_saveArrayArchiveWithArray:self.cachedRangeArray url:url];
}

#pragma mark - Private

- (void)p_saveArrayArchiveWithArray:(NSArray *)array url:(NSURL *)url {
    
    if (!array || array.count < 1) {
        return;
    }
    
    @synchronized (array) {
        [NSKeyedArchiver archiveRootObject:array toFile:[self p_rangeModelPathWithUrl:url]];
    }
}

- (NSString *)p_rangeModelPathWithUrl:(NSURL *)url {
    NSString *cacheDirectory = [iRonPlayerCacheManager rangeModelCacheDirectory];
    NSString *urlHash = [NSString stringWithFormat:@"%lu",(unsigned long)url.absoluteString.hash];
    NSString *filePath = [cacheDirectory stringByAppendingPathComponent:urlHash];
    
    return filePath;
}

      
+ (NSString *)p_contenInfoPathWithUrl:(NSURL *)url {
    NSString *cacheDirectory = [iRonPlayerCacheManager contentInfoCacheDirectory];
    NSString *urlHash = [NSString stringWithFormat:@"%lu",(unsigned long)url.absoluteString.hash];
    NSString *filePath = [cacheDirectory stringByAppendingPathComponent:urlHash];

    return filePath;
}

@end
