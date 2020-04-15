//
//  iRonPlayerDownloader.m
//  iRonCachePlayer
//
//  Created by iRonCheng on 2020/3/24.
//  Copyright © 2020 iRon. All rights reserved.
//

#import "iRonPlayerDownloader.h"
#import "iRonPlayerRangeManager.h"
#import "iRonPlayerCacheManager.h"

#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>

/**
    下载队列单例
    所有请求都固定在同一个队列下载
 */

@interface iRonDownloadQueue : NSObject
@property (nonatomic, strong, readonly) NSOperationQueue *downloadQueue;
+ (instancetype)shared;
@end
@implementation iRonDownloadQueue
+ (instancetype)shared {
    static iRonDownloadQueue *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [iRonDownloadQueue new];
    });
    return instance;
}
- (instancetype)init {
    self = [super init];
    if (self) {
        //queue.maxConcurrentOperationCount 为 -1, 默认并发队列
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        queue.name = @"com.iRonPlayer.download";
        _downloadQueue = queue;
    }
    return self;
}
@end



@interface iRonPlayerDownloader () <NSURLSessionDelegate>

@property (nonatomic, strong) NSURL *correctVideoUrl;
@property (nonatomic, strong) NSMutableArray <iRonPlayerRangeModel *> *rangeModelArray;
@property (nonatomic, strong) iRonPlayerCacheManager *cacheManager;

@property (nonatomic, strong) iRonPlayerRangeModel *currentModel;
@property (nonatomic, assign) NSUInteger currentModelReceivedDataLength;

@property (nonatomic, strong) NSURLSession *urlSession;
@property (nonatomic, strong) NSURLSessionDataTask *sessionDataTask;

@end

@implementation iRonPlayerDownloader

#pragma mark - Getter

- (NSURLSession *)urlSession {
    if (!_urlSession) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        // 所有请求都固定在同一个队列下载
        NSURLSession *session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[iRonDownloadQueue shared].downloadQueue];
        _urlSession = session;
    }
    
    return _urlSession;
}

#pragma mark - Public

 - (instancetype)initWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest correctUrl:(NSURL *)correctUrl {
    self = [super init];
    if (self) {
        self.loadingRequest = loadingRequest;
        
        self.correctVideoUrl = correctUrl;
        
        self.cacheManager = [[iRonPlayerCacheManager alloc] initWithUrl:loadingRequest.request.URL];
        
        //当前url、当前请求range下的所有rangeModel数组
        self.rangeModelArray = [[iRonPlayerRangeManager shared] calculateRangeModelArrayForLoadingRequest:loadingRequest];
        
        iRonPlayerContentInfo *contentInfo = [iRonPlayerRangeManager contentInfoWithUrl:loadingRequest.request.URL];
        [self p_fillContentInfo:contentInfo];
        
        
        [self p_handleLoadingRequest];
    }
    return self;
}

- (void)cancel {
    
    if (!self.loadingRequest.isFinished) {
        [self.loadingRequest finishLoadingWithError:[[NSError alloc] initWithDomain:@"com.iron" code:-3 userInfo:@{NSLocalizedDescriptionKey: @"Resource loader cancelled"}]];
    }
    
    [self.sessionDataTask cancel];//保证请求被立即取消，不然服务器还会继续返回一段数据，这段数据不会被利用到，浪费流量
    [self.urlSession invalidateAndCancel];
    self.urlSession = nil;
}

- (void)p_finishAllRequest:(NSError *)error {
    
    if (!self.loadingRequest.isFinished) {
        if (error) {
            [self.loadingRequest finishLoadingWithError:error];
        } else {
            [self.loadingRequest finishLoading];
        }
    }
    
    [self.sessionDataTask cancel];//保证请求被立即取消，不然服务器还会继续返回一段数据，这段数据不会被利用到，浪费流量
    [self.urlSession invalidateAndCancel];
    self.urlSession = nil;
}

#pragma mark - 处理下载请求

