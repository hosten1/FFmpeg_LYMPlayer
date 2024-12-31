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
    export ANDROID_NDK_HOME="${NDK_ROOT}"

elif [ "$OS" == "Linux" ]; then
    echo "Is Linux build..."
    export NDK_ROOT=/home/luoyongmeng/Documents/android-ndk-r17c
    export ANDROID_EABI_SYS=linux-x86_64
    export ANDROID_NDK_HOME="${NDK_ROOT}"

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
    HOST=arm-linux
    PLATFORM=arm-linux-androideabi
    CROSS_COMPILE="${PLATFORM}-"
    OPENSSL=$WORKSPACE_CURRENT/openssl/$ANDROID_ABI
    # SYSROOT=$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/sysroot
    # TOOLCHAIN=$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64
    TOOLCHAIN=$NDK_ROOT/toolchains/$ANDROID_EABI/prebuilt/$ANDROID_EABI_SYS
    SYSROOT=$NDK_ROOT/platforms/$ANDROID_API/$ANDROID_ARCH
    

    PREFIX=$WORKSPACE_CURRENT/android/$ANDROID_ABI
    CROSS_PREFIX=$TOOLCHAIN/bin/$CROSS_COMPILE
#    CC=$TOOLCHAIN/bin/${PLATFORM}${API}-clang
#    CXX=$TOOLCHAIN/bin/${PLATFORM}${API}-clang++
    CC=${TOOLCHAIN}/bin/${PLATFORM}-gcc 
    CXX=${TOOLCHAIN}/bin/${PLATFORM}-g++ 

    # Directories for external libraries
    X264_PATH=$WORKSPACE_CURRENT/third_party/x264/$ANDROID_ABI
    X265_PATH=$WORKSPACE_CURRENT/third_party/x265/$ANDROID_ABI
    FDK_AAC_PATH=$WORKSPACE_CURRENT/third_party/fdk-aac/$ANDROID_ABI
    FREETYPE_PATH=$WORKSPACE_CURRENT/third_party/freetype/$ANDROID_ABI
    OPUS_PATH=$WORKSPACE_CURRENT/third_party/opus/$ANDROID_ABI
    OPENSSL_PATH=$WORKSPACE_CURRENT/third_party/ssl/$ANDROID_ABI

     SSL_ANDROID_PLATFROM=android-arm
    	# GitLqr：高版本 NDK 不再包含 gcc, 因此需要将 NDK 内置的 clang 加到入 PATH 环境变量中
	export PATH=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$ANDROID_EABI_SYS/bin:$PATH
	# GitLqr：编译 arm64 架构需要用到脚本
#	export PATH=${TOOLCHAIN}/bin:$PATH

    ensure_directory_exists "${X264_PATH}"
    ensure_directory_exists "${X265_PATH}"
    ensure_directory_exists "${FDK_AAC_PATH}"
    ensure_directory_exists "${OPUS_PATH}"
    ensure_directory_exists "${OPENSSL_PATH}"
    
    sudo chmod -R 777 ${X264_PATH}/
    sudo chmod -R 777 ${FDK_AAC_PATH}/
    sudo chmod -R 777 ${FDK_AAC_PATH}/
    sudo chmod -R 777 ${OPUS_PATH}/
    sudo chmod -R 777 ${OPENSSL_PATH}/

    # Main flow

	# 输出结果
	# 查找 .a 文件
	FOUND=$(find "$X264_PATH" -type f -name "*.a")
	if [ -n "$FOUND" ]; then
	    echo "$X264_PATH 已找到以下静态库文件："
	    echo "$FOUND"
	    echo "$X264_PATH 已经编译完成"
	else
	    echo "$X264_PATH 未找到任何 .a 文件，开始编译X264"
    	    build_x264
	fi
#     build_x265
	FOUND=$(find "$FDK_AAC_PATH" -type f -name "*.a")
	if [ -n "$FOUND" ]; then
	    echo "$FDK_AAC_PATH已找到以下静态库文件："
	    echo "$FOUND"
	    echo "$FDK_AAC_PATH 已经编译完成"
	else
	    echo "$FDK_AAC_PATH 未找到任何 .a 文件，开始编译X264"
    	    build_fdk_aac
	fi

