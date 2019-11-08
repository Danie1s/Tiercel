//
//  OCSingleFileController.m
//  Demo
//
//  Created by yw_zhuangtao on 2019/11/8.
//  Copyright © 2019 Daniels. All rights reserved.
//

#import "OCSingleFileController.h"
#import <Tiercel/Tiercel-Swift.h>
#import "Demo-Swift.h"
static NSString *URLString = @"http://dldir1.qq.com/qqfile/QQforMac/QQ_V4.2.4.dmg";

@interface OCSingleFileController ()

@property (weak, nonatomic) IBOutlet UILabel *speedLabel;
@property (weak, nonatomic) IBOutlet UILabel *progressLabel;
@property (weak, nonatomic) IBOutlet UILabel *timeRemainingLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (weak, nonatomic) IBOutlet UILabel *startDateLabel;
@property (weak, nonatomic) IBOutlet UILabel *endDateLabel;
@property (weak, nonatomic) IBOutlet UILabel *validationLabel;

@property (nonatomic, strong) BridgeSessionManager *sessionManager;
@end

@implementation OCSingleFileController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.sessionManager = ((AppDelegate *)[UIApplication sharedApplication].delegate).sessionManager5;
    
    BridgeTask *task = self.sessionManager.tasks.firstObject;
    if (!task) return;
    [self updateUI:task];
    
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (void)updateUI:(BridgeTask *)task {
    CGFloat per = task.progress.fractionCompleted;
    self.progressLabel.text = [NSString stringWithFormat:@"progress： %0.2f",per * 100];
    self.progressView.progress = per;
    self.speedLabel.text = [NSString stringWithFormat:@"speed: %lld",[task speed]];
    self.timeRemainingLabel.text = [NSString stringWithFormat:@"剩余时间：%lld",task.timeRemaining];
    self.startDateLabel.text = [NSString stringWithFormat:@"开始时间：%0.2f",task.startDate];
    self.endDateLabel.text = [NSString stringWithFormat:@"结束时间：%0.2f",task.endDate];
    NSString *validation;
    switch (task.validation) {
    case ValidationUnkown:
            self.validationLabel.textColor = [UIColor blueColor];
            validation = @"未知";
            break;
    case ValidationCorrect:
            self.validationLabel.textColor = [UIColor greenColor];
            validation = @"正确";
            break;
    case ValidationIncorrect:
            self.validationLabel.textColor = [UIColor redColor];
            validation = @"错误";
            break;
    }
    _validationLabel.text = [NSString stringWithFormat:@"文件验证： %@",validation];
}

- (IBAction)start:(id)sender {
    
    __weak typeof(self) weakSelf = self;
    (void)[[[[[self.sessionManager download:URLString headers:nil fileName:nil] progress:YES handler:^(BridgeTask * _Nonnull task) {
        
        [weakSelf updateUI:task];
        
    }] success:YES handler:^(BridgeTask * _Nonnull task) {
        
        [weakSelf updateUI:task];
        
    }] failure:YES handler:^(BridgeTask * _Nonnull task) {
        
        [weakSelf updateUI:task];
        
        if (task.status == BridgeStatusSuspended) {
            // 下载任务暂停了
        }
        if (task.status == BridgeStatusFailed) {
            // 下载任务失败了
        }
        if (task.status == BridgeStatusCanceled) {
            // 下载任务取消了
        }
      
        
    }] validateFile:@"9e2a3650530b563da297c9246acaad5c" type:FileVerificationTypeMd5 onMainQueue:YES handler:^(BridgeTask * _Nonnull task) {
        
        [weakSelf updateUI:task];
        
    }];
}

- (IBAction)suspend:(id)sender {
    [self.sessionManager suspend: URLString];
}


- (IBAction)cancel:(id)sender {
    [self.sessionManager cancel: URLString];
}

- (IBAction)deleteTask:(id)sender {
    
    [self.sessionManager remove:URLString completely: false onMainQueue:NO handler:nil];
}

- (IBAction)clearDisk:(id)sender {
    (void)self.sessionManager.clearDisk;
}

@end
