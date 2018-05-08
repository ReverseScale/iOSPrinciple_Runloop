//
//  main.m
//  iOSPrinciple_Runloop
//
//  Created by WhatsXie on 2018/5/8.
//  Copyright © 2018年 WhatsXie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

int main(int argc, char * argv[]) {
    @autoreleasepool {
        NSLog(@"开始");
        int rooloop = UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
        NSLog(@"结束");
        return rooloop;
    }
}
