//
//  FFmpegTest.m
//  FFmpegTestDemo
//
//  Created by 刘李斌 on 2020/6/24.
//  Copyright © 2020 Brilliance. All rights reserved.
//

#import "FFmpegTest.h"




int flush_encoder(AVFormatContext *fmt_ctx, unsigned int stream_index) {
    int ret;
    int got_frame;
    AVPacket enc_pkt;
    if (!(fmt_ctx->streams[stream_index]->codec->codec->capabilities &
          CODEC_CAP_DELAY))
        return 0;
    while (1) {
        enc_pkt.data = NULL;
        enc_pkt.size = 0;
        av_init_packet(&enc_pkt);
        ret = avcodec_encode_video2(fmt_ctx->streams[stream_index]->codec, &enc_pkt,
                                    NULL, &got_frame);
        av_frame_free(NULL);
        if (ret < 0)
            break;
        if (!got_frame) {
            ret = 0;
            break;
        }
        NSLog(@"Flush Encoder: Succeed to encode 1 frame!\tsize:%5d\n", enc_pkt.size);
        /* mux encoded frame */
        ret = av_write_frame(fmt_ctx, &enc_pkt);
        if (ret < 0)
            break;
    }
    return ret;
}

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
        NSLog(@"失败");
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


/// 视频编码
/// @param filePath 需要编码的文件路径(文件格式为: MP4, MOV等格式)(封装格式)
/// @param outFilePath 完成编码的文件路径(YUV格式)(视频像素数据格式)
+ (void)ffmpegVideoEncode:(NSString*)filePath outFilePath:(NSString*)outFilePath {
    //第一步：注册组件->编码器、解码器等等…
    av_register_all();
    
    //第二步：初始化封装格式上下文->视频编码->处理为视频压缩数据格式
    AVFormatContext *avformat_context = avformat_alloc_context();
    //注意事项：FFmepg程序推测输出文件类型->视频压缩数据格式类型
    const char *coutFilePath = [outFilePath UTF8String];
    //    const char *coutFilePath = [@"Test.mp4" UTF8String];
    //得到视频压缩数据格式类型(h264、h265、mpeg2等等...)
    AVOutputFormat *avoutput_format = av_guess_format(NULL, coutFilePath, NULL);
    //指定类型
    avformat_context->oformat = avoutput_format;
    //    avformat_alloc_output_context2(&avformat_context, avoutput_format, NULL, NULL);
    
    //第三步：打开输出文件
    //参数一：输出流
    //参数二：输出文件
    //参数三：权限->输出到文件中
    if (avio_open(&avformat_context->pb, coutFilePath, AVIO_FLAG_WRITE) < 0) {
        NSLog(@"打开输出文件失败");
        return;
    }
    
    //第四步：创建输出码流->创建了一块内存空间->并不知道他是什么类型流->希望他是视频流
    AVStream *av_video_stream = avformat_new_stream(avformat_context, NULL);
    
    //第五步：查找视频编码器
    //1、获取编码器上下文
    AVCodecContext *avcodec_context = av_video_stream->codec;
    //    AVCodec *avcodec = avcodec_find_encoder(avformat_context->oformat->video_codec);
    //    AVCodecContext *avcodec_context = avcodec_alloc_context3(avcodec);
    //2、设置编解码器上下文参数->必需设置->不可少
    //目标：设置为是一个视频编码器上下文->指定的是视频编码器
    //上下文种类：视频解码器、视频编码器、音频解码器、音频编码器
    //2.1 设置视频编码器ID
    avcodec_context->codec_id = avoutput_format->video_codec;
    //2.2 设置编码器类型->视频编码器
    //视频编码器->AVMEDIA_TYPE_VIDEO
    //音频编码器->AVMEDIA_TYPE_AUDIO
    avcodec_context->codec_type = AVMEDIA_TYPE_VIDEO;
    //2.3 设置读取像素数据格式->编码的是像素数据格式->视频像素数据格式->YUV420P(YUV422P、YUV444P等等...)
    //注意：这个类型是根据你解码的时候指定的解码的视频像素数据格式类型
    avcodec_context->pix_fmt = AV_PIX_FMT_YUV420P;
    //2.4 设置视频宽高->视频尺寸
    avcodec_context->width = 640;
    avcodec_context->height = 352;
    //2.5 设置帧率->表示每秒25帧
    //视频信息->帧率 : 25.000 fps
    //f表示：帧数
    //ps表示：时间(单位：每秒)
    avcodec_context->time_base.num = 1;
    avcodec_context->time_base.den = 25;
    //2.6 设置码率
    //2.6.1 什么是码率？
    //含义：每秒传送的比特(bit)数单位为 bps(Bit Per Second)，比特率越高，传送数据速度越快。
    //单位：bps，"b"表示数据量，"ps"表示每秒
    //目的：视频处理->视频码率
    //2.6.2 什么是视频码率?
    //含义：视频码率就是数据传输时单位时间传送的数据位数，一般我们用的单位是kbps即千位每秒
    //视频码率计算如下？
    //基本的算法是：【码率】(kbps)=【视频大小 - 音频大小】(bit位) /【时间】(秒)
    //例如：Test.mov时间 = 24，文件大小(视频+音频) = 1.73MB
    //视频大小 = 1.34MB（文件占比：77%） = 1.34MB * 1024 * 1024 * 8 = 字节大小 = 468365字节 = 468Kbps
    //音频大小 = 376KB（文件占比：21%）
    //计算出来值->码率 : 468Kbps->表示1000，b表示位(bit->位)
    //总结：码率越大，视频越大
    avcodec_context->bit_rate = 468000;
    
    //2.7 设置GOP->影响到视频质量问题->画面组->一组连续画面
    //MPEG格式画面类型：3种类型->分为->I帧、P帧、B帧
    //I帧->内部编码帧->原始帧(原始视频数据)
    //    完整画面->关键帧(必需的有，如果没有I，那么你无法进行编码，解码)
    //    视频第1帧->视频序列中的第一个帧始终都是I帧，因为它是关键帧
    //P帧->向前预测帧->预测前面的一帧类型，处理数据(前面->I帧、B帧)
    //    P帧数据->根据前面的一帧数据->进行处理->得到了P帧
    //B帧->前后预测帧(双向预测帧)->前面一帧和后面一帧
    //    B帧压缩率高，但是对解码性能要求较高。
    //总结：I只需要考虑自己 = 1帧，P帧考虑自己+前面一帧 = 2帧，B帧考虑自己+前后帧 = 3帧
    //    说白了->P帧和B帧是对I帧压缩
    //每250帧，插入1个I帧，I帧越少，视频越小->默认值->视频不一样
    avcodec_context->gop_size = 250;
    
    //2.8 设置量化参数->数学算法(高级算法)->不讲解了
    //总结：量化系数越小，视频越是清晰
    //一般情况下都是默认值，最小量化系数默认值是10，最大量化系数默认值是51
    avcodec_context->qmin = 10;
    avcodec_context->qmax = 51;
    
    //2.9 设置b帧最大值->设置不需要B帧
    avcodec_context->max_b_frames = 0;
    
    //第二点：查找编码器->h264
    //找不到编码器->h264
    //重要原因是因为：编译库没有依赖x264库（默认情况下FFmpeg没有编译进行h264库）
    //第一步：编译h264库
    AVCodec *avcodec = avcodec_find_encoder(avcodec_context->codec_id);
    if (avcodec == NULL) {
        NSLog(@"找不到编码器");
        return;
    }
    
    NSLog(@"编码器名称为：%s", avcodec->name);
    
    
    //第六步：打开h264编码器
    //缺少优化步骤？
    //编码延时问题
    //编码选项->编码设置
    AVDictionary *param = 0;
    if (avcodec_context->codec_id == AV_CODEC_ID_H264) {
        //需要查看x264源码->x264.c文件
        //第一个值：预备参数
        //key: preset
        //value: slow->慢
        //value: superfast->超快
        av_dict_set(&param, "preset", "slow", 0);
        //第二个值：调优
        //key: tune->调优
        //value: zerolatency->零延迟
        av_dict_set(&param, "tune", "zerolatency", 0);
    }
    if (avcodec_open2(avcodec_context, avcodec, &param) < 0) {
        NSLog(@"打开编码器失败");
        return;
    }
    
    //第七步: 写入文件头信息
    int writeRus = avformat_write_header(avformat_context, NULL);
    if (writeRus == AVSTREAM_INIT_IN_WRITE_HEADER) {
        NSLog(@"AVSTREAM_INIT_IN_WRITE_HEADER on success if the codec had not already been fully initialized in avformat_init");
        
    } else {
        NSLog(@"AVSTREAM_INIT_IN_INIT_OUTPUT  on success if the codec had already been fully initialized in avformat_init");
    }
    
    //第八步: 循环编码yuv文件->视频像素数据(yuv格式)->编码->视频压缩数据格式(h264格式)
    //8.1 定义一个缓冲区(用来缓存一帧视频像素数据)
    //8.1.1 获取缓冲区大小
    int buffer_size = av_image_get_buffer_size(avcodec_context->pix_fmt,
                                               avcodec_context->width,
                                               avcodec_context->height,
                                               1);
    //8.1.2 创建一个缓冲区
    int y_size = avcodec_context->width * avcodec_context->height;
    uint8_t *out_buffer = (uint8_t *)av_malloc(buffer_size);
    
    //8.1.3 打开输入文件
    const char *cinFilePath = [filePath UTF8String];
    FILE *in_file = fopen(cinFilePath, "rb");
    if (in_file == NULL) {
        NSLog(@"文件不存在");
        return;
    }
    //8.2.1 开辟一块内存空间->av_frame_alloc
    //开辟了一块内存空间
    AVFrame *av_frame = av_frame_alloc();
    //8.2.2 设置缓冲区和AVFrame类型保持一直->填充数据
    av_image_fill_arrays(av_frame->data,
                         av_frame->linesize,
                         out_buffer,
                         avcodec_context->pix_fmt,
                         avcodec_context->width,
                         avcodec_context->height,
                         1);
    
    int i = 0;
    
    //9.2 接收一帧视频像素数据->编码为->视频压缩数据格式
    AVPacket *av_packet = (AVPacket *) av_malloc(buffer_size);
    int result = 0;
    int current_frame_index = 1;
    while (true) {
        //8.1 从yuv文件里面读取缓冲区
        //读取大小：y_size * 3 / 2
        if (fread(out_buffer, 1, y_size * 3 / 2, in_file) <= 0) {
            NSLog(@"读取完毕...");
            break;
        } else if (feof(in_file)) {
            break;
        }
        
        //8.2 将缓冲区数据->转成AVFrame类型
        //给AVFrame填充数据
        //8.2.3 void * restrict->->转成->AVFrame->ffmpeg数据类型
        //Y值
        av_frame->data[0] = out_buffer;
        //U值
        av_frame->data[1] = out_buffer + y_size;
        //V值
        av_frame->data[2] = out_buffer + y_size * 5 / 4;
        av_frame->pts = i;
        //注意时间戳
        i++;
        //总结：这样一来我们的AVFrame就有数据了
        
        //第9步：视频编码处理
        //9.1 发送一帧视频像素数据
        avcodec_send_frame(avcodec_context, av_frame);
        //9.2 接收一帧视频像素数据->编码为->视频压缩数据格式
        result = avcodec_receive_packet(avcodec_context, av_packet);
        //9.3 判定是否编码成功
        if (result == 0) {
            //编码成功
            //第10步：将视频压缩数据->写入到输出文件中->outFilePath
            av_packet->stream_index = av_video_stream->index;
            result = av_write_frame(avformat_context, av_packet);
            NSLog(@"当前是第%d帧", current_frame_index);
            current_frame_index++;
            //是否输出成功
            if (result < 0) {
                NSLog(@"输出一帧数据失败");
                return;
            }
        }
    }
    
    //第11步：写入剩余帧数据->可能没有
    flush_encoder(avformat_context, 0);
    
    //第12步：写入文件尾部信息
    av_write_trailer(avformat_context);
    
    //第13步：释放内存
    avcodec_close(avcodec_context);
    av_free(av_frame);
    av_free(out_buffer);
    av_packet_free(&av_packet);
    avio_close(avformat_context->pb);
    avformat_free_context(avformat_context);
    fclose(in_file);
}


