//
//  FFmpegTest.h
//  FFmpegTestDemo
//
//  Created by 刘李斌 on 2020/6/24.
//  Copyright © 2020 Brilliance. All rights reserved.
//

#import <Foundation/Foundation.h>

///引入头文件
///核心库
#import <libavcodec/avcodec.h>
///引入封装格式库
#import <libavformat/avformat.h>


NS_ASSUME_NONNULL_BEGIN

@interface FFmpegTest : NSObject


/// 测试FFmpeg的配置
+ (void)ffmpegConfigTest;


/// 打开视频文件
/// @param filePath 文件地址
+ (void)ffmpegOpenVideoFile:(NSString *)filePath;

@end

NS_ASSUME_NONNULL_END