#    build_freetype
	FOUND=$(find "$OPUS_PATH" -type f -name "*.a")
	if [ -n "$FOUND" ]; then
	    echo "$FDK_AAC_PATH 已找到以下静态库文件："
	    echo "$FOUND"
	    echo "$FDK_AAC_PATH 已经编译完成"
	else
	    echo "$FDK_AAC_PATH 未找到任何 .a 文件，开始编译X264"
    	    build_opus
	fi
	FOUND=$(find "$OPENSSL_PATH" -type f -name "*.a")
	if [ -n "$FOUND" ]; then
	    echo "$OPENSSL_PATH 已找到以下静态库文件："
	    echo "$FOUND"
	    echo "$OPENSSL_PATH 已经编译完成"
	else
	    echo "$OPENSSL_PATH 未找到任何 .a 文件，开始编译X264"
    	    build_openssl
	fi
    
    # build_ffmpeg
}
build_arm64_all(){
   # arm64-v8a

    ANDROID_ABI=arm64-v8a
    ANDROID_API=android-${API}
    ANDROID_ARCH=arch-arm64
    ANDROID_EABI=aarch64-linux-android-4.9

    HOST=aarch64-linux
    PLATFORM=aarch64-linux-android
    CROSS_COMPILE="${PLATFORM}-"
    OPENSSL=$WORKSPACE_CURRENT/openssl/$ANDROID_ABI
    # SYSROOT=$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/sysroot
    # TOOLCHAIN=$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64
    SYSROOT=$NDK_ROOT/platforms/$ANDROID_API/$ANDROID_ARCH
    TOOLCHAIN=$NDK_ROOT/toolchains/$ANDROID_EABI/prebuilt/$ANDROID_EABI_SYS
    PREFIX=$WORKSPACE_CURRENT/android/$ANDROID_ABI
    CROSS_PREFIX=$TOOLCHAIN/bin/$CROSS_COMPILE
#    CC=$TOOLCHAIN/bin/${PLATFORM}${API}-clang
#    CXX=$TOOLCHAIN/bin/${PLATFORM}${API}-clang++
    CC=${TOOLCHAIN}/bin/${PLATFORM}-gcc 
    CXX=${TOOLCHAIN}/bin/${PLATFORM}-g++ 

    # Directories for external libraries
    X264_PATH=$WORKSPACE_CURRENT/third_party/x264/$ANDROID_ABI
    X265_PATH=$WORKSPACE_CURRENT/third_party/x265/$ANDROID_ABI
    FDK_AAC_PATH=$WORKSPACE_CURRENT/third_party/fdk-aac/$ANDROID_ABI
    FREETYPE_PATH=$WORKSPACE_CURRENT/third_party/freetype/$ANDROID_ABI
    OPUS_PATH=$WORKSPACE_CURRENT/third_party/opus/$ANDROID_ABI
    OPENSSL_PATH=$WORKSPACE_CURRENT/third_party/ssl/$ANDROID_ABI

     SSL_ANDROID_PLATFROM=android-arm64
    	# GitLqr：高版本 NDK 不再包含 gcc, 因此需要将 NDK 内置的 clang 加到入 PATH 环境变量中
	export PATH=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$ANDROID_EABI_SYS/bin:$PATH
	# GitLqr：编译 arm64 架构需要用到脚本
#	export PATH=${TOOLCHAIN}/bin:$PATH

    ensure_directory_exists "${X264_PATH}"
    ensure_directory_exists "${X265_PATH}"
    ensure_directory_exists "${FDK_AAC_PATH}"
    ensure_directory_exists "${OPUS_PATH}"
    ensure_directory_exists "${OPENSSL_PATH}"

    sudo chmod -R 777 ${X264_PATH}/
    sudo chmod -R 777 ${FDK_AAC_PATH}/
    sudo chmod -R 777 ${FDK_AAC_PATH}/
    sudo chmod -R 777 ${OPUS_PATH}/
    sudo chmod -R 777 ${OPENSSL_PATH}/
    
	# Main flow

	# 输出结果
	# 查找 .a 文件
	FOUND=$(find "$X264_PATH" -type f -name "*.a")
	if [ -n "$FOUND" ]; then
	    echo "$X264_PATH 已找到以下静态库文件："
	    echo "$FOUND"
	    echo "$X264_PATH 已经编译完成"
	else
	    echo "$X264_PATH 未找到任何 .a 文件，开始编译X264"
    	    build_x264
	fi
#     build_x265
	FOUND=$(find "$FDK_AAC_PATH" -type f -name "*.a")
	if [ -n "$FOUND" ]; then
	    echo "$FDK_AAC_PATH已找到以下静态库文件："
	    echo "$FOUND"
	    echo "$FDK_AAC_PATH 已经编译完成"
	else
	    echo "$FDK_AAC_PATH 未找到任何 .a 文件，开始编译X264"
    	    build_fdk_aac
	fi

#    build_freetype
	FOUND=$(find "$OPUS_PATH" -type f -name "*.a")
	if [ -n "$FOUND" ]; then
	    echo "$FDK_AAC_PATH 已找到以下静态库文件："
	    echo "$FOUND"
	    echo "$FDK_AAC_PATH 已经编译完成"
	else
	    echo "$FDK_AAC_PATH 未找到任何 .a 文件，开始编译X264"
    	    build_opus
	fi
	FOUND=$(find "$OPENSSL_PATH" -type f -name "*.a")
	if [ -n "$FOUND" ]; then
	    echo "$OPENSSL_PATH 已找到以下静态库文件："
	    echo "$FOUND"
	    echo "$OPENSSL_PATH 已经编译完成"
	else
	    echo "$OPENSSL_PATH 未找到任何 .a 文件，开始编译X264"
    	    build_openssl
	fi
    
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
# 在脚本中开启错误退出模式
    set -e
    echo "Building x264 for $ANDROID_ARCH..."
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
    cd ${x264_dir}
    echo "Compiling x264 for currnt_path = $(pwd)  $ANDROID_ABI "
    echo "Installing x264 to: $X264_PATH"
#    HOST: arm-linux-androideabi 
#CROSS_PREFIX /home/luoyongmeng/Documents/android-ndk-r17c/toolchains/arm-linux-androideabi-4.9/prebuilt/linux-x86_64/bin/arm-linux-androideabi- 
#SYSROOT /home/luoyongmeng/Documents/android-ndk-r17c/platforms/android-24/arch-arm 
    echo "HOST: ${HOST} "
    echo "CROSS_PREFIX ${CROSS_PREFIX} "
    echo "SYSROOT ${SYSROOT} "
#    PREFIX=$(pwd)/android/$ANDROID_ABI
    ./configure \
        --prefix=${X264_PATH} \
        --host=${HOST} \
        --disable-asm \
        --enable-static \
        --enable-pic \
        --cross-prefix=${CROSS_PREFIX} \
        --sysroot=${SYSROOT}
        
    make clean    
    make -j$(nproc)
    make install
    cd $WORKSPACE_CURRENT
    # 关闭错误退出模式（可选）
    set +e
}

