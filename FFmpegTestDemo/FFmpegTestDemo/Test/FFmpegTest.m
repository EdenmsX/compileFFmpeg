//
//  FFmpegTest.m
//  FFmpegTestDemo
//
//  Created by 刘李斌 on 2020/6/24.
//  Copyright © 2020 Brilliance. All rights reserved.
//

#import "FFmpegTest.h"

@implementation FFmpegTest

+ (void)ffmpegConfigTest {
    const char *config = avcodec_configuration();
    NSLog(@"配置信息: %s", config);
}

+ (void)ffmpegOpenVideoFile:(NSString *)filePath {
    //注册组件(现在已不需要)
//    av_register_all();
    
    //封装格式上下文
    AVFormatContext *avformat_context = avformat_alloc_context();
    //视频地址
    const char *url = [filePath UTF8String];
    /**
     打开封装格式文件
     @prama  <#AVFormatContext **ps#>       封装格式上下文
     @prama  <#const char *url#>                    打开视频地址
     @prama  <#AVInputFormat *fmt#>            指定输入封装格式(NULL为默认)
     @prama  <#AVDictionary **options#>       指定默认配置信息(NULL为默认)
     
     @retu 返回值为0表示打开成功
     */
    int openInputResult = avformat_open_input(&avformat_context, url, NULL, NULL);
    if (openInputResult != 0) {
        //获取错误信息
        char *err = NULL;
        av_strerror(openInputResult, err, 1024);
        NSLog(@"打开失败, 错误信息: %s", err);
        return;
    }
    NSLog(@"文件打开成功");
}

@end
