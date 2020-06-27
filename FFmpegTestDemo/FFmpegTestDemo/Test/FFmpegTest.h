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
///工具库
#import <libavutil/imgutils.h>
///视频像素数据格式库
#import <libswscale/swscale.h>
#import <libswresample/swresample.h>


NS_ASSUME_NONNULL_BEGIN

@interface FFmpegTest : NSObject


/// 测试FFmpeg的配置
+ (void)ffmpegConfigTest;


/// 打开视频文件
/// @param filePath 文件地址
+ (void)ffmpegOpenVideoFile:(NSString *)filePath;


/// 视频解码
/// @param filePath 需要解码的文件路径(文件格式为: MP4, MOV等格式)(封装格式)
/// @param outFilePath 完成解码的文件路径(YUV格式)(视频像素数据格式)
+ (void)ffmpegVideoDecode:(NSString *)filePath outFilePath:(NSString *)outFilePath;


/// 音频解码
/// @param filePath 需要解码的音频文件路径
/// @param outFilePath 完成解码的文件路径
+ (void)ffmpegAudioDecode:(NSString *)filePath outFilePath:(NSString *)outFilePath;

@end

NS_ASSUME_NONNULL_END