build_x265() {
    echo "Building x265 for $ANDROID_ARCH..."
#    CC=$TOOLCHAIN/bin/${PLATFORM}${API}-clang
#    CXX=$TOOLCHAIN/bin/${PLATFORM}${API}-clang++
    local x265_dir="x265_git"

    # 检查 x265_git 文件夹是否存在
    if [[ -d ${x265_dir} ]]; then
        echo "Directory ${x265_dir} already exists. Skipping clone."
    else
        echo "Cloning x265 repository..."
        git clone https://bitbucket.org/multicoreware/x265_git.git
#		git clone https://github.com/kimsan0622/libx265-android.git
        if [[ $? -ne 0 ]]; then
            echo "Error: Failed to clone x265 repository"
            exit 1
        fi
    fi
    cd ${x265_dir}
    
#    export ANDROID_API_VERSION=$API # chose android platform version. I recommend a version higher than 21.
#    export NUMBER_OF_CORES=4 # set the number of cores which you want to use for compile. it depends on CPU of your host computer.
#    export OUTPUT_PREFIX=$X265_PATH # set the output prefix. default directory is ./build
#
#    # 进入 source 目录并开始编译

#    mkdir x265/build/android
#    cp -rf build_script/* x265/build/android
#	
#	
#	
#	
#	pushd x265/build/android/${$ANDROID_ABI} 
#
#	cmake ../../../source \
#	  -DCMAKE_SYSTEM_NAME=Android \
#	  -DCMAKE_SYSTEM_VERSION=${ANDROID_API_VERSION} \
#	  -DCMAKE_ANDROID_ARCH_ABI=${$ANDROID_ABI} \
#	  -DCMAKE_ANDROID_NDK=${NDK_ROOT} \
#	  -DCMAKE_ANDROID_STL_TYPE=gnustl_static \
#	  -DENABLE_SHARED=0 \ # add this line.
#	  -DNEON_ANDROID=1
#	
#	sed -i '' 's/-lpthread/-pthread/' CMakeFiles/cli.dir/link.txt
#	sed -i '' 's/-lpthread/-pthread/' CMakeFiles/x265-shared.dir/link.txt
#	sed -i '' 's/-lpthread/-pthread/' CMakeFiles/x265-static.dir/link.txt
#	
#	make -j${NUMBER_OF_CORES}
#	make DESTDIR=${OUTPUT_PREFIX}/${$ANDROID_ABI} install
	

    cd source/
    mkdir build 
    cd build
    make clean
    rm -rf CMakeCache.txt CMakeFiles
    echo "Configuring build with CMake...  $(pwd)/install NDK_ROOT：${NDK_ROOT} $ANDROID_ABI  CXX：${CXX}"
    cmake -DCMAKE_INSTALL_PREFIX=$X265_PATH \
          -DCMAKE_TOOLCHAIN_FILE=${NDK_ROOT}/build/cmake/android.toolchain.cmake \
          -G "Unix Makefiles" \
          -DANDROID_PLATFORM=android-$API \
          -DCMAKE_SYSTEM_VERSION=${API} \
          -DCMAKE_SYSTEM_VERSION=${ANDROID_ABI} \
          -DCMAKE_ANDROID_NDK=${NDK_ROOT} \
          -DANDROID_ABI=$ANDROID_ABI \
          -DCMAKE_SYSTEM_NAME=Android \
          -DENABLE_STATIC=ON \
          -DENABLE_SHARED=OFF \
          -DENABLE_ASSEMBLY=OFF \
          -DNEON_ANDROID=1 \
          ..
#                    -DCMAKE_C_COMPILER=${CC} \
#          -DCMAKE_CXX_COMPILER=${CXX} \

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
    ./configure --prefix=${FDK_AAC_PATH} --host=$HOST --enable-static --enable-pic --disable-shared
    make -j$(nproc)
    make install
    cd $WORKSPACE_CURRENT
}

