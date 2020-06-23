#!/bin/bash

#1. 定义下载的库的名称
source="ffmpeg-4.2.3"

#2. 定义".h .m .c"文件编译的结果目录
#目录作用: 保存.h .m .c文件编译后的结果  .o文件
cache="cache"

#3. 定义.a静态库保存目录
#pwd命令: 获取当前目录
staticdir=`pwd`/"ffmpeg-iOS"

#4. 添加FFmpeg配置选项(默认配置)
#Toolchain options:工具链选项（指定我么需要编译平台CPU架构类型，例如：arm64、x86等等…）
#--enable-cross-compile: 交叉编译
#Developer options:开发者选项
#--disable-debug: 禁止使用调试模式
#Program options选项
#--disable-programs:禁用程序(不允许建立命令行程序)
#Documentation options：文档选项
#--disable-doc：不需要编译文档
#Toolchain options：工具链选项
#--enable-pic：允许建立与位置无关代码
configure_flags="--enable-cross-compile --disable-debug --disable-programs --disable-doc --enable-pic"

#5. 定义默认CPU平台架构类型
#arm64 armv7: 真机的CPU架构类型
#x86_64 i386: 模拟器的CPU架构类型
archs="arm64 armv7 x86_64 i386"

#6. 指定这个库的编译系统版本(iOS系统下 7.0及以上版本使用)
targetversion="7.0"

#7. 接收命令后输入参数
#动态接收命令行输入CPU平台架构类型(输入参数: 编译指定的CPU库)
if [ "$*" ]
then
#存在输入参数, 也就是说, 外部指定需要编译CPU架构类型
archs="$*"
fi

#8. 安装汇编器(yasm)
#先判断是否存在这个汇编器
#目的: 通过软件管理器(homebrew)下载安装(或更新)汇编器
if [ ! `which yasm`  ]
then
    #Homebrew:软件管理器
    #下载一个软件管理器:安装、卸载、更新、搜索等等...
    if [ ! `which brew` ]
    then
        echo "安装brew"
        ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" || exit 1
    fi
    echo "安装yasm"
    #成功了
    #下载安装这个汇编器
    #exit 1: 表示如果安装失败了，那么退出程序
    brew install yasm || exit 1
fi

echo "循环编译"

#9. for循环编译FFmpeg静态库
currentdir=`pwd`
for arch in $archs
do
    echo "开始编译"
    #9.1 创建目录
    #在编译结果目录下-创建对应的平台架构类型
    mkdir -p "$cache/$arch"
    #9.2 进入这个目录
    cd "$cache/$arch"

    #9.3 配置编译CPU架构类型(指定当前编译CPU架构类型)
    archflags="-arch $arch"

    #9.4 判定一下到底编译的是模拟器.a静态库，还是真机.a静态库
    if [ "$arch" = "i386" -o "$arch" = "x86_64" ]
    then
        #模拟器
        platform="iPhoneSimulator"
        #支持最小iOS系统版本
        archflags="$archflags -mios-simulator-version-min=$targetversion"
    else
        #真机(mac、iOS都支持)
        platform="iPhoneOS"
        #支持最小iOS系统版本
        archflags="$archflags -mios-version-min=$targetversion -fembed-bitcode"
        #注意:优化处理(可有可无)
        #如果架构类型是"arm64"，那么
        if [ "$arch" = "arm64" ]
        then
            #GNU汇编器（GNU Assembler），简称为GAS
            #GASPP: 汇编器预处理程序
            #解决问题：分段错误
            #通俗一点：就是程序运行时,变量访问越界一类的问题
            EXPORT="GASPP_FIX_XCODE5=1"
        fi
    fi


    #10. 正式编译
    #tr命令可以对来自标准输入的字符进行替换、压缩和删除
    #'[:upper:]': 将小写转成大写
    #'[:lower:]': 将大写转成小写
    #将platform: 转成大写或者小写
    XCRUN_SDK=`echo $platform | tr '[:upper:]' '[:lower:]'`
    #编译器(编译平台)
    CC="xcrun -sdk $XCRUN_SDK clang"

    #架构类型->arm64
    if [ "$arch" = "arm64" ]
    then
        #音视频默认一个编译命令
        #preprocessor.pl帮助我们编译FFmpeg(生成arm64位静态库)
        AS="gas-preprocessor.pl -arch aarch64 -- $CC"
    else
        #默认编译平台
        AS="$CC"
    fi

    echo "执行到了1"

    #目录找到FFmepg编译源代码目录->设置编译配置->编译FFmpeg源码
    #--target-os:目标系统  darwin(mac系统早期的版本名字)
    #darwin:是mac系统、iOS系统祖宗
    #--arch:CPU平台架构类型
    #--cc：指定编译器类型选项
    #--as:汇编程序
    #$configure_flags最初配置
    #--extra-cflags
    #--prefix：静态库输出目录
    TMPDIR=${TMPDIR/%\/} $currentdir/$source/configure \
        --target-os=darwin \
        --arch=$arch \
        --cc="$CC" \
        --as="$AS" \
        $configure_flags \
        --extra-cflags="$archflags" \
        --extra-ldflags="$archflags" \
        --prefix="$staticdir/$arch" \
        || exit 1

    echo "执行了"

    #导出静态库(编译.a静态库)
    #执行命令
    make -j3 install $EXPORT || exit 1
    #回到脚本文件目录
    cd $currentdir
done
