#!/bin/bash
set -e
# archbit=64


export NDK_ROOT=/Users/luoyongmeng/Documents/lym/ndklib/android-ndk-r19c


# if [ $archbit -eq 64 ];then
#     echo "build for 64bit"
#     # ARCH=aarch64
#     # CPU=armv8-a
#     ARCH=arm64
#     CPU=armv8-a
#     API=24
#     PLATFORM=aarch64-linux-android
#     ANDROID=android
# else
# echo "build for 32bit"
#     # ARCH=arm
#     # CPU=armv7-a
#     ARCH=arm
#     CPU=armv7-a
#     API=24
#     PLATFORM=arm-linux-androideabi
#     ANDROID=androideabi

# fi wget https://dl.google.com/android/repository/android-ndk-r12b-linux-x86_64.zip

# CFLAGS="-I$OPENSSL/include -fPIE -pie -fPIC -mfloat-abi=softfp -march=$CPU"
# LDFLAGS="-L$OPENSSL/lib ,-Wl,--fix-cortex-a8"

# export TOOLCHAIN=$NDK/toolchains/llvm/prebuilt/darwin-x86_64/bin
# export SYSROOT=$NDK/platforms/android-$API/arch-$ARCH/
# export CROSS_PREFIX=$NDK/toolchains/$PLATFORM-4.9/prebuilt/darwin-x86_64/bin/$PLATFORM-
# # export CC=$TOOLCHAIN/$PLATFORM-linux-$ANDROID$API-clang
# # export CXX=$TOOLCHAIN/$PLATFORM-linux-$ANDROID$API-clang++
# export PREFIX=$(pwd)/android/$CPU
build() {
    API=21
    ARCH=$1
    PLATFORM=$2
    OPENSSL=$(pwd)/openssl/$ARCH
    TOOLCHAIN=$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/
    SYSROOT=$TOOLCHAIN/sysroot
    CROSS_PREFIX=$TOOLCHAIN/bin/$PLATFORM-
    CC=$TOOLCHAIN/bin/aarch64-linux-android$API-clang
    CXX=$TOOLCHAIN/bin/aarch64-linux-android$API-clang++
    PREFIX=$(pwd)/android/$CPU

    echo "开始编译ffmpeg $ARCH so"
    ./configure \
    --prefix=$PREFIX \
    --disable-doc \
    --enable-shared \
    --disable-static \
    --disable-x86asm \
    --disable-asm \
    --disable-symver \
    --disable-devices \
    --disable-avdevice \
    --enable-gpl \
    --disable-ffmpeg \
    --disable-ffplay \
    --disable-ffprobe \
    --enable-small \
    --enable-openssl \
    --enable-nonfree \
    --enable-cross-compile \
    --cross-prefix=$CROSS_PREFIX \
    --target-os=android \
    --arch=$ARCH \
    --sysroot=$SYSROOT \
    --extra-cflags="-I$OPENSSL/include -fPIE -pie" \
    --extra-ldflags="-L$OPENSSL/lib"
}

cd ffmpeg-4.3.2-android/
# build armv7a
build arm arm-linux-androideabi
make clean
make -j4
make install

echo "完成ffmpeg $ARCH 编译..."

# build armv8a
build arm64 aarch64-linux-android
make clean
make -j4
make install

echo "完成ffmpeg $ARCH 编译..."
# #这里定义变量，后续会使用
# #TOOLCHAIN 变量指向ndk中的交叉编译gcc所在的目录
# NDK_ROOT=/Applications/AndroidNDK8775105.app/Contents/NDK
# TOOLCHAIN=$NDK_ROOT/toolchains/llvm/prebuilt/darwin-x86_64/bin
# #FLAGS与INCLUDES变量 可以从AS ndk工程的.externativeBuild/cmake/debug/armeabi-v7a/build.ninja中拷贝，需要注意的是**地址**
# FLAGS="-isystem $NDK_ROOT/sysroot/usr/include/arm-linux-androideabi -D__ANDROID_API__=21 -g -DANDROID -ffunction-sections -funwind-tables -fstack-protector-strong -no-canonical-prefixes -march=armv7-a -mfloat-abi=softfp -mfpu=vfpv3-d16 -mthumb -Wa,--noexecstack -Wformat -Werror=format-security -std=c++14  -O0 -fPIC"
# INCLUDES="-isystem $NDK_ROOT/sources/cxx-stl/llvm-libc++/include -isystem $NDK_ROOT/sources/android/support/include -isystem $NDK_ROOT/sources/cxx-stl/llvm-libc++abi/include"

# #此变量用于编译完成之后的库与头文件存放在哪个目录
# PREFIX=./android/armeabi-v7a

# #执行configure脚本，用于生成makefile
# #--prefix : 安装目录
# #--enable-small : 优化大小
# #--disable-programs : 不编译ffmpeg程序(命令行工具)，我们是需要获得静态(动态)库。
# #--disable-avdevice : 关闭avdevice模块，此模块在android中无用
# #--disable-encoders : 关闭所有编码器 (播放不需要编码)
# #--disable-muxers :  关闭所有复用器(封装器)，不需要生成mp4这样的文件，所以关闭
# #--disable-filters :关闭视频滤镜
# #--enable-cross-compile : 开启交叉编译（ffmpeg比较**跨平台**,并不是所有库都有这么happy的选项 ）
# #--cross-prefix: 看右边的值应该就知道是干嘛的，gcc的前缀 xxx/xxx/xxx-gcc 则给xxx/xxx/xxx-
# #disable-shared enable-static 不写也可以，默认就是这样的。
# #--sysroot: 
# #--extra-cflags: 会传给gcc的参数
# #--arch --target-os : 不给不行，为什么给这些值，见视频
# ./configure \
# --prefix=$PREFIX \
# --enable-small \
# --disable-programs \
# --disable-avdevice \
# --disable-encoders \
# --disable-muxers \
# --disable-filters \
# --enable-cross-compile \
# --cross-prefix=$TOOLCHAIN/bin/arm-linux-androideabi- \
# --disable-shared \
# --enable-static \
# --sysroot=$NDK_ROOT/platforms/android-21/arch-arm \
# --extra-cflags="$FLAGS $INCLUDES" \
# --extra-cflags="-isysroot $NDK_ROOT/sysroot" \
# --arch=arm \
# --target-os=android 

# #上面运行脚本生成makefile之后，使用make执行脚本
# make clean
# make install
# build_android