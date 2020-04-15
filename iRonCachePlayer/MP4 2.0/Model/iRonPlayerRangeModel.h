//
//  iRonPlayerRangeModel.h
//  iRonCachePlayer
//
//  Created by iRonCheng on 2020/3/24.
//  Copyright © 2020 iRon. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, iRonPlayerDataType) {
    iRonPlayerDataTypeLocal = 0,
    iRonPlayerDataTypeRemote
};


@interface iRonPlayerRangeModel : NSObject

@property (nonatomic, assign, readonly) iRonPlayerDataType dataType;
@property (nonatomic, assign, readonly) NSRange requestRange;

- (instancetype)initWithRequestDataType:(iRonPlayerDataType)dataType requestRange:(NSRange)requestRange;


@end

NS_ASSUME_NONNULL_END
