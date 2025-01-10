#!/bin/bash


WORKSPACE_CURRENT=$(pwd)
FF_VERSION=4.3.2  # 默认 FFmpeg 版本号

# 检查操作系统类型
OS=$(uname)
if [ "$OS" == "Darwin"  ];
then
    echo "Is MacOS build 。。。。"
else
    echo "Unsupported operating system: $OS"
    exit 1
fi

# ========================== 目录检查与创建函数 ===========================
function ensure_directory_exists() {
    local dir_path=$1
    if [[ ! -d "${dir_path}" ]]; then
        echo "Directory '${dir_path}' does not exist. Creating it now..."
        mkdir -p "${dir_path}"
        if [[ $? -ne 0 ]]; then
            echo "Error: Failed to create directory '${dir_path}'."
            exit 1
        fi
    else
        echo "Directory '${dir_path}' already exists."
    fi
}

# 检查 FFmpeg 源代码是否存在
function check_ffmpeg_source() {
    local ffmpeg_archive="ffmpeg-${FF_VERSION}.tar.bz2"
    local ffmpeg_dir="ffmpeg-${FF_VERSION}"

    # 检查源代码文件夹是否存在
    if [[ -d "${ffmpeg_dir}" ]]; then
        echo "FFmpeg source directory '${ffmpeg_dir}' already exists. Skipping extraction."
        return
    fi

    # 检查压缩包是否存在
    if [[ -f "${ffmpeg_archive}" ]]; then
        echo "FFmpeg archive '${ffmpeg_archive}' already exists. Skipping download."
    else
        echo "Downloading FFmpeg source archive '${ffmpeg_archive}'..."
        wget https://ffmpeg.org/releases/${ffmpeg_archive}
        if [[ $? -ne 0 ]]; then
            echo "Error: Failed to download FFmpeg source archive."
            exit 1
        fi
    fi

    # 解压源代码
    echo "Extracting FFmpeg source archive '${ffmpeg_archive}'..."
    tar -xjf "${ffmpeg_archive}"
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to extract FFmpeg source archive."
        exit 1
    fi
}
build_ios_all() {
    # iOS 架构
    # IOS_ARCHS=("armv7" "arm64" "x86_64" "i386")
    IOS_ARCHS=("arm64")

    for ARCH in "${IOS_ARCHS[@]}"; do
        build_ios_arch "$ARCH"
    done
}

