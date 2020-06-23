#!/bin/bash
#库名称
source="ffmpeg-4.2.3"
#下载库
if [ ! -r $source ]
then
#没有下载需要执行下载操作
echo "没有下载mmpeg库, 需要下载"

#进行下载
#curl命令: 可以通过http/ftp等网络方式下载和上传文件
#基本语法: curl 地址
#下载完成后如需要可进行自动解压
#tar命令: 解压或压缩文件
#基本语法: tar 选项参数
#eg. tar xj
#tar的选项参数有很多类型(x 表示解压文件; j 表示解压bz2压缩包)
curl http://ffmpeg.org/releases/${source}.tar.bz2 | tar xj || exit 1
fi
