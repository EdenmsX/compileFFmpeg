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
    
    [self encodeAudio];
    
}

- (void)encodeAudio {
    NSString *inStr= [NSString stringWithFormat:@"Video.bundle/%@",@"Test.pcm"];
    NSString *inPath=[[[NSBundle mainBundle]resourcePath] stringByAppendingPathComponent:inStr];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                         
                                                         NSUserDomainMask, YES);
    NSString *path = [paths objectAtIndex:0];
    NSString *tmpPath = [path stringByAppendingPathComponent:@"temp"];
    [[NSFileManager defaultManager] createDirectoryAtPath:tmpPath withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString* outFilePath = [tmpPath stringByAppendingPathComponent:[NSString stringWithFormat:@"Test.aac"]];
    
    [FFmpegTest ffmpegAudioEncode:inPath outFilePath:outFilePath];
}

- (void)encodeVideo {
    NSString* inPath = [[NSBundle mainBundle] pathForResource:@"Test" ofType:@"yuv"];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                         
                                                         NSUserDomainMask, YES);
    NSString *path = [paths objectAtIndex:0];
    NSString *tmpPath = [path stringByAppendingPathComponent:@"temp"];
    [[NSFileManager defaultManager] createDirectoryAtPath:tmpPath withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString* outFilePath = [tmpPath stringByAppendingPathComponent:[NSString stringWithFormat:@"Test.h264"]];
    [FFmpegTest ffmpegVideoEncode:inPath outFilePath:outFilePath];
}

- (void)decodeAudio {
    NSString *inStr = [NSString stringWithFormat:@"Video.bundle/%@", @"Test.mov"];
    NSString *inPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:inStr];
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *tempPath = [path stringByAppendingPathComponent:@"temp"];
    [[NSFileManager defaultManager] createDirectoryAtPath:tempPath withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *tempPathFile = [tempPath stringByAppendingPathComponent:@"Test.pcm"];
    
    [FFmpegTest ffmpegAudioDecode:inPath outFilePath:tempPathFile];
}

- (void)decodeVideo {
    NSString *inStr = [NSString stringWithFormat:@"Video.bundle/%@", @"Test.mov"];
    NSString *inPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:inStr];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [paths objectAtIndex:0];
    NSString *tempPath = [path stringByAppendingPathComponent:@"temp"];
    [[NSFileManager defaultManager] createDirectoryAtPath:tempPath withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *tempPathFile = [tempPath stringByAppendingPathComponent:@"Test.yuv"];
    
    [FFmpegTest ffmpegVideoDecode:inPath outFilePath:tempPathFile];
}

- (void)configTest {
    [FFmpegTest ffmpegConfigTest];
}

- (void)openVideoFile {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"Test" ofType:@".mov"];
    [FFmpegTest ffmpegOpenVideoFile:path];
}


@end
