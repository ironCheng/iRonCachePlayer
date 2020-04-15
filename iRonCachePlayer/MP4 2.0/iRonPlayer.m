//
//  iRonPlayer.m
//  iRonCachePlayer
//
//  Created by iRonCheng on 2020/3/23.
//  Copyright © 2020 iRon. All rights reserved.
//

#import "iRonPlayer.h"
#import "iRonPlayerDownloader.h"


static NSString *kiRonMediaScheme = @"__iRonMediaCache__:";


@interface iRonPlayer()<AVAssetResourceLoaderDelegate>

@property (nonatomic, strong) iRonPlayerDownloader *lastToEndDownloader;
@property (nonatomic, strong) NSMutableArray <iRonPlayerDownloader *>*nonToEndDownloaderArray;


@end

@implementation iRonPlayer

+ (instancetype _Nonnull )shared {
    static iRonPlayer *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [iRonPlayer new];
    });
    
    return instance;
}

- (AVPlayerItem *)playerItemWithURL:(NSURL *)url {
    NSURL *assetURL = [self p_assetURLWithNormalURL:url];
    AVURLAsset *urlAsset = [AVURLAsset URLAssetWithURL:assetURL options:nil];
    
    /** 设置<AVAssetResourceLoaderDelegate>为self */
    [urlAsset.resourceLoader setDelegate:self queue:dispatch_get_main_queue()];
    
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:urlAsset];
    if ([playerItem respondsToSelector:@selector(setCanUseNetworkResourcesForLiveStreamingWhilePaused:)]) {
        playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = YES;
    }
    return playerItem;
}

- (void)cancelAllDownloaders {
    
    if (self.lastToEndDownloader) {
        [self.lastToEndDownloader cancel];
        self.lastToEndDownloader = nil;
    }
    for (iRonPlayerDownloader *downloader in self.nonToEndDownloaderArray) {
        [downloader cancel];
        
    }
    
}

#pragma mark - AVAssetResourceLoaderDelegate

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest  {
    
    /// 同一个resourceLoader，会回调多次request
    
    NSURL *resourceURL = [loadingRequest.request URL];
    if ([resourceURL.absoluteString hasPrefix:kiRonMediaScheme]) {

        //取消上一个requestsAllDataToEndOfResource的请求
        if (loadingRequest.dataRequest.requestsAllDataToEndOfResource) {
            if (self.lastToEndDownloader) {
                long long lastRequestedOffset = self.lastToEndDownloader.loadingRequest.dataRequest.requestedOffset;
                long long lastRequestedLength = self.lastToEndDownloader.loadingRequest.dataRequest.requestedLength;
                long long lastCurrentOffset = self.lastToEndDownloader.loadingRequest.dataRequest.currentOffset;

                long long currentRequestedOffset = loadingRequest.dataRequest.requestedOffset;
                long long currentRequestedLength = loadingRequest.dataRequest.requestedLength;
                long long currentCurrentOffset = loadingRequest.dataRequest.currentOffset;
                if (lastRequestedOffset == currentRequestedOffset && lastRequestedLength == currentRequestedLength && lastCurrentOffset == currentCurrentOffset) {
                    //在弱网络情况下，下载文件最后部分时，会出现所请求数据完全一致的loadingRequest（且requestsAllDataToEndOfResource = YES），此时不应取消前一个与其相同的请求；否则会无限生成相同的请求范围的loadingRequest，无限取消，产生循环
                    // 牛逼
                    
                    return YES;
                
                } else {
                    [self.lastToEndDownloader cancel];
                }
            }
            
        }
        
        
        NSString *urlString = resourceURL.absoluteString;
        urlString = [urlString stringByReplacingOccurrencesOfString:kiRonMediaScheme withString:@""];
        NSURL *correctUrl = [NSURL URLWithString:urlString];
        iRonPlayerDownloader *downloader = [[iRonPlayerDownloader alloc] initWithLoadingRequest:loadingRequest correctUrl:correctUrl];
        if (loadingRequest.dataRequest.requestsAllDataToEndOfResource) {
            
            self.lastToEndDownloader = downloader;
            
        } else {
            
            if (!self.nonToEndDownloaderArray) {//对于不是requestsAllDataToEndOfResource的请求也要收集，在取消当前请求时要一并取消掉
                self.nonToEndDownloaderArray = [NSMutableArray array];
            }
            
            [self.nonToEndDownloaderArray addObject:downloader];
        }
        
        NSLog(@"~~~AVAssetResourceLoaderDelegate -> return YES ->(%lld,%ld)", loadingRequest.dataRequest.requestedOffset, (long)loadingRequest.dataRequest.requestedLength);
        return YES;
    }
    
    NSLog(@"~~~AVAssetResourceLoaderDelegate -> return NO");
    return NO;
}

// 自动时不时触发didCancelLoadingRequest 重新发起请求策略
- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    
//    iRonResourceLoader *loader = [self p_loaderForRequest:loadingRequest];
    NSLog(@"~~~AVAssetResourceLoaderDelegate didCancel ->(%lld,%ld)", loadingRequest.dataRequest.requestedOffset, (long)loadingRequest.dataRequest.requestedLength);
//    [loader removeRequest:loadingRequest];
    
}

#pragma mark -

- (NSURL *)p_assetURLWithNormalURL:(NSURL *)url {
    if (!url) {
        return nil;
    }
    
    NSURL *assetURL = [NSURL URLWithString:[kiRonMediaScheme stringByAppendingString:[url absoluteString]]];
    return assetURL;
}


@end
