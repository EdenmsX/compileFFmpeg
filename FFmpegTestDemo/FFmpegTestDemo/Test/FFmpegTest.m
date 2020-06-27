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
    NSLog(@"解码完成, 释放资源");
    //释放内存资源, 关闭解码器
    av_packet_free(&packet);
    fclose(file_yuv420p);
    av_frame_free(&av_frame_in);
    av_frame_free(&avframe_420p);
    free(out_buffer);
    avcodec_close(avctx);
    avformat_free_context(avformat_context);
    
}

+ (void)ffmpegAudioDecode:(NSString *)filePath outFilePath:(NSString *)outFilePath {
    //1. 注册组件(现在已不需要)
//    av_register_all();
    //2. 打开封装格式文件(解封装)
    //封装格式上下文
    AVFormatContext *avformat_context = avformat_alloc_context();
    //视频路径
    const char *url = [filePath UTF8String];
    
    /**
     参数1: 封装格式上下文
     参数2: 文件路径
     参数3: 指定输入的格式
     参数4: 设置默认参数
     */
    if(avformat_open_input(&avformat_context, url, NULL, NULL) != 0) {
        NSLog(@"文件打开失败!");
        return;
    }
    
    //3. 查找音频流
    if (avformat_find_stream_info(avformat_context, NULL) < 0) {
        NSLog(@"查找失败");
        return;
    }
    
    //4. 查找音频解码器
    //4.1 查找音频流索引位置
    int av_audio_stream_index = -1;
    for (int i = 0; i < avformat_context->nb_streams; i++) {
        //判断是否是音频流
        if (avformat_context->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
            av_audio_stream_index = i;
            break;
        }
    }
    //4.2 根据音频流索引, 获取解码器上下文
    //获取参数
    AVCodecParameters *avcodePatameters = avformat_context->streams[av_audio_stream_index]->codecpar;
    //根据id查找音频解码器
    AVCodec *avcodec = avcodec_find_decoder(avcodePatameters->codec_id);
    //创建解码器上下文
    AVCodecContext *avcodec_context = avcodec_alloc_context3(avcodec);
    //将参数写入上下文
    if (avcodec_parameters_to_context(avcodec_context, avcodePatameters) != 0) {
        NSLog(@"创建音频解码器上下文失败");
        return;
    }
    //5. 打开音频解码器
    if (avcodec_open2(avcodec_context, avcodec, NULL) != 0) {
        NSLog(@"打开音频解码器失败");
        return;
    }
    //打印解码器名称
    NSLog(@"音频解码器名称为: %s", avcodec->name);
    
    //6. 循环读取每一帧音频压缩数据
    
    //准备一帧音频压缩数据
    AVPacket *avPacket = (AVPacket *)av_malloc(sizeof(AVPacket));
    //准备一帧音频采样数据
    AVFrame *avFrame = av_frame_alloc();
    
    
    //6.1将数据统一转换为pcm格式(swr_convert())
    //初始化音频采样数据上下文
    //6.1.1 开辟一块内存空间
    SwrContext *swrContext = swr_alloc();
    //6.1.2 设置默认配置
    int64_t in_ch_layout = av_get_default_channel_layout(avcodec_context->channels);
    /**
     参数1(s): 音频采样数据上下文
     参数2(out_ch_layout): 输出声道布局(立体声,环绕声等)
     参数3(out_sample_fmt): 输出采样精度(编码)
     参数4(out_sample_rate): 输出采样率
     参数5(in_ch_layout): 输入声道布局
     参数6(in_sample_fmt): 输入采样精度
     参数7(in_sample_rate): 输入采样率
     参数8(log_offset): 日志统计开始位置
     参数9(log_ctx): 日志上下文
     */
    swr_alloc_set_opts(swrContext,
                       AV_CH_LAYOUT_STEREO,
                       AV_SAMPLE_FMT_S16,
                       avcodec_context->sample_rate,
                       in_ch_layout,
                       avcodec_context->sample_fmt,
                       avcodec_context->sample_rate,
                       0,
                       NULL);
    //6.1.3 初始化上下文
    swr_init(swrContext);
    //6.1.4 统一输出音频采样数据格式(pcm)
    int max_audio_size = 44100 * 2;
    uint8_t *out_buffer = (uint8_t *)av_malloc(max_audio_size);
    
    //6.2 获取缓冲区实际大小
    int out_nb_buffer = av_get_channel_layout_nb_channels(AV_CH_LAYOUT_STEREO);
    
    //6.3.1 打开文件
    const char *outfile = [outFilePath UTF8String];
    FILE *file_pcm = fopen(outfile, "wb+");
    if (file_pcm == NULL) {
        NSLog(@"输出文件打开失败");
        return;
    }
    
    int current_index = 0;
    
    /** av_read_frame
     参数1: 封装格式上下文
     参数2: 一帧音频压缩数据
     返回值: >=0 表示读取成功, <0 表示失败或者解码完成(读取完毕)
     */
    while (av_read_frame(avformat_context, avPacket) >= 0) {
        //判断这一阵数据是否是音频流
        if (avPacket->stream_index == av_audio_stream_index) {
            //是音频流, 开始处理
            //1. 开始音频解码
            //1.1 发送数据包  一帧音频压缩数据   acc格式, MP3格式
            avcodec_send_packet(avcodec_context, avPacket);
            //1.2 解码数据包 (一帧音频采样数据 -> pcm格式)
            int ret = avcodec_receive_frame(avcodec_context, avFrame);
            if (ret == 0) {
                //解码成功
                //2. 类型转换(统一转换为pcm格式(swr_convert()))  解码之后的音频采样数据格式有很多中类型,为了保证格式一致, 所以需要类型转换
                /**
                 参数1(s): 音频采样数据上下文
                 参数2(out): 输出音频采样数据
                 参数3(out_count): 输出音频采样数据大小
                 参数4(in): 输入音频采样数据
                 参数5(in_count): 输入音频采样数据大小
                 */
                swr_convert(swrContext,
                            &out_buffer,
                            max_audio_size,
                            (const uint8_t **)avFrame->data,
                            avFrame->nb_samples);
                //3. 获取缓冲区实际大小
                /**
                 参数1(linesize): 行大小
                 参数2(nb_channels): 输出声道数量(单声道, 双声道)
                 参数3(nb_samples): 输入大小
                 参数4(sample_fmt): 输出音频采样数据格式
                 参数5(align): 字节对齐方式(默认1)
                 */
                int buffer_size = av_samples_get_buffer_size(NULL,
                                                             out_nb_buffer,
                                                             avFrame->nb_samples,
                                                             avcodec_context->sample_fmt,
                                                             1);
                
                //4. 写入文件
                fwrite(out_buffer, 1, buffer_size, file_pcm);
                current_index++;
                NSLog(@"当前解码到第 %d 帧", current_index);
            } else {
                NSLog(@"第 %d 帧解码失败", current_index);
            }
        }
    }
    NSLog(@"解码完成, 释放资源");
    //7. 释放资源, 关闭解码器
    av_packet_free(&avPacket);
    fclose(file_pcm);
    av_frame_free(&avFrame);
    free(out_buffer);
    avcodec_close(avcodec_context);
    avformat_free_context(avformat_context);
       
}

@end