build_ios_arch() {
    local IOS_ARCH=$1
    local IOS_SDK="iphoneos"
    local IOS_MIN_VERSION="10.0"

    if [[ "$IOS_ARCH" == "x86_64" || "$IOS_ARCH" == "i386" ]]; then
        IOS_SDK="iphonesimulator"
    fi

    local IOS_TOOLCHAIN=$(xcrun -sdk $IOS_SDK --show-sdk-platform-path)/Developer/usr/bin
    local IOS_SYSROOT=$(xcrun -sdk $IOS_SDK --show-sdk-path)

    local PREFIX=$WORKSPACE_CURRENT/ios/$IOS_ARCH
    local CROSS_PREFIX=$IOS_TOOLCHAIN/

    X264_PATH=$WORKSPACE_CURRENT/third_party/x264/$IOS_ARCH
    FDK_AAC_PATH=$WORKSPACE_CURRENT/third_party/fdk-aac/$IOS_ARCH
    OPUS_PATH=$WORKSPACE_CURRENT/third_party/opus/$IOS_ARCH
    OPENSSL_PATH=$WORKSPACE_CURRENT/third_party/ssl/$IOS_ARCH

    ensure_directory_exists "${X264_PATH}"
    ensure_directory_exists "${FDK_AAC_PATH}"
    ensure_directory_exists "${OPUS_PATH}"
    ensure_directory_exists "${OPENSSL_PATH}"

    # Main flow

    # 输出结果
    # 查找 .a 文件
    # FOUND=$(find "$X264_PATH" -type f -name "*.a")
    # if [ -n "$FOUND" ]; then
    #     echo "$X264_PATH 已找到以下静态库文件："
    #     echo "$FOUND"
    #     echo "$X264_PATH 已经编译完成"
    # else
    #     echo "$X264_PATH 未找到任何 .a 文件，开始编译X264"
    #     build_x264 "$IOS_ARCH" "$IOS_SDK" "$IOS_SYSROOT" "$IOS_TOOLCHAIN"
    # fi

    # FOUND=$(find "$FDK_AAC_PATH" -type f -name "*.a")
    # if [ -n "$FOUND" ]; then
    #     echo "$FDK_AAC_PATH 已找到以下静态库文件："
    #     echo "$FOUND"
    #     echo "$FDK_AAC_PATH 已经编译完成"
    # else
    #     echo "$FDK_AAC_PATH 未找到任何 .a 文件，开始编译FDK_AAC"
    #     build_fdk_aac "$IOS_ARCH" "$IOS_SDK" "$IOS_SYSROOT" "$IOS_TOOLCHAIN"
    # fi

    # FOUND=$(find "$OPUS_PATH" -type f -name "*.a")
    # if [ -n "$FOUND" ]; then
    #     echo "$OPUS_PATH 已找到以下静态库文件："
    #     echo "$FOUND"
    #     echo "$OPUS_PATH 已经编译完成"
    # else
    #     echo "$OPUS_PATH 未找到任何 .a 文件，开始编译opus"
    #     build_opus "$IOS_ARCH" "$IOS_SDK" "$IOS_SYSROOT" "$IOS_TOOLCHAIN"
    # fi

    FOUND=$(find "$OPENSSL_PATH" -type f -name "*.a")
    if [ -n "$FOUND" ]; then
        echo "$OPENSSL_PATH 已找到以下静态库文件："
        echo "$FOUND"
        echo "$OPENSSL_PATH 已经编译完成"
    else
        echo "$OPENSSL_PATH 未找到任何 .a 文件，开始编译openssl"
        build_openssl "$IOS_ARCH" "$IOS_SDK" "$IOS_SYSROOT" "$IOS_TOOLCHAIN"
    fi

    # build_ffmpeg "$IOS_ARCH" "$IOS_SDK" "$IOS_SYSROOT" "$IOS_TOOLCHAIN"
}


function setting_pkg() {
    echo "pkgconfig=$(which pkgconfig)"
    echo "pkgconfig=$(whereis pkgconfig)"
    # Concatenate paths step by step
    PKG_CONFIG_PATH="$X264_PATH/lib/pkgconfig"
    PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$FDK_AAC_PATH/lib/pkgconfig"
    PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$OPUS_PATH/lib/pkgconfig"
    PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$OPENSSL_PATH/lib/pkgconfig"

    # Export the final PKG_CONFIG_PATH
    export PKG_CONFIG_PATH
    echo "PKG_CONFIG_PATH = ${PKG_CONFIG_PATH}"
}




