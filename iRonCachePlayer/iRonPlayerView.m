//
//  iRonPlayerView.m
//  iRonCachePlayer
//
//  Created by iRonCheng on 2020/3/23.
//  Copyright © 2020 iRon. All rights reserved.
//

#import "iRonPlayerView.h"
#import "iRonPlayer.h"

//  播放器的状态
typedef NS_ENUM(NSInteger, iRonPlayerState) {
    iRonPlayerStateFailed,
    iRonPlayerStateBuffering,
    iRonPlayerStatePlaying,
    iRonPlayerStateStopped,
    iRonPlayerStatePause,
};

@interface iRonPlayerView ()

@property (nonatomic, strong) NSURL *videoUrl;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;

@property (nonatomic, assign) CGFloat currentProgress;
@property (nonatomic, assign) iRonPlayerState playState;
@property (nonatomic, strong) UIActivityIndicatorView *indicatorView;

@end

@implementation iRonPlayerView

#pragma mark - Public

- (instancetype)initWithFrame:(CGRect)frame videoUrl:(NSURL *)videoUrl {
    self = [super initWithFrame:frame];
    if (self) {
        _videoUrl = videoUrl;
        [self p_setUpAll];
    }
    return self;
}

- (void)resetToPlayNewVideo:(NSURL *)videoUrl {
    [self p_resetPlayer];
    self.videoUrl = videoUrl;
    
    [self p_setUpAll];
}

- (void)play {
    if (self.player) {
        if (_playState == iRonPlayerStatePause) {
            self.playState = iRonPlayerStatePlaying;
        }
        
        [self.player play];
    }
}

- (void)pause {
    if (self.player) {
        if (_playState == iRonPlayerStatePlaying) {
            self.playState = iRonPlayerStatePause;
        }
        
        [self.player pause];
    }
}

#pragma mark - SetUp

- (void)p_setUpAll {
    
    AVPlayerItem *playerItem = [[iRonPlayer shared] playerItemWithURL:self.videoUrl];
    [self p_addKVOAndNotifiWith:playerItem];
    
    _player = [AVPlayer playerWithPlayerItem:playerItem];
    if (@available(iOS 10.0, *)) {
        _player.automaticallyWaitsToMinimizeStalling = NO;
    }
    _playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.playerLayer.frame = self.bounds;
    self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    self.playerLayer.shouldRasterize = YES;
    
    [self.layer addSublayer:self.playerLayer];
    
}

- (void)p_resetPlayer {
    [self p_removeAllObserver];
    
    [self.player pause];
    // player的item替换为nil
    [self.playerLayer removeFromSuperlayer];
    
    self.player = nil;
}

#pragma mark -

- (void)p_addKVOAndNotifiWith:(AVPlayerItem *)item {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(p_playbackFinished:) name:AVPlayerItemDidPlayToEndTimeNotification object:item];
    [item addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    [item addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
    [item addObserver:self forKeyPath:@"playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];
    [item addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew context:nil];
}

#pragma mark - KVO & Notifi

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    
    if (object != self.player.currentItem) {
        return;
    }
    
    if ([keyPath isEqualToString:@"status"]) {
        
        AVPlayerStatus status = [change[NSKeyValueChangeNewKey] integerValue];
        
        if (status == AVPlayerStatusReadyToPlay) {
            self.playState = iRonPlayerStatePlaying;
        } else if (status == AVPlayerStatusFailed) {
            self.playState = iRonPlayerStateFailed;
        }
        
    } else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {
        
        NSArray *loadedTimeRanges = [self.player.currentItem loadedTimeRanges];
        // 获取缓冲区域
        CMTimeRange timeRange = [loadedTimeRanges.firstObject CMTimeRangeValue];
        float startSeconds = CMTimeGetSeconds(timeRange.start);
        float durationSeconds = CMTimeGetSeconds(timeRange.duration);
        NSTimeInterval timeInterval = startSeconds + durationSeconds;
        
        CGFloat totalDuration = CMTimeGetSeconds(self.player.currentItem.duration);
        CGFloat progress = timeInterval / totalDuration;
        
        if (isnan(totalDuration) || isnan(timeInterval)) {
            return;
        }
        
        _currentProgress = progress;
        NSLog(@"~~~ 当前缓冲点：%f。 ", progress);
        
//        NSLog(@"~~~ timeInterval:%f, total:%f, 当前缓冲点：%f。url:%@",timeInterval, totalDuration, progress, self.videoUrl.absoluteString);
        
        if (1.0 - progress <= 0.00001) {
            if (_loadFinishBlock) {
                self.loadFinishBlock(self.videoUrl);
            }
        }
        
    } else if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
        
        //  缓冲是空的
        if (self.player.currentItem.playbackBufferEmpty) {
            self.playState = iRonPlayerStateBuffering;
        }
        
    } else if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
        
//        NSLog(@"~~~ 当前缓冲好");
        //  缓冲好的时候
        if (self.player.currentItem.playbackLikelyToKeepUp && self.playState == iRonPlayerStateBuffering) {
            self.playState = iRonPlayerStatePlaying;
        }
    
    }
}

// 播完一轮
- (void)p_playbackFinished:(NSNotification *)notification {
    AVPlayerItem *item = [notification object];
    
    __weak typeof(self) ws = self;
    [self.player seekToTime:CMTimeMake(0, item.currentTime.timescale) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
        if (finished) {
            [ws.player play];
        }
    }];
    if (self.playFinishBlock) {
        self.playFinishBlock(self.videoUrl);
    }
}

#pragma mark - Setter

- (void)setPlayState:(iRonPlayerState)playState {
    _playState = playState;
    
    if ( (playState == iRonPlayerStateBuffering || playState == iRonPlayerStateFailed) && self.playerLayer ) {
        /// loading
        self.indicatorView.alpha = 1.0;
        [self addSubview:self.indicatorView];
        
    } else {
        ///
        self.indicatorView.alpha = 0;
    }
}

#pragma mark - Getter

- (UIActivityIndicatorView *)indicatorView {
    
    if (!_indicatorView) {
        _indicatorView = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:(UIActivityIndicatorViewStyleWhiteLarge)];
        //设置小菊花的frame
        _indicatorView.frame = CGRectMake(100, 100, 100, 100);
        _indicatorView.center = CGPointMake(self.bounds.size.width/2, self.bounds.size.height/2);
        //设置小菊花颜色
        _indicatorView.color = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.8];
        //设置背景颜色
        _indicatorView.backgroundColor = [UIColor lightGrayColor];
        //刚进入这个界面会显示控件，并且停止旋转也会显示，只是没有在转动而已，没有设置或者设置为YES的时候，刚进入页面不会显示
        _indicatorView.hidesWhenStopped = NO;
        [_indicatorView startAnimating];
    }
    return _indicatorView;
    
}

#pragma mark - Other

- (void)dealloc {
    [self p_removeAllObserver];
    
    [self.player pause];
    [self.playerLayer removeFromSuperlayer];
    
    self.player = nil;
    [[iRonPlayer shared] cancelAllDownloaders];
}

- (void)p_removeAllObserver {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self.player.currentItem removeObserver:self forKeyPath:@"status"];
    [self.player.currentItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
    [self.player.currentItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
    [self.player.currentItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
}

@end
