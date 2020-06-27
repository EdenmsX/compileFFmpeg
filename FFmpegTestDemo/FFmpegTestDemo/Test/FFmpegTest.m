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

+ (void)ffmpegVideoDecode:(NSString *)filePath outFilePath:(NSString *)outFilePath {
    //1. 注册组件(现在已不需要自己手动注册)
//    av_register_all();
    //2. 打开文件
    //2.1 创建上下文
    AVFormatContext *avformat_context = avformat_alloc_context();
    //2.2 转换视频路径数据类型
    const char *url = [filePath UTF8String];
    //2.3 打开封装格式文件
    int avformat_open_input_result = avformat_open_input(&avformat_context, url, NULL, NULL);
    //2.4 判断打开结果
    if (avformat_open_input_result != 0) {
        NSLog(@"文件开发失败");
        return;
    }
    //文件打开成功, 开始解码
    
    //3. 查找视频流, 拿到视频信息
    /**
     param1: 封装格式上线文
     param2: 指定默认配置
     */
    int avformat_find_stream_info_result = avformat_find_stream_info(avformat_context, NULL);
    if (avformat_find_stream_info_result != 0) {
        NSLog(@"查找视频流失败");
        return;
    }
    
    //4. 查找解码器
    //4.1 查找视频流索引位置
    int av_stream_index = -1;
    for (int i = 0; i < avformat_context->nb_streams; i++) {
        //判断流类型: 视频流, 音频流, 字母流等
        if (avformat_context->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
            av_stream_index = i;
            break;
        }
    }
    
    //4.2 根据视频流索引, 获取解码器参数
    AVCodecParameters *avcodecparams = avformat_context->streams[av_stream_index]->codecpar;
    
    //4.3 根据解码器参数, 获取解码器ID, 然后查找解码器
    AVCodec *avcodec = avcodec_find_decoder(avcodecparams->codec_id);
    
    //5. 打开解码器
    //创建解码器上下文
    AVCodecContext *avctx = avcodec_alloc_context3(avcodec);
    int avcodec_parameters_to_context_result = avcodec_parameters_to_context(avctx, avcodecparams);
    if (avcodec_parameters_to_context_result != 0) {
        NSLog(@"上下文参数写入上下文失败");
        return;
    }
    
//    AVCodecContext *avctx = avformat_context->streams[av_stream_index]->codec;
//    AVCodec *avcodec = avcodec_find_decoder(avctx->codec_id);
    
    int avcodec_open2_result = avcodec_open2(avctx, avcodec, NULL);
    if (avcodec_open2_result != 0) {
        NSLog(@"打开解码器失败");
        return;
    }
    NSLog(@"解码器名称: %s", avcodec->name);
    
    //6. 读取视频压缩数据(循环读取)
    //结构体大小计算(字节对齐原则)
    AVPacket *packet = (AVPacket *)av_malloc(sizeof(AVPacket));
    //解码一帧的视频压缩数据
    //开辟一块内存空间
    AVFrame *av_frame_in = av_frame_alloc();
    int decode_result = 0;
    /**
     参数1(srcW):  源文件, 原始视频像素数据格式宽度
     参数2(srcH):  源文件, 原始视频像素数据格式高度
     参数3(srcFormat):  源文件, 原始视频像素数据格式类型
     参数4(dstW):  目标文件, 目标视频像素数据格式宽度
     参数5(dstH):  目标文件, 目标视频像素数据格式高度
     参数6(dstFormat):  目标文件, 目标视频像素数据格式类型
     */
    struct SwsContext *swscontext = sws_getContext(avctx->width,
                                                   avctx->height,
                                                   avctx->pix_fmt,
                                                   avctx->width,
                                                   avctx->height,
                                                   AV_PIX_FMT_YUV420P,
                                                   SWS_BICUBIC,
                                                   NULL,
                                                   NULL,
                                                   NULL);
    //创建一个YUV420p视频像素数据格式缓冲区(一帧数据)
    AVFrame *avframe_420p = av_frame_alloc();
    /** 得到YUV420p缓冲区大小
     参数1: 视频像素数据格式类型(YUV420p格式)
     参数2: 一帧视频像素数据宽度(=视频宽度)
     参数3: 一帧视频像素数据高度(=视频高度)
     参数4: 字节对齐方式(默认为1)
     */
    int buffer_size = av_image_get_buffer_size(AV_PIX_FMT_YUV420P, avctx->width, avctx->height, 1);
    //开辟一块内存空间
    uint8_t *out_buffer = (uint8_t *)av_malloc(buffer_size);
    /** 填充数据
     参数1: 目标->填充数据(avframe_YUV420p)
     参数2: 目标-> 每一行大小
     参数3: 原始数据
     参数4: 目标-> 格式类型
     参数5: 宽
     参数6: 高
     参数7: 字节对齐方式
     */
    av_image_fill_arrays(avframe_420p->data,
                         avframe_420p->linesize,
                         out_buffer,
                         AV_PIX_FMT_YUV420P,
                         avctx->width,
                         avctx->height,
                         1);
    //将YUV420p数据写入.yuv文件中
    //打开文件
    const char *outfile = [outFilePath UTF8String];
    FILE *file_yuv420p = fopen(outfile, "wb+");
    if (file_yuv420p == NULL) {
        NSLog(@"文件打开失败");
        return;
    }
    
    int y_size, u_size, v_size;
    int current_index = 0;
    /**
     av_read_frame 参数:
     参数1: 封装格式上下文
     参数2: 一帧压缩数据(一张图片)
     */
    while (av_read_frame(avformat_context, packet) >= 0) {
        /**
         av_read_frame(avformat_context, packet) 结果
         >=0  表示读取到了
         <0    表示读取错误或者读取完毕
         */
        //判断是否是需要的视频流
        if (packet->stream_index == av_stream_index) {
            //解码
            //解码一帧压缩数据->得到视频像素数据->yuv格式
            //发送一帧视频压缩数据
            avcodec_send_packet(avctx, packet);
            //解码一帧视频压缩数据
            decode_result = avcodec_receive_frame(avctx, av_frame_in);
            if (decode_result == 0) {
                //解码成功
                //不能保证解码出来的一帧视频像素数据格式是哪种YUV格式, 视频项目数据格式有多种类型: yuv420p, yuv422p, yuv444p等
                //为了保证解码后的视频数据格式统一为yuv420p(通用的格式), 需要进行类型转换
                //类型转换: 将解码出来的视频像素数据格式统一转换类型为yuv420p
                /**
                 sws_scale 类型转换
                 参数1(c): 视频像素数据格式上下文
                 参数2(srcSlice): 源文件的视频像素数据格式: 输入数据
                 参数3(srcStride): 源文件的视频像素数据格式: 输入画面每一行大小
                 参数4(srcSliceY): 源文件的视频像素数据格式: 输入画面每一行开始位置(填写0: 表示从原点开始读取)
                 参数5(srcSliceH): 源文件的视频像素数据格式: 输入数据行数
                 参数6(dst): 转换类型后视频像素数据格式: 输出数据
                 参数7(dstStride): 转换类型后视频像素数据格式: 输出画面每一行大小
                 */
                sws_scale(swscontext,
                          (const uint8_t * const *)av_frame_in->data,
                          av_frame_in->linesize,
                          0,
                          avctx->height,
                          avframe_420p->data,
                          avframe_420p->linesize);
                //方式1: 直接显示视频
                //方式2: 写入yuv文件格式
                //将yuv420p数据写入.yuv文件中
                //计算yuv大小  (y表示亮度, uv表示色度)
                //yuv420p格式规范一: Y结构表示一个像素(一个像素对应一个Y)
                //yuv420p格式规范二: 4个像素点对应一个u和v(4Y = U = V)
                y_size = avctx->width * avctx->height;
                u_size = y_size / 4;
                v_size = y_size / 4;
                //写入.yuv文件
                //写入Y数据
                fwrite(avframe_420p->data[0], 1, y_size, file_yuv420p);
                //写入U数据
                fwrite(avframe_420p->data[0], 1, y_size, file_yuv420p);
                //写入V数据
                fwrite(avframe_420p->data[0], 1, y_size, file_yuv420p);
                
                current_index++;
                NSLog(@"当前解码第%d帧", current_index);
            }
        }
    }
    
    //释放内存资源, 关闭解码器
    av_packet_free(&packet);
    fclose(file_yuv420p);
    av_frame_free(&av_frame_in);
    av_frame_free(&avframe_420p);
    free(out_buffer);
    avcodec_close(avctx);
    avformat_free_context(avformat_context);
    
    
    
    
    
}

@end
