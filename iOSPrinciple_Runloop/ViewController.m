//
//  ViewController.m
//  iOSPrinciple_Runloop
//
//  Created by WhatsXie on 2018/5/8.
//  Copyright © 2018年 WhatsXie. All rights reserved.
//

#import "ViewController.h"
#import "RunloopTimerModeViewController.h"
#import "RunlooploadImageModeViewController.h"
#import "RunloopObserverViewController.h"
#import "RunloopLongrunViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self getRunloop];
    
    [self performSelector];
    
    [self timerTest];
}

/// Source0 触摸事件
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    NSLog(@"点击了屏幕");
}

/// Source0 performSelector
- (void)performSelector {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self performSelectorOnMainThread:@selector(test) withObject:nil waitUntilDone:YES];
    });
}
- (void)test {}

/// Timers
- (void)timerTest {
    [NSTimer scheduledTimerWithTimeInterval:3.0 repeats:NO block:^(NSTimer * _Nonnull timer) {
        NSLog(@"NSTimer ---- timer调用了");
    }];
}
- (void)getRunloop {
    // 获得当前线程的RunLoop对象
    NSLog(@"获得当前线程的RunLoop对象: \n%@", [NSRunLoop currentRunLoop]);
    // 获得主线程的RunLoop对象
    NSLog(@"获得主线程的RunLoop对象: \n%@", [NSRunLoop mainRunLoop]);

    // 获得当前线程的RunLoop对象
    NSLog(@"获得当前线程的RunLoop对象: \n%@", CFRunLoopGetCurrent());
    // 获得主线程的RunLoop对象
    NSLog(@"获得主线程的RunLoop对象: \n%@", CFRunLoopGetMain());
}
- (IBAction)timerAction:(id)sender {
    RunloopTimerModeViewController *vc = [RunloopTimerModeViewController new];
    [self.navigationController pushViewController:vc animated:YES];
}
- (IBAction)loadImageAction:(id)sender {
    RunlooploadImageModeViewController *vc = [RunlooploadImageModeViewController new];
    [self.navigationController pushViewController:vc animated:YES];
}
- (IBAction)observerAction:(id)sender {
    RunloopObserverViewController *vc = [RunloopObserverViewController new];
    [self.navigationController pushViewController:vc animated:YES];
}
- (IBAction)longrunAction:(id)sender {
    RunloopLongrunViewController *vc = [RunloopLongrunViewController new];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

@end