build_freetype() {
    echo "Building freetype for $ANDROID_ARCH..."
     local freetype_dir="freetype-2.9"
    # 检查 freetype 文件夹是否存在
    if [[ -d ${freetype_dir} ]]; then
        echo "Directory ${freetype_dir} already exists. Skipping clone."
    else
        echo "Cloning x264 repository..."
        wget -c https://download.savannah.gnu.org/releases/freetype/freetype-${freetype_dir}.tar.gz

        if [[ $? -ne 0 ]]; then
            echo "Error: Failed to clone x264 repository"
            exit 1
        fi
        tar zxvf ${freetype_dir}.tar.gz
    fi

    # 进入 freetype 目录
    cd ${freetype_dir}
    
    ./configure --prefix=$(pwd)/install --host=$HOST --enable-static --disable-shared
    make -j$(nproc)
    make install
    cd $WORKSPACE_CURRENT
}

build_opus() {
    echo "Building opus for $ANDROID_ARCH..."

   # 定义工具链路径
    Android_Toolchain=${WORKSPACE_CURRENT}/android_toolchain

    # 检查工具链是否存在
    if [ ! -d "$Android_Toolchain" ]; then
        echo "Android toolchain not found. Creating toolchain..."
        sudo sh ${NDK_ROOT}/build/tools/make-standalone-toolchain.sh \
            --platform=android-${API} \
            --install-dir=${Android_Toolchain}
        if [ $? -ne 0 ]; then
            echo "Error: Failed to create Android toolchain."
            exit 1
        fi
    else
        echo "Android toolchain already exists. Skipping creation."
    fi

    # 下载并解压 Opus 源代码（如果未下载）
    if [ ! -d "opus-1.5.2" ]; then
        echo "Downloading Opus source..."
        wget https://downloads.xiph.org/releases/opus/opus-1.5.2.tar.gz -O opus-1.5.2.tar.gz
        if [ $? -ne 0 ]; then
            echo "Error: Failed to download Opus source."
            exit 1
        fi
        tar -xzf opus-1.5.2.tar.gz
    fi

    # 进入 Opus 源码目录
    cd opus-1.5.2 || exit

    # 设置环境变量
    export PATH=${Android_Toolchain}/bin:$PATH
    export CC=arm-linux-androideabi-gcc
    export CXX=arm-linux-androideabi-g++

    # 配置并编译 Opus
    ./configure --prefix=${OPUS_PATH} \
                --host=${HOST} \
                --enable-fixed-point \
                --disable-float-api \
                CFLAGS="-O3 -mfpu=neon -mfloat-abi=softfp" \
                HAVE_ARM_NEON_INTR=1

    if [ $? -ne 0 ]; then
        echo "Error: Configuration failed."
        exit 1
    fi
    make clean

    make -j$(nproc)
    if [ $? -ne 0 ]; then
        echo "Error: Build failed."
        exit 1
    fi

    make install
    if [ $? -ne 0 ]; then
        echo "Error: Installation failed."
        exit 1
    fi

    echo "Opus build and installation completed successfully."
    cd $WORKSPACE_CURRENT
    
#    wget https://downloads.xiph.org/releases/opus/opus-1.5.2.tar.gz
#    git clone --depth 1 https://github.com/xiph/opus.git opus-src
#    cd opus-1.5.2
#    Android_Toolchain=${WORKSPACE_CURRENT}/android_toolchain
#    sudo sh ${NDK_ROOT}/build/tools/make-standalone-toolchain.sh \
#        --platform=android-${API} --install-dir=${Android_Toolchain}
#
#    #!/bin/sh
# 
#	export PATH=${Android_Toolchain}/bin:$PATH
#	export CC=arm-linux-androideabi-gcc
#	export CXX=arm-linux-androideabi-g++
#	 
#	./configure --prefix=${OPUS_PATH} \
#			  --host=${HOST} \
#			  --enable-fixed-point \
#			  --disable-float-api \
#			 CFLAGS="-O3 -mfpu=neon -mfloat-abi=softfp" \
#			 HAVE_ARM_NEON_INTR=1
##    
##    ./configure --prefix=$(pwd)/install --host=$HOST --enable-static --disable-shared
#    make -j$(nproc)
#    make install
#    cd $WORKSPACE_CURRENT
}
build_openssl() {
    echo "Installing openssl..."
    # 定义必要的变量
    OPENSSL_VERSION="1.1.1k"
    OPENSSL_TAR="openssl-${OPENSSL_VERSION}.tar.gz"
    OPENSSL_DIR="openssl-${OPENSSL_VERSION}"
    OPENSSL_URL="https://www.openssl.org/source/${OPENSSL_TAR}"
   CC=$TOOLCHAIN/bin/${PLATFORM}${API}-clang
   CXX=$TOOLCHAIN/bin/${PLATFORM}${API}-clang++

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

    cd ${OPENSSL_DIR} || { echo "Error: Failed to enter ${OPENSSL_DIR}"; exit 1; }

#CROSS_PREFIX
    # 配置和编译
    ./Configure ${SSL_ANDROID_PLATFROM} \
    				no-shared \
    				no-ssl2 \
    				no-ssl3 \
    				no-comp \
    				no-asm \
    				no-engine \
    				no-unit-test \
    				--prefix=${OPENSSL_PATH} \
    				--cross-compile-prefix=${CROSS_PREFIX} \
    				-D__ANDROID_API__=${API} || { echo "Error: Configuration failed"; exit 1; }
    if [ $? -ne 0 ]; then
        echo "Error: Configuration failed."
        exit 1
    fi
    	
    make clean
    make -j$(nproc) || { echo "Error: Build failed"; exit 1; }
    make install || { echo "Error: Installation failed"; exit 1; }

    cd $WORKSPACE_CURRENT || { echo "Error: Failed to return to workspace"; exit 1; }
}
	
build_armv7_all
#build_arm64_all