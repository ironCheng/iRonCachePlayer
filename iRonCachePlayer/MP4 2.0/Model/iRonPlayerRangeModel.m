//
//  iRonPlayerRangeModel.m
//  iRonCachePlayer
//
//  Created by iRonCheng on 2020/3/24.
//  Copyright © 2020 iRon. All rights reserved.
//

#import "iRonPlayerRangeModel.h"

@interface iRonPlayerRangeModel()

@property (nonatomic, assign, readwrite) iRonPlayerDataType dataType;
@property (nonatomic, assign, readwrite) NSRange requestRange;

@end

@implementation iRonPlayerRangeModel

- (instancetype)initWithRequestDataType:(iRonPlayerDataType)dataType requestRange:(NSRange)requestRange {
    self = [super init];
    if (self) {
        _dataType = dataType;
        _requestRange = requestRange;
    }
    return self;
}

//#pragma mark - NSCoding
//
//- (void)encodeWithCoder:(NSCoder *)coder {
//    [coder encodeInteger:self.dataType forKey:@"dataType"];
//    [coder encodeObject:[NSValue valueWithRange:self.requestRange] forKey:@"requestRange"];
//}
//
//- (instancetype)initWithCoder:(NSCoder *)coder {
//    self = [super init];
//    if (self) {
//        _dataType = [coder decodeIntegerForKey:@"dataType"];
//        _requestRange = [[coder decodeObjectForKey:@"requestRange"] rangeValue];
//       
//    }
//    return self;
//}

@end