- (void)p_handleLoadingRequest {

    if (self.rangeModelArray.count > 0) {
        
        self.currentModel = self.rangeModelArray.firstObject;
        self.currentModelReceivedDataLength = 0;
        
        [self.rangeModelArray removeObjectAtIndex:0];
        
        if (self.currentModel.dataType == iRonPlayerDataTypeLocal) {
            /// 本地已缓存，直接从沙盒中读取
            
            NSRange cacheRange = self.currentModel.requestRange;
            NSData *cacheData = [self.cacheManager readCacheDataWithRange:cacheRange];
            // respondWithData 回填数据
            [self.loadingRequest.dataRequest respondWithData:cacheData];
            
            /// 继续处理请求
            [self p_handleLoadingRequest];
            
        } else {
            /// 远程下载
            
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.correctVideoUrl];
            request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
            
            // 这里指明下载范围
            long long fromOffset = self.currentModel.requestRange.location;
            long long endOffset = self.currentModel.requestRange.location + self.currentModel.requestRange.length - 1;
            NSString *downloadRangeString = [NSString stringWithFormat:@"bytes=%lld-%lld", fromOffset, endOffset];
            [request setValue:downloadRangeString forHTTPHeaderField:@"Range"];
        
            self.sessionDataTask = [self.urlSession dataTaskWithRequest:request];
            [self.sessionDataTask resume]; // 开始请求
        }
        
    } else {
        
        [self p_finishAllRequest:nil];
    }
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler{
//    NSLog(@"~~~NSURL Delegate 收到回复:%@", response);
    
    NSString *mimeType = response.MIMEType;
    
    if ([mimeType rangeOfString:@"video/"].location == NSNotFound &&
           [mimeType rangeOfString:@"audio/"].location == NSNotFound &&
           [mimeType rangeOfString:@"application"].location == NSNotFound) {
        
        // 如果不是 video/audio 数据的话， 就取消掉这个task
        completionHandler(NSURLSessionResponseCancel);
    
    } else {
        
        //服务器首次响应请求时，返回的响应头，长度为2字节，包含该次网络请求返回的音频文件的内容信息，例如文件长度，类型等
        [self p_fillContentInfoWithResponse:response];
        
        completionHandler(NSURLSessionResponseAllow);
    }
}

//下载中，服务器返回数据时，调用该方法，可能会调用多次
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{

    [self p_handleReceiveData:data];
    
}

//请求完成调用该方法
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    if (!error) {
        
        //记录先archive下
        [[iRonPlayerRangeManager shared] archiveWithUrl:self.loadingRequest.request.URL];
        /// 继续处理请求
        [self p_handleLoadingRequest];
        
    } else {
        NSLog(@"[iRonPlayer]%s:%@", __func__, error);
        [self p_finishAllRequest:error];
    }
}

#pragma mark - Handle Request Data

- (void)p_fillContentInfoWithResponse:(NSURLResponse *)response {
    AVAssetResourceLoadingContentInformationRequest *contentInfoRequest = self.loadingRequest.contentInformationRequest;
    if (contentInfoRequest && !contentInfoRequest.contentType) {
        if (![response isKindOfClass:[NSHTTPURLResponse class]]) {
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        //服务器端是否支持分段传输
        BOOL byteRangeAccessSupported = [httpResponse.allHeaderFields[@"Accept-Ranges"] isEqualToString:@"bytes"] || [httpResponse.allHeaderFields[@"Accept-Ranges"] isEqualToString:@"Bytes"];
        
        //获取返回文件的长度
        long long contentLength = [[[httpResponse.allHeaderFields[@"Content-Range"] componentsSeparatedByString:@"/"] lastObject] longLongValue];
        
        //获取返回文件的类型
        NSString *mimeType = httpResponse.MIMEType;
        CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)mimeType, NULL);//此处需要引入<MobileCoreServices/MobileCoreServices.h>头文件
        NSString *contentTypeStr = CFBridgingRelease(contentType);

        contentInfoRequest.byteRangeAccessSupported = byteRangeAccessSupported;
        contentInfoRequest.contentLength = contentLength;
        contentInfoRequest.contentType = contentTypeStr;
        
        
        
        iRonPlayerContentInfo *contentInfo = [iRonPlayerContentInfo new];
        contentInfo.byteRangeAccessSupported = byteRangeAccessSupported;
        contentInfo.contentLength = contentLength;
        contentInfo.contentType = contentTypeStr;
        [iRonPlayerRangeManager saveContentInfoArchiver:contentInfo withUrl:self.loadingRequest.request.URL];
    }
}

- (void)p_fillContentInfo:(iRonPlayerContentInfo *)contentInfo {
    AVAssetResourceLoadingContentInformationRequest *contentInfoRequest = self.loadingRequest.contentInformationRequest;
    if (contentInfoRequest && !contentInfoRequest.contentType && contentInfo) {
        
        contentInfoRequest.byteRangeAccessSupported = contentInfo.byteRangeAccessSupported;
        contentInfoRequest.contentLength = contentInfo.contentLength;
        contentInfoRequest.contentType = contentInfo.contentType;
    }
    
}

- (void)p_handleReceiveData:(NSData *)data {
    NSRange cacheRange = NSMakeRange(self.currentModel.requestRange.location + self.currentModelReceivedDataLength, data.length);

    NSError *error;
    //缓存
    [self.cacheManager addCacheData:data withRange:cacheRange error:&error];
    if (error) {
        
        NSLog(@"error:%@", error);
        return;
    }
    //记录缓存
    [[iRonPlayerRangeManager shared] addCachedRange:cacheRange withUrl:self.loadingRequest.request.URL];
    self.currentModelReceivedDataLength += data.length;
    
    // respondWithData 回填数据
    [self.loadingRequest.dataRequest respondWithData:data];
}


@end



