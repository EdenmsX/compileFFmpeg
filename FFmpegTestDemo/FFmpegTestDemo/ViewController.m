//
//  ViewController.m
//  FFmpegTestDemo
//
//  Created by 刘李斌 on 2020/6/24.
//  Copyright © 2020 Brilliance. All rights reserved.
//

#import "ViewController.h"

#import "FFmpegTest.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [FFmpegTest ffmpegConfigTest];
    
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"Test" ofType:@".mov"];
    [FFmpegTest ffmpegOpenVideoFile:path];
}


@end