build_ffmpeg() {
    local IOS_ARCH=$1
    local IOS_SDK=$2
    local IOS_SYSROOT=$3
    local IOS_TOOLCHAIN=$4

    check_ffmpeg_source
    setting_pkg
    cd $WORKSPACE_CURRENT/"ffmpeg-${FF_VERSION}"
    echo "Building FFmpeg for $ANDROID_ARCH..."
     local FFMPEG_CFLAGS=""
    FFMPEG_CFLAGS+=" -I$X264_PATH/include"
    FFMPEG_CFLAGS+=" -I$FDK_AAC_PATH/include"
    FFMPEG_CFLAGS+=" -I$OPUS_PATH/include"
    FFMPEG_CFLAGS+=" -I$OPENSSL_PATH/include"
    FFMPEG_CFLAGS+=" -Os -fpic -DBIONIC_IOCTL_NO_SIGNEDNESS_OVERLOAD"
    FFMPEG_CFLAGS+=" -fPIE -pie -DANDROID "

    local FFMPEG_LDFLAGS=""
    FFMPEG_LDFLAGS+=" -L$X264_PATH/lib"
    FFMPEG_LDFLAGS+=" -L$FDK_AAC_PATH/lib"
    FFMPEG_LDFLAGS+=" -L$OPUS_PATH/lib"
    FFMPEG_LDFLAGS+=" -L$OPENSSL_PATH/lib"
    FFMPEG_LDFLAGS+=" $ADDI_LDFLAGS"

    
    ./configure \
        --prefix=$(pwd)/install/${IOS_ARCH} \
        --pkg-config="pkg-config --static" \
        --disable-doc \
        --enable-neon  \
        --enable-hwaccels  \
        --enable-shared \
        --enable-static \
        --disable-x86asm \
        --disable-asm \
        --disable-symver \
        --disable-devices \
        --disable-avdevice \
        --disable-indev=v4l2 \
        --enable-gpl \
        --enable-pic \
        --enable-nonfree \
        --enable-small \
        --enable-cross-compile \
        --enable-jni \
        --enable-protocols \
        --cross-prefix=$IOS_TOOLCHAIN \
        --target-os=darwin \
        --arch="$IOS_ARCH" \
        --sysroot=$IOS_SYSROOT \
        --extra-cflags="$FFMPEG_CFLAGS" \
    	--extra-ldflags="$FFMPEG_LDFLAGS" \
        --cc=$CC \
        --cxx=$CXX \
        --enable-libx264 \
        --enable-libopus \
        --enable-openssl \
        --enable-libfdk-aac 
#                --enable-libfreetype \
#        --enable-libx265 \

   if [ $? -ne 0 ]; then
        echo "Error: Configuration failed."
        exit 1
    fi
    	
    make clean
    make -j$(nproc) || { echo "Error: Build failed"; exit 1; }
    make install || { echo "Error: Installation failed"; exit 1; }

    cd $WORKSPACE_CURRENT || { echo "Error: Failed to return to workspace"; exit 1; }
}

# Build external libraries
build_x264() {
    # local IOS_ARCH=$1
    # local IOS_SDK=$2
    # local IOS_SYSROOT=$3
    # local IOS_TOOLCHAIN=$4
    # CFLAGS="-arch $IOS_ARCH"
    # ASFLAGS=
    cd ios_deps || exit 1
    echo "Building x264 for $IOS_ARCH..."
    local x264_dir="x264"
    
    # 检查 x264 文件夹是否存在
    if [[ -d ${x264_dir} ]]; then
        echo "Directory ${x264_dir} already exists. Skipping clone."
    else
        echo "Cloning x264 repository..."
        git clone https://code.videolan.org/videolan/x264.git
        if [[ $? -ne 0 ]]; then
            echo "Error: Failed to clone x264 repository"
            exit 1
        fi
    fi

    # 进入 x264 目录
    # cd ${x264_dir}
    echo "Compiling x264 for $IOS_ARCH pwd: $(pwd)"
    ./build-x264.sh "$(pwd)/${x264_dir}" "$X264_PATH" "$IOS_ARCH"
    cd "$WORKSPACE_CURRENT" || exit
}

