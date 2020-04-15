//
//  iRonPlayerCacheManager.h
//  iRonCachePlayer
//
//  Created by iRonCheng on 2020/3/24.
//  Copyright © 2020 iRon. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface iRonPlayerCacheManager : NSObject

+ (NSString *)checkFilePathExistsWithUrl:(NSURL *)videoUrl;
+ (BOOL)isFilePathExists:(NSString *)filePath;
+ (NSString *)contentInfoCacheDirectory;
+ (NSString *)rangeModelCacheDirectory;

//+ (instancetype)shared;//不用shared 因为每次要改好几个初始化数据

- (instancetype)initWithUrl:(NSURL *)url;
- (void)addCacheData:(NSData *)data withRange:(NSRange)range error:(NSError **)error;
- (NSData *)readCacheDataWithRange:(NSRange)range;


@end

NS_ASSUME_NONNULL_END
