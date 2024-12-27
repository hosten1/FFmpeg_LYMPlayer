#!/bin/bash

# fseeko64直到 android-24 才可用。您必须提高您的minSdkVersion或停止使用
# 所以这里推荐最低24 否则编译h265 会出错 android use of undeclared identifier 'fseeko'; did you mean 'fseek'
API=24
WORKSPACE_CURRENT=$(pwd)
FF_VERSION=4.3.2  # 默认 FFmpeg 版本号
# PLATFORM=$2
# 检查操作系统类型
OS=$(uname)
if [ "$OS" == "Darwin"  ];
then
    echo "Is MacOS build 。。。。"
    export NDK_ROOT=/Users/luoyongmeng/Documents/lym/ndklib/android-ndk-r17c

    export ANDROID_EABI_SYS=darwin-x86_64
elif [ "$OS" == "Linux" ]; then
    echo "Is Linux build..."
    export NDK_ROOT=/path/to/your/linux/ndk
    export ANDROID_EABI_SYS=linux-x86_64
else
    echo "Unsupported operating system: $OS"
    exit 1
fi

# ========================== 目录检查与创建函数 ===========================
function ensure_directory_exists() {
    local dir_path=$1
    if [[ ! -d "${dir_path}" ]]; then
        echo "Directory '${dir_path}' does not exist. Creating it now..."
        sudo mkdir -p "${dir_path}"
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
build_armv7_all(){
    # armeabi-v7a
    ANDROID_ABI=armeabi-v7a
    ANDROID_API=android-$API
    ANDROID_ARCH=arch-arm
    ANDROID_EABI=arm-linux-androideabi-4.9

    # HOST=arm-linux-androideabi
    # CROSS_COMPILE=arm-linux-androideabi-
    HOST=arm-linux-androideabi
    CROSS_COMPILE=$HOST-
    OPENSSL=$WORKSPACE_CURRENT/openssl/$ANDROID_ABI
    # SYSROOT=$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/sysroot
    # TOOLCHAIN=$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64
    TOOLCHAIN=$NDK_ROOT/toolchains/$ANDROID_EABI/prebuilt/$ANDROID_EABI_SYS
    SYSROOT=$NDK_ROOT/platforms/$ANDROID_API/$ANDROID_ARCH

    PREFIX=$WORKSPACE_CURRENT/android/$ANDROID_ABI
    CROSS_PREFIX=$TOOLCHAIN/bin/$CROSS_COMPILE
    CC=$TOOLCHAIN/bin/$HOST$API-clang
    CXX=$TOOLCHAIN/bin/$HOST$API-clang++
    # CC=${TOOLCHAIN}/${HOST}-gcc 
    # CXX=${TOOLCHAIN}/${HOST}-g++ 

    # Directories for external libraries
    X264_PATH=$WORKSPACE_CURRENT/third_party/x264/$ANDROID_ABI
    X265_PATH=$WORKSPACE_CURRENT/third_party/x265/$ANDROID_ABI
    FDK_AAC_PATH=$WORKSPACE_CURRENT/third_party/fdk-aac/$ANDROID_ABI
    FREETYPE_PATH=$WORKSPACE_CURRENT/third_party/freetype/$ANDROID_ABI
    OPUS_PATH=$WORKSPACE_CURRENT/third_party/opus/$ANDROID_ABI
    
    ensure_directory_exists ${X264_PATH}
    ensure_directory_exists ${X265_PATH}
    ensure_directory_exists ${FDK_AAC_PATH}
    ensure_directory_exists ${OPUS_PATH}

    # Main flow
    # build_x264
    build_x265
    # build_fdk_aac
    # build_freetype
    # build_opus
    # build_ffmpeg
}
build_arm64_all(){
   # arm64-v8a
    ANDROID_ABI=arm64-v8a
    ANDROID_API=android-$API
    ANDROID_ARCH=arch-arm64
    ANDROID_EABI=aarch64-linux-android-4.9

    HOST=aarch64-linux-android
    CROSS_COMPILE=$HOST-
    OPENSSL=$WORKSPACE_CURRENT/openssl/$ANDROID_ABI
    # SYSROOT=$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/sysroot
    # TOOLCHAIN=$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64
    SYSROOT=$NDK_ROOT/platforms/$ANDROID_API/$ANDROID_ARCH
    TOOLCHAIN=$NDK_ROOT/toolchains/$ANDROID_EABI/prebuilt/$ANDROID_EABI_SYS/bin
    PREFIX=$WORKSPACE_CURRENT/android/$ANDROID_ABI
    CROSS_PREFIX=$TOOLCHAIN/$CROSS_COMPILE
    CC=$TOOLCHAIN/bin/$HOST$API-clang
    CXX=$TOOLCHAIN/bin/$HOST$API-clang++
    # CC=${TOOLCHAIN}/${HOST}-gcc 
    # CXX=${TOOLCHAIN}/${HOST}-g++ 

    # Directories for external libraries
    X264_PATH=$WORKSPACE_CURRENT/third_party/x264/$ANDROID_ABI
    X265_PATH=$WORKSPACE_CURRENT/third_party/x265/$ANDROID_ABI
    FDK_AAC_PATH=$WORKSPACE_CURRENT/third_party/fdk-aac/$ANDROID_ABI
    FREETYPE_PATH=$WORKSPACE_CURRENT/third_party/freetype/$ANDROID_ABI
    OPUS_PATH=$WORKSPACE_CURRENT/third_party/opus/$ANDROID_ABI

    ensure_directory_exists ${X264_PATH}
    ensure_directory_exists ${X265_PATH}
    ensure_directory_exists ${FDK_AAC_PATH}
    ensure_directory_exists ${OPUS_PATH}
    # Main flow
    # build_x264
    build_x265
    # build_fdk_aac
    # build_freetype
    # build_opus
    # build_ffmpeg
}






build_ffmpeg() {
    cd $WORKSPACE_CURRENT/"ffmpeg-${FF_VERSION}"
    echo "Building FFmpeg for $ANDROID_ARCH..."
    ./configure \
        --prefix=$PREFIX \
        --disable-doc \
        --enable-neon  \
        --enable-hwaccels  \
        --enable-shared \
        --disable-static \
        --disable-x86asm \
        --disable-asm \
        -disable-postproc \
        --disable-symver \
        --disable-devices \
        --disable-avdevice \
        --disable-indev=v4l2
        --enable-gpl \
        --enable-nonfree \
        --enable-small \
        --enable-cross-compile \
        -–enable-jni \
        --enable-protocols \
        --cross-prefix=$CROSS_PREFIX \
        --target-os=android \
        --arch=$ANDROID_ARCH \
        --sysroot=$SYSROOT \
        --extra-cflags="-I$X264_PATH/include -I$X265_PATH/include -I$FDK_AAC_PATH/include -I$FREETYPE_PATH/include -I$OPUS_PATH/include -I$OPENSSL/include -Os -fpic -DBIONIC_IOCTL_NO_SIGNEDNESS_OVERLOAD -fPIE -pie -DANDROID -mfpu=neon -mfloat-abi=softfp" \
        --extra-ldflags="-L$X264_PATH/lib -L$X265_PATH/lib -L$FDK_AAC_PATH/lib -L$FREETYPE_PATH/lib -L$OPUS_PATH/lib -L$OPENSSL/lib $ADDI_LDFLAGS" \
        --enable-libx264 \
        --enable-libx265 \
        --enable-libfdk-aac \
        --enable-libopus \
        --enable-libfreetype \
        --enable-openssl

    make clean
    make -j$(nproc)
    make install
    echo "FFmpeg build for $ANDROID_ARCH completed!"
}

# Build external libraries
build_x264() {
    echo "Building x264 for $ANDROID_ARCH..."
    local x264_dir="x264-src"

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
    cd ${x264_dir}
    echo "Compiling x264 for $ANDROID_ABI "
    echo "Installing x264 to: $X264_PATH"
    ./configure \
        --prefix=$X264_PATH \
        --host=$HOST \
        --disable-asm \
        --enable-static \
        --enable-pic \
        --enalbe-neon \
        --extra-cflags="-fPIE -pie" \
        --extra-ldflags="-fPIE -pie" \
        --cross-prefix=$CROSS_PREFIX \
        --sysroot=$SYSROOT
    make clean    
    make -j$(nproc)
    make install
    cd $WORKSPACE_CURRENT
}

build_x265() {
    echo "Building x265 for $ANDROID_ARCH..."
     local x265_dir="x265_git"

    # 检查 x265_git 文件夹是否存在
    if [[ -d ${x265_dir} ]]; then
        echo "Directory ${x265_dir} already exists. Skipping clone."
    else
        echo "Cloning x265 repository..."
        git clone https://bitbucket.org/multicoreware/x265_git.git
        if [[ $? -ne 0 ]]; then
            echo "Error: Failed to clone x265 repository"
            exit 1
        fi
    fi
    
    # 进入 source 目录并开始编译
    cd ${x265_dir}
    git checkout origin/Release_4.0
    # cd build/arm-linux/
    # cmake -DCMAKE_TOOLCHAIN_FILE=crosscompile.cmake \
    #     -G "Unix Makefiles" ../../source && ccmake ../../source

    cd source/
    mkdir build 
    cd build
    make clean
    rm -rf CMakeCache.txt CMakeFiles
    echo "Configuring build with CMake...  $(pwd)/install NDK_ROOT：${NDK_ROOT} $ANDROID_ABI"
    cmake -DCMAKE_INSTALL_PREFIX=$X265_PATH \
          -DCMAKE_TOOLCHAIN_FILE=${NDK_ROOT}/build/cmake/android.toolchain.cmake \
          -G "Unix Makefiles" \
          -DANDROID_PLATFORM=android-$API \
          -DANDROID_ABI=$ANDROID_ABI \
          -DCMAKE_SYSTEM_NAME=Android \
          -DENABLE_STATIC=ON \
          -DENABLE_SHARED=OFF \
          -DENABLE_ASSEMBLY=OFF \
          -DCMAKE_C_COMPILER=${CC} \
          -DCMAKE_CXX_COMPILER=${CXX} \
          ..
    # cmake -DCMAKE_TOOLCHAIN_FILE=/Users/luoyongmeng/Documents/lym/ndklib/android-ndk-r17c/build/cmake/android.toolchain.cmake \
    #       -G "Unix Makefiles" \
    #       -DCMAKE_MAKE_PROGRAM=$(which make) \
    #       -DANDROID_PLATFORM=android-$API \
    #       -DANDROID_ABI=$ANDROID_ABI \
    #       -DCMAKE_BUILD_TYPE=Release \
    #       -DENABLE_SHARED=OFF \
    #       -DENABLE_STATIC=ON \
    #       -CMAKE_ANDROID_STL_TYPE=c++_static \
    #       -DCMAKE_INSTALL_PREFIX=$(pwd)/install \
    #       -DCMAKE_C_COMPILER=/Users/luoyongmeng/Documents/lym/ndklib/android-ndk-r17c/toolchains/arm-linux-androideabi-4.9/prebuilt/darwin-x86_64/bin/arm-linux-androideabi-gcc \
    #       -DCMAKE_CXX_COMPILER=/Users/luoyongmeng/Documents/lym/ndklib/android-ndk-r17c/toolchains/arm-linux-androideabi-4.9/prebuilt/darwin-x86_64/bin/arm-linux-androideabi-g++ \
    #       ..

    make -j$(nproc)
    sudo make install
    cd $WORKSPACE_CURRENT
}

build_fdk_aac() {
     echo "Installing fdk-aac..."
    local fdk_aac_version="2.0.3"
    local fdk_aac_tar="fdk-aac-${fdk_aac_version}.tar.gz"
    local fdk_aac_url="https://downloads.sourceforge.net/opencore-amr/${fdk_aac_tar}"

    # 检查文件是否已存在
    if [[ ! -f ${fdk_aac_tar} ]]; then
        echo "fdk-aac tarball not found. Downloading..."
        wget ${fdk_aac_url} || { echo "Error: Failed to download ${fdk_aac_tar}"; exit 1; }
    else
        echo "fdk-aac tarball already exists. Skipping download."
    fi

    # 解压并安装
    tar zxvf ${fdk_aac_tar}
    cd fdk-aac-${fdk_aac_version}
    # mkdir -p build && cd build
    ./configure --prefix=$(pwd)/install --host=$HOST --enable-static --enable-pic --disable-shared
    make -j$(nproc)
    make install
    cd $WORKSPACE_CURRENT
}

build_freetype() {
    echo "Building freetype for $ANDROID_ARCH..."
    wget -c https://download.savannah.gnu.org/releases/freetype/freetype-2.12.1.tar.gz
    tar zxvf freetype-2.12.1.tar.gz
    cd freetype-2.12.1
    ./configure --prefix=$(pwd)/install --host=$HOST --enable-static --disable-shared
    make -j$(nproc)
    make install
    cd $WORKSPACE_CURRENT
}

build_opus() {
    echo "Building opus for $ANDROID_ARCH..."
    git clone --depth 1 https://github.com/xiph/opus.git opus-src
    cd opus-src
    ./configure --prefix=$(pwd)/install --host=$HOST --enable-static --disable-shared
    make -j$(nproc)
    make install
    cd $WORKSPACE_CURRENT
}
	
build_armv7_all
build_arm64_all