#!/bin/bash
set -e  # 遇到错误立即退出

FF_VERSION=4.3.2  # 默认 FFmpeg 版本号

# ========================== 配置部分 ===========================
# 默认路径，可以通过传参覆盖这些路径
X264_PATH="/home/lym_work/ffmpeg-${FF_VERSION}/third_lib/x264"
X265_PATH="/home/lym_work/ffmpeg-${FF_VERSION}/third_lib/x265"
FDK_AAC_PATH="/home/lym_work/ffmpeg-${FF_VERSION}/third_lib/fdk-aac"
OPENSSL_PATH="/usr/local/openssl"

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
# ====================== 安装必要依赖 ============================
function install_dependencies() {
    echo "Installing required packages..."
    sudo apt-get update
    sudo apt-get install -y \
        build-essential wget git nasm cmake libtool pkg-config \
        yasm zlib1g-dev libssl-dev perl cpanminus libfreetype6-dev
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

# ====================== 安装 FreeType ===========================
function install_freetype() {
    freetype_version=2.9
    wget http://download.savannah.gnu.org/releases/freetype/freetype-${freetype_version}.tar.gz
    tar zxvf freetype-${freetype_version}.tar.gz
    cd freetype-${freetype_version}
    ./configure --prefix=/usr/local/freetype
    make -j$(nproc) && sudo make install
    cd ..
}

# ====================== 安装 x264 ===========================
function install_libx264() {
    echo "Installing x264..."
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

    echo "Configuring x264 build..."
    ./configure --prefix=$(pwd)/install --enable-static --enable-shared --disable-asm
    if [[ $? -ne 0 ]]; then
        echo "Error: x264 configuration failed"
        exit 1
    fi

    echo "Building x264..."
    make -j$(nproc)
    if [[ $? -ne 0 ]]; then
        echo "Error: x264 build failed"
        exit 1
    fi

    echo "Installing x264..."
    make install
    if [[ $? -ne 0 ]]; then
        echo "Error: x264 installation failed"
        exit 1
    fi

    # 返回上一层目录
    cd ..
    echo "x264 installation complete!"
}

# ====================== 安装 x265 ===========================
function install_libx265() {
    echo "Installing x265..."
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
    cd ${x265_dir}/source/
    mkdir -p build
    cd build

    echo "Running CMake..."
    cmake -DCMAKE_INSTALL_PREFIX=$(pwd)/install -DENABLE_SHARED=ON ..
    if [[ $? -ne 0 ]]; then
        echo "Error: CMake configuration failed"
        exit 1
    fi

    echo "Building x265..."
    make -j$(nproc)
    if [[ $? -ne 0 ]]; then
        echo "Error: x265 build failed"
        exit 1
    fi

    echo "Installing x265..."
    make install
    if [[ $? -ne 0 ]]; then
        echo "Error: x265 installation failed"
        exit 1
    fi

    # 将安装文件夹拷贝到上一级目录
    cp -r install ../
    cd ../../../
    echo "x265 installation complete!"
}

# ====================== 安装 fdk-aac ============================
function install_fdk_aac() {
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
    mkdir -p build && cd build
    cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$(pwd)/../install
    make -j$(nproc) && make install || { echo "Error: fdk-aac build failed"; exit 1; }
    
    cd ../..
    echo "fdk-aac installation complete!"
}

# ====================== 安装 OpenSSL ============================
function install_openssl() {
    echo "Installing OpenSSL..."
    local openssl_version="1.1.1k"
    local openssl_tar="openssl-${openssl_version}.tar.gz"
    local openssl_url="https://www.openssl.org/source/${openssl_tar}"
    OPENSSL_PATH="/usr/local/openssl"  # 指定安装路径，可根据需求修改

    # 检查文件是否已存在
    if [[ ! -f ${openssl_tar} ]]; then
        echo "${openssl_tar} not found. Downloading..."
        wget ${openssl_url} || { echo "Error: Failed to download ${openssl_tar}"; exit 1; }
    else
        echo "${openssl_tar} already exists. Skipping download."
    fi

    # 解压并安装
    tar zxvf ${openssl_tar}
    cd openssl-${openssl_version}
    ./config --prefix=${OPENSSL_PATH} --openssldir=${OPENSSL_PATH} || { echo "Error: Configuration failed"; exit 1; }
    make -j$(nproc) && sudo make install || { echo "Error: OpenSSL build failed"; exit 1; }

    cd ..
    echo "OpenSSL installation complete! Installed to: ${OPENSSL_PATH}"
}
 function setting_pkg() {
#	echo "pkgconfig="${	which pkgconfig}
#     echo "pkgconfig="${whereis pkgconfig}
     export PKG_CONFIG_PATH="/home/lym_work/ffmpeg/pkgconfig"
     cp /home/lym_work/fdk-aac-2.0.3/install/lib/pkgconfig/fdk-aac.pc ${PKG_CONFIG_PATH}
     cp /home/lym_work/x264/install/lib/pkgconfig/x264.pc ${PKG_CONFIG_PATH}
     cp /home/lym_work/x265_git/source/install/lib/pkgconfig/x265.pc ${PKG_CONFIG_PATH}
     cp -r /home/lym_work/fdk-aac-2.0.3/install/* ${FDK_AAC_PATH}
     cp -r  /home/lym_work/x264/install/* ${X264_PATH}
     cp -r /home/lym_work/x265_git/source/install/* ${X265_PATH}

     
}
# ====================== FFmpeg 编译配置 =========================
function build_ffmpeg() {
    echo "Building FFmpeg..."

#    # 检查源代码是否存在
#    if [[ ! -d "ffmpeg-${FF_VERSION}" ]]; then
#        wget https://ffmpeg.org/releases/ffmpeg-${FF_VERSION}.tar.bz2
#        tar -xjf ffmpeg-${FF_VERSION}.tar.bz2
#    fi

    cd ffmpeg-${FF_VERSION}
    ./configure --prefix=/usr/local \
                --enable-shared \
                --enable-ffmpeg \
                --enable-ffplay \
                --disable-optimizations \
                --disable-asm \
                --enable-libfreetype \
                --enable-libx264 \
                --enable-libx265 \
                --enable-libfdk-aac \
                --enable-openssl \
                --enable-nonfree \
                --enable-gpl \
                --enable-pthreads \
                --extra-cflags="-I${X264_PATH}/include -I${X265_PATH}/include -I${FDK_AAC_PATH}/include -I${OPENSSL_PATH}/include" \
                --extra-ldflags="-L${X264_PATH}/lib -L${X265_PATH}/lib -L${FDK_AAC_PATH}/lib -L${OPENSSL_PATH}/lib"

    make -j$(nproc)
    sudo make install
    cd ..
}

# ====================== 库路径设置 ============================
function configure_library_path() {
    echo "Configuring library paths..."
    LIB_CONFIG_FILE="/etc/ld.so.conf.d/ffmpeg.conf"
    
    # 定义要添加的路径
    paths=(
        "/usr/local/lib"
        "${X264_PATH}/lib"
        "${X265_PATH}/lib"
        "${FDK_AAC_PATH}/lib"
    )

    # 遍历路径列表，逐个检查是否已存在
    for path in "${paths[@]}"; do
        if ! grep -Fxq "${path}" "${LIB_CONFIG_FILE}" 2>/dev/null; then
            echo "Adding ${path} to ${LIB_CONFIG_FILE}..."
            echo "${path}" | sudo tee -a "${LIB_CONFIG_FILE}" > /dev/null
        else
            echo "${path} already exists in ${LIB_CONFIG_FILE}."
        fi
    done

    # 更新库缓存
    sudo ldconfig
    echo "Updated library paths:"
    cat "${LIB_CONFIG_FILE}"
}

# ====================== 主流程 ============================
# 调用函数检查并准备 FFmpeg 源代码
check_ffmpeg_source
echo "Checking and ensuring required directories exist..."

	ensure_directory_exists ${X264_PATH}
	ensure_directory_exists ${X265_PATH}
	ensure_directory_exists ${FDK_AAC_PATH}

echo "All required directories are ready."
install_dependencies
install_freetype
install_libx264
install_libx265
install_fdk_aac
install_openssl
setting_pkg
build_ffmpeg
configure_library_path

echo "FFmpeg build completed successfully!"
