//
//  iRonPlayerContentInfo.h
//  iRonCachePlayer
//
//  Created by iRonCheng on 2020/3/27.
//  Copyright © 2020 iRon. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface iRonPlayerContentInfo : NSObject <NSCoding>

@property (nonatomic, copy) NSString *contentType;
@property (nonatomic, assign) BOOL byteRangeAccessSupported;
@property (nonatomic, assign) unsigned long long contentLength;

@end

NS_ASSUME_NONNULL_END