/// 音频编码
/// @param filePath 需要编码的音频文件路径
/// @param outFilePath 完成编码的文件路径
+ (void)ffmpegAudioEncode:(NSString *)filePath outFilePath:(NSString *)outFilePath {
    //第一步：注册组件->音频编码器等等…
    av_register_all();
    
    //第二步：初始化封装格式上下文->视频编码->处理为音频压缩数据格式
    AVFormatContext *avformat_context = avformat_alloc_context();
    //注意事项：FFmepg程序推测输出文件类型->音频压缩数据格式类型->aac格式
    const char *coutFilePath = [outFilePath UTF8String];
    //得到音频压缩数据格式类型(aac、mp3等...)
    AVOutputFormat *avoutput_format = av_guess_format(NULL, coutFilePath, NULL);
    //指定类型
    avformat_context->oformat = avoutput_format;
    
    //第三步：打开输出文件
    //参数一：输出流
    //参数二：输出文件
    //参数三：权限->输出到文件中
    if (avio_open(&avformat_context->pb, coutFilePath, AVIO_FLAG_WRITE) < 0) {
        NSLog(@"打开输出文件失败");
        return;
    }
    
    //第四步：创建输出码流->创建了一块内存空间->并不知道他是什么类型流->希望他是视频流
    AVStream *audio_st = avformat_new_stream(avformat_context, NULL);
    
    //第五步：查找音频编码器
    //1、获取编码器上下文
    AVCodecContext *avcodec_context = audio_st->codec;
    
    //2、设置编解码器上下文参数->必需设置->不可少
    //目标：设置为是一个音频编码器上下文->指定的是音频编码器
    //上下文种类：音频解码器、音频编码器
    //2.1 设置音频编码器ID
    avcodec_context->codec_id = avoutput_format->audio_codec;
    //2.2 设置编码器类型->音频编码器
    //视频编码器->AVMEDIA_TYPE_VIDEO
    //音频编码器->AVMEDIA_TYPE_AUDIO
    avcodec_context->codec_type = AVMEDIA_TYPE_AUDIO;
    //2.3 设置读取音频采样数据格式->编码的是音频采样数据格式->音频采样数据格式->pcm格式
    //注意：这个类型是根据你解码的时候指定的解码的音频采样数据格式类型
    avcodec_context->sample_fmt = AV_SAMPLE_FMT_S16;
    //设置采样率
    avcodec_context->sample_rate = 44100;
    //立体声
    avcodec_context->channel_layout = AV_CH_LAYOUT_STEREO;
    //声道数量
    int channels = av_get_channel_layout_nb_channels(avcodec_context->channel_layout);
    avcodec_context->channels = channels;
    //设置码率
    //基本的算法是：【码率】(kbps)=【视频大小 - 音频大小】(bit位) /【时间】(秒)
    avcodec_context->bit_rate = 128000;
    
    //第二点：查找音频编码器->aac
    //    AVCodec *avcodec = avcodec_find_encoder(avcodec_context->codec_id);
    AVCodec *avcodec = avcodec_find_encoder_by_name("libfdk_aac");
    if (avcodec == NULL) {
        NSLog(@"找不到音频编码器");
        return;
    }
    
    
    //第六步：打开aac编码器
    if (avcodec_open2(avcodec_context, avcodec, NULL) < 0) {
        NSLog(@"打开音频编码器失败");
        return;
    }
    
    //第七步：写文件头（对于某些没有文件头的封装格式，不需要此函数。比如说MPEG2TS）
    avformat_write_header(avformat_context, NULL);
    
    //打开YUV文件
    const char *c_inFilePath = [filePath UTF8String];
    FILE *in_file = fopen(c_inFilePath, "rb");
    if (in_file == NULL) {
        NSLog(@"YUV文件打开失败");
        return;
    }
    
    //第十步：初始化音频采样数据帧缓冲区
    AVFrame *av_frame = av_frame_alloc();
    av_frame->nb_samples = avcodec_context->frame_size;
    av_frame->format = avcodec_context->sample_fmt;
    
    //得到音频采样数据缓冲区大小
    int buffer_size = av_samples_get_buffer_size(NULL,
                                                 avcodec_context->channels,
                                                 avcodec_context->frame_size,
                                                 avcodec_context->sample_fmt,
                                                 1);
    
    
    //创建缓冲区->存储音频采样数据->一帧数据
    uint8_t *out_buffer = (uint8_t *) av_malloc(buffer_size);
    avcodec_fill_audio_frame(av_frame,
                             avcodec_context->channels,
                             avcodec_context->sample_fmt,
                             (const uint8_t *)out_buffer,
                             buffer_size,
                             1);
    
    //第十二步：创建音频压缩数据->帧缓存空间
    AVPacket *av_packet = (AVPacket *) av_malloc(buffer_size);
    
    
    //第十三步：循环读取视频像素数据格式->编码压缩->视频压缩数据格式
    int frame_current = 1;
    int i = 0, ret = 0;
    
    //第八步：循环编码每一帧视频
    //即将AVFrame（存储YUV像素数据）编码为AVPacket（存储H.264等格式的码流数据）
    while (true) {
        //1、读取一帧音频采样数据
        if (fread(out_buffer, 1, buffer_size, in_file) <= 0) {
            NSLog(@"Failed to read raw data! \n");
            break;
        } else if (feof(in_file)) {
            break;
        }
        
        //2、设置音频采样数据格式
        //将outbuffer->av_frame格式
        av_frame->data[0] = out_buffer;
        av_frame->pts = i;
        i++;
        
        //3、编码一帧音频采样数据->得到音频压缩数据->aac
        //采用新的API
        //3.1 发送一帧音频采样数据
        ret = avcodec_send_frame(avcodec_context, av_frame);
        if (ret != 0) {
            NSLog(@"Failed to send frame! \n");
            return;
        }
        //3.2 编码一帧音频采样数据
        ret = avcodec_receive_packet(avcodec_context, av_packet);
        
        if (ret == 0) {
            //第九步：将编码后的音频码流写入文件
            NSLog(@"当前编码到了第%d帧", frame_current);
            frame_current++;
            av_packet->stream_index = audio_st->index;
            ret = av_write_frame(avformat_context, av_packet);
            if (ret < 0) {
                NSLog(@"写入失败! \n");
                return;
            }
        } else {
            NSLog(@"Failed to encode! \n");
            return;
        }
    }
    
    //第十步：输入的像素数据读取完成后调用此函数。用于输出编码器中剩余的AVPacket。
    ret = flush_encoder(avformat_context, 0);
    if (ret < 0) {
        NSLog(@"Flushing encoder failed\n");
        return;
    }
    
    //第十一步：写文件尾（对于某些没有文件头的封装格式，不需要此函数。比如说MPEG2TS）
    av_write_trailer(avformat_context);
    
    
    //第十二步：释放内存，关闭编码器
    avcodec_close(avcodec_context);
    av_free(av_frame);
    av_free(out_buffer);
    av_packet_free(&av_packet);
    avio_close(avformat_context->pb);
    avformat_free_context(avformat_context);
    fclose(in_file);
}

@end
