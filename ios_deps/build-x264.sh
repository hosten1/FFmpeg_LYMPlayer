#!/bin/bash


ARCHS="arm64"

# 函数：编译指定架构
build_arch() {
	CWD=$(pwd)
	local SRC_PATH=$1 # 第一个参数是源码src目录
    local ARCH=$3    # 第三个参数是架构
    local PREFIX=$2   # 第二个参数是安装目录    
    # local SCRATCH="scratch-fdk-aac"
    echo "Building for architecture: $ARCH SRC_PATH: $SRC_PATH PREFIX: $PREFIX"
	#  # 创建架构临时目录
	# mkdir -p "$SCRATCH/$ARCH"
	# 进入源码目录
	cd "$SRC_PATH" || exit
	# local CFLAGS="-arch $ARCH"
	 # 配置架构和平台
    if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]; then
        PLATFORM="iPhoneSimulator"
        if [ "$ARCH" = "x86_64" ]; then
            SIMULATOR=" -mios-simulator-version-min=7.0"
            HOST="--host=x86_64-apple-darwin"
        else
            SIMULATOR=" -mios-simulator-version-min=7.0"
            HOST="--host=i386-apple-darwin"
        fi
    else
        PLATFORM="iPhoneOS"
        if [ "$ARCH" = "arm64" ]; then
            HOST="--host=aarch64-apple-darwin"
        else
            HOST="--host=arm-apple-darwin"
        fi
    fi

	 # 设置 Xcode 编译器
    XCRUN_SDK=$(echo $PLATFORM | tr '[:upper:]' '[:lower:]')
    CC="xcrun -sdk $XCRUN_SDK clang -Wno-error=unused-command-line-argument-hard-error-in-future  -arch $ARCH"
	local GAS_PREPROCESSOR=$SRC_PATH/extras/gas-preprocessor.pl
	 if [ ! -r "$GAS_PREPROCESSOR" ];then
		echo 'gas-preprocessor.pl not found. Trying to install...'
		(curl -L https://github.com/libav/gas-preprocessor/blob/master/gas-preprocessor.pl \
		-o "${GAS_PREPROCESSOR}" \
		&& chmod +x "${GAS_PREPROCESSOR}") \
		|| exit 1
    fi
    local AS="${GAS_PREPROCESSOR} $CC"
	CFLAGS="-arch $ARCH $SIMULATOR  -fembed-bitcode"
	CXXFLAGS="$CFLAGS"
	LDFLAGS="$CFLAGS"
 
	# CXX="$CC" 
	# CPP="$CC -E" 
    AS="$AS" 
	CC="$CC" ./configure \
		    "$CONFIGURE_FLAGS" \
		    $HOST \
			--enable-static \
			--enable-pic \
			--disable-cli \
		    --extra-cflags="$CFLAGS" \
		    --extra-ldflags="$LDFLAGS" \
		    --prefix="$PREFIX"

	make -j3 install || exit 1
	cd $CWD || exit
}

# 函数：合并多个架构的库文件为 fat binary
create_fat_binary() {
	local FAT="x264-iOS"
    echo "Creating fat binaries..."
	mkdir -p $FAT/lib
	set - "$ARCHS"
	CWD=$(pwd)
	cd $THIN/$1/lib || exit
	for LIB in *.a
	do
		cd $CWD
		lipo -create `find $THIN -name $LIB` -output $FAT/lib/"$LIB"
	done

	cd $CWD
	cp -rf "$THIN"/"$1"/include $FAT
}

# 函数：执行编译
compile() {
    CWD=$(pwd)
    for ARCH in $ARCHS
    do
        build_arch $ARCH
    done
}

# 主函数
main() {
	# if [ "$*" ]
	# then
	# 	if [ "$*" = "lipo" ]
	# 	then
	# 		compile
	# 	else
	# 		ARCHS="$*"
	# 		if [ $# -eq 1 ]
	# 		then
    #     		create_fat_binary
	# 		fi
	# 	fi
	# fi
	if [ "$#" -eq 3 ]; then
	   local SRC_PATH=$1 # 第一个参数是源码目录
       local ARCHS=$3    # 第三个参数是架构
       local PREFIX=$2   # 第二个参数是安装目录
       build_arch "$SRC_PATH" "$PREFIX" "$ARCHS"

    else
        echo "Usage: $0 <arch> <action>"
        echo "Actions: build, lipo"
        exit 1
    fi
}

# 执行主函数
main "$@"