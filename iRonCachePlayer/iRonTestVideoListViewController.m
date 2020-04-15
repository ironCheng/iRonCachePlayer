//
//  iRonTestVideoListViewController.m
//  iRonCachePlayer
//
//  Created by iRonCheng on 2020/3/27.
//  Copyright © 2020 iRon. All rights reserved.
//

#import "iRonTestVideoListViewController.h"
#import <AVKit/AVKit.h>
#import "iRonPlayerView.h"

@interface iRonTestVideoListViewController ()<
    UITableViewDelegate,
    UITableViewDataSource
>

@property (nonatomic,strong) NSArray *urlArray;

@end

@implementation iRonTestVideoListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor grayColor];

    NSArray *audioUrlArray = @[
                               @"http://download.lingyongqian.cn/music/ForElise.mp3",
                               @"http://mpge.5nd.com/2018/2018-1-23/74521/1.mp3",
                               @"http://download.lingyongqian.cn/music/AdagioSostenuto.mp3",
                               @"https://mvvideo5.meitudata.com/56ea0e90d6cb2653.mp4",
                               @"http://vfx.mtime.cn/Video/2018/05/15/mp4/180515210431224977.mp4",
                          
                               ];
    self.urlArray = audioUrlArray;
    
    CGFloat SWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat SHeight = [UIScreen mainScreen].bounds.size.height;
    
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, SWidth, SHeight) style:UITableViewStylePlain];
    tableView.delegate = self;
    tableView.dataSource = self;
    [self.view addSubview:tableView];
    
}

#pragma mark - UITableViewDelegate & UITableViewDataSource

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    return 44;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"cellID";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellID];
    }
    cell.textLabel.text = self.urlArray[indexPath.row];
    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.urlArray.count;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    
    UIViewController *vc = [UIViewController new];
    vc.view.backgroundColor = [UIColor whiteColor];
    
    
    iRonPlayerView *playerView = [[iRonPlayerView alloc] initWithFrame:CGRectMake(0, 88, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.width/375*260) videoUrl:[NSURL URLWithString:self.urlArray[indexPath.row]]];
    playerView.backgroundColor = [UIColor blackColor];
    
    playerView.loadFinishBlock = ^(NSURL * _Nonnull currentUrl) {
        
    };
    playerView.playFinishBlock = ^(NSURL * _Nonnull currentUrl) {
        
    };
    
    [playerView play];
    [vc.view addSubview:playerView];
    
    [self.navigationController pushViewController:vc animated:YES];
}

@end
