#!/bin/bash
set -e

FF_VERSION=4.3.2  # 默认 FFmpeg 版本号
# archbit=64


 # ========================== 配置部分 ===========================
 # 默认路径，可以通过传参覆盖这些路径
 X264_PATH="/home/lym_work/ffmpeg-${FF_VERSION}/third_lib/x264/"
 X265_PATH="/home/lym_work/ffmpeg-${FF_VERSION}/third_lib/x265/"
 FDK_AAC_PATH="/home/lym_work/ffmpeg-${FF_VERSION}/third_lib/fdk-aac/"



 function install_freetype () {
    freetype_version=2.9
    wget http://download.savannah.gnu.org/releases/freetype/freetype-${freetype_version}.tar.gz
    tar zxvf freetype-${freetype_version}.tar.gz
    ccdf freetype-${freetype_version}
    ./configure --prefix=/usr/local/freetype 
    make -j && make install
 }

 function install_libx264 () {
     apt install nasm
     apt install binutils-gold
     git clone https://code.videolan.org/videolan/x264.git
     cd x264
     ./configure --prefix=$(pwd)/install --enable-static --enable-shared --disable-asm
     make
     make install
 }
 function install_libx265 () {
     git clone https://bitbucket.org/multicoreware/x265_git.git
     cd x265_git/source/
     make && make install
 }
 function install_fdk_aac () {
     wget https://downloads.sourceforge.net/opencore-amr/fdk-aac-2.0.3.tar.gz
     tar zxvf  fdk-aac-2.0.3.tar.gz
     cd fdk-aac-2.0.3
     mkdir build && cd build
     cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$(pwd)/../install
     make -j$(nproc)
	make install
#     git clone https://github.com/mstorsjo/fdk-aac.git
#     cd fdk-aac/
#     # 如果不安装libtool等下执行autoreconf -fiv命令时可能会报错
#     apt install libtool
#     autoreconf -fiv
#     mkdir install && cd install
     
 }

 function setting_pkg() {
	echo "pkgconfig="${	which pkgconfig}
     echo "pkgconfig="${whereis pkgconfig}
     export PKG_CONFIG_PATH="/home/ffmpeg/pkgconfig"
     cp /home/lym_work/fdk-aac-2.0.3/install/lib/pkgconfig/fdk-aac.pc /home/ffmpeg/pkgconfig
     cp /home/lym_work/x264/install/lib/pkgconfig/x264.pc /home/ffmpeg/pkgconfig
     cp /home/lym_work/x265_git/source/install/lib/pkgconfig/x265.pc /home/ffmpeg/pkgconfig
     cp -r /home/lym_work/fdk-aac-2.0.3/install/* ${FDK_AAC_PATH}
     cp -r  /home/lym_work/x264/install/* ${X264_PATH}
     cp -r /home/lym_work/x265_git/source/install/* ${X265_PATH}

     
}
 # ========================= 配置编译 ============================
 echo "Configuring FFmpeg build..."
 cd ffmpeg-${FF_VERSION}
 #             --enable-debug \
 ./configure --enable-shared \
             --prefix=/usr/local \
             --enable-ffmpeg \
             --enable-ffplay \
             --disable-optimizations \
             --disable-asm \
             --enable-libfreetype \
             --enable-stripping \
             --enable-libx264 \
             --enable-libx265 \
             --enable-gpl \
             --enable-pthreads \
             --enable-libfdk-aac \
             --enable-nonfree \
             --extra-cflags="-I${X264_PATH}/include -I${X265_PATH}/include -I${FDK_AAC_PATH}/include" \
             --extra-ldflags="-L${X264_PATH}/lib -L${X265_PATH}/lib -L${FDK_AAC_PATH}/lib" || {
   echo "Error: Configuration failed."
   exit 1
 }

 # ========================== 编译与安装 =========================
 echo "Building FFmpeg..."
 make -j$(nproc) 

 echo "Installing FFmpeg..."
 make install 
#将库路径添加到 LD_LIBRARY_PATH   export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
#永久添加到系统库路径 echo "/usr/local/lib" | sudo tee -a /etc/ld.so.conf.d/ffmpeg.conf 
#sudo ldconfig 
#cat /etc/ld.so.conf.d/ffmpeg.conf
#sudo apt install zlib1g zlib1g-dev perl cpanminus


 # ========================== 完成 ===============================
 echo "Linux FFmpeg build success! Installed to: $(pwd)/install"