build_fdk_aac() {
    cd ios_deps || exit 1
    local IOS_ARCH=$1

    echo "Installing fdk-aac... FDK_AAC_PATH=${FDK_AAC_PATH}"
    local fdk_aac_version="2.0.3"
    local fdk_aac_tar="fdk-aac-${fdk_aac_version}.tar.gz"
    local fdk_aac_url="https://downloads.sourceforge.net/opencore-amr/${fdk_aac_tar}"
    local fdk_aac_dir=fdk-aac-${fdk_aac_version}
    # 检查文件是否已存在
    if [[ ! -d ${fdk_aac_dir} ]]; then
        echo "fdk-aac tarball not found. Downloading..."
        wget ${fdk_aac_url} || { echo "Error: Failed to download ${fdk_aac_tar}"; exit 1; }
        # 解压并安装
        tar zxvf ${fdk_aac_tar}
    else
        echo "fdk-aac tarball already exists. Skipping download."
    fi
    # cd fdk_aac_dir
    echo "Compiling fdk_aac for $IOS_ARCH pwd: $(pwd)"
    ./build-fdk-aac.sh "$(pwd)/${fdk_aac_dir}" "$FDK_AAC_PATH" "$IOS_ARCH"
    cd "$WORKSPACE_CURRENT" || exit 
}

build_opus() {
    cd ios_deps || exit 1
    local ARCHS=$1
    # local SDKVERSION="11.1"
    # local MINIOSVERSION="8.0"
    # local REPOROOT=$WORKSPACE_CURRENT
    # local IOS_SYSROOT=$3
    # local IOS_TOOLCHAIN=$4
    local VERSION="1.5.2"
    local opus_dir=opus-${VERSION}
    echo "Building opus for $IOS_ARCH..."

    # 下载并解压 Opus 源代码（如果未下载）
    if [ ! -d ${opus_dir} ]; then
        echo "Downloading Opus source..."
        wget https://downloads.xiph.org/releases/opus/${opus_dir}.tar.gz -O ${opus_dir}.tar.gz
        if [ $? -ne 0 ]; then
            echo "Error: Failed to download Opus source."
            exit 1
        fi
        tar -xzf ${opus_dir}.tar.gz
    fi

    # 进入 Opus 源码目录
    cd ${opus_dir} || exit
    echo "Compiling fdk_aac for $IOS_ARCH pwd: $(pwd)"
    rm -r build
    mkdir build && cd build
    cmake .. -G "Unix Makefiles" \
            -DCMAKE_INSTALL_PREFIX=$OPUS_PATH \
            -DCMAKE_SYSTEM_NAME=iOS \
            -DCMAKE_OSX_ARCHITECTURES=${ARCHS} \

    cmake --build .
    make install

    # ./build-libopus.sh
    cd $WORKSPACE_CURRENT
}

build_openssl() {
    cd ios_deps || exit 1
    # sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
    local ARCH=$1
    # local IOS_SDK=$2
    # local IOS_SYSROOT=$3
    # local IOS_TOOLCHAIN=$4

     echo "Building openssl( for $IOS_ARCH..."
    # 定义必要的变量
    OPENSSL_VERSION="1.1.1k"
    OPENSSL_TAR="openssl-${OPENSSL_VERSION}.tar.gz"
    OPENSSL_DIR="openssl-${OPENSSL_VERSION}"
    OPENSSL_URL="https://www.openssl.org/source/${OPENSSL_TAR}"

    # 检查并下载 OpenSSL 源码
    if [ ! -d "${OPENSSL_DIR}" ]; then
        if [ ! -f "${OPENSSL_TAR}" ]; then
            echo "Downloading OpenSSL source..."
            wget ${OPENSSL_URL} || { echo "Error: Failed to download ${OPENSSL_TAR}"; exit 1; }
        fi
        tar zxf ${OPENSSL_TAR} || { echo "Error: Failed to extract ${OPENSSL_TAR}"; exit 1; }
    else
        echo "OpenSSL source directory already exists. Skipping download."
    fi

    # cd ${OPENSSL_DIR} || { echo "Error: Failed to enter ${OPENSSL_DIR}"; exit 1; }
     ./do-compile-openssl.sh "$ARCH" "$(pwd)/${OPENSSL_DIR}" "${OPENSSL_PATH}"

    cd "$WORKSPACE_CURRENT" || { echo "Error: Failed to return to workspace"; exit 1; }
}

build_ios_all