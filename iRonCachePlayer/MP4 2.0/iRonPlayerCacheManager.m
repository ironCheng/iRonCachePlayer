//
//  iRonPlayerCacheManager.m
//  iRonCachePlayer
//
//  Created by iRonCheng on 2020/3/24.
//  Copyright © 2020 iRon. All rights reserved.
//

#import "iRonPlayerCacheManager.h"

static NSString *iRonPlayerDirectory = @"iRonPlayer";

@interface iRonPlayerCacheManager ()

@property (nonatomic, strong) NSFileHandle *writeFileHandle;
@property (nonatomic, strong) NSFileHandle *readFileHandle;

@end

@implementation iRonPlayerCacheManager

#pragma mark - Public 

+ (NSString *)checkFilePathExistsWithUrl:(NSURL *)videoUrl {
    
    if ([videoUrl.absoluteString hasPrefix:@"/var"] || [videoUrl.absoluteString hasPrefix:@"/Users"]) {
        return videoUrl.absoluteString;
    }
    
    NSString *cachePath = [self p_cachePathWithUrl:videoUrl];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:cachePath]) {
        return cachePath;
    } else{
        return nil;
    }
    
}

+ (BOOL)isFilePathExists:(NSString *)filePath {
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        return filePath;
    } else{
        return nil;
    }
}


+ (NSString *)contentInfoCacheDirectory {
    NSString *cacheDirectory = [self p_cacheDirectory];
    cacheDirectory = [cacheDirectory stringByAppendingPathComponent:@"contentInfos"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    if (![fileManager fileExistsAtPath:cacheDirectory]) {
        [fileManager createDirectoryAtPath:cacheDirectory withIntermediateDirectories:YES attributes:nil error:&error];
    }
    if (!error) {
        return cacheDirectory;
    }
    
    return nil;
}

+ (NSString *)rangeModelCacheDirectory {
    NSString *cacheDirectory = [self p_cacheDirectory];
    cacheDirectory = [cacheDirectory stringByAppendingPathComponent:@"rangeModels"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    if (![fileManager fileExistsAtPath:cacheDirectory]) {
        [fileManager createDirectoryAtPath:cacheDirectory withIntermediateDirectories:YES attributes:nil error:&error];
    }
    if (!error) {
        return cacheDirectory;
    }
    
    return nil;
}

+ (instancetype)shared {
    static iRonPlayerCacheManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [iRonPlayerCacheManager new];
    });
    
    return instance;
}

- (instancetype)initWithUrl:(NSURL *)url {
    self = [super init];
    if (self) {
        NSString *cachePath = [iRonPlayerCacheManager p_cachePathWithUrl:url];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        NSError *error;
        if (![fileManager fileExistsAtPath:cachePath]) {
            [fileManager createFileAtPath:cachePath contents:nil attributes:nil];
        }

        NSURL *fileURL = [NSURL fileURLWithPath:cachePath];
        _readFileHandle = [NSFileHandle fileHandleForReadingFromURL:fileURL error:&error];
        if (!error) {
            _writeFileHandle = [NSFileHandle fileHandleForWritingToURL:fileURL error:&error];
        } else {
            NSLog(@"[iRonPlayer] %s: create Directory Fail", __func__);
        }
    }
    return self;
}

- (void)addCacheData:(NSData *)data withRange:(NSRange)range error:(NSError **)error {
    @synchronized (self.writeFileHandle) {
        @try {
            [self.writeFileHandle seekToFileOffset:range.location];
            [self.writeFileHandle writeData:data];
            [self.writeFileHandle synchronizeFile];
            
        } @catch (NSException *exception) {
            NSLog(@"[iRonPlayer] %s: write Data Fail", __func__);
            *error =  [NSError errorWithDomain:exception.name code:123 userInfo:@{NSLocalizedDescriptionKey: exception.reason, @"exception": exception}];
        }
        
    }
}

- (NSData *)readCacheDataWithRange:(NSRange)range {
    @synchronized (self.readFileHandle) {
        ///先seek 再read
        [self.readFileHandle seekToFileOffset:range.location];
        return [self.readFileHandle readDataOfLength:range.length];
    }
}

#pragma mark - Private

+ (NSString *)p_cacheDirectory {
    NSString *cacheDirectory = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) objectAtIndex:0] stringByAppendingPathComponent:iRonPlayerDirectory];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    if (![fileManager fileExistsAtPath:cacheDirectory]) {
        [fileManager createDirectoryAtPath:cacheDirectory withIntermediateDirectories:YES attributes:nil error:&error];
    }
    if (!error) {
        return cacheDirectory;
    }
    
    return nil;
}

+ (NSString *)p_cachePathWithUrl:(NSURL *)url {
    
    NSString *fileType = url.pathExtension;
    NSString *urlHash = [NSString stringWithFormat:@"%lu",(unsigned long)url.absoluteString.hash];
    
    NSString *cachePath = [[self p_cacheDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", urlHash, fileType]];
    return cachePath;
}

#pragma mark - Other

- (void)dealloc{
    [self.writeFileHandle closeFile];
    [self.readFileHandle closeFile];
}

@end
