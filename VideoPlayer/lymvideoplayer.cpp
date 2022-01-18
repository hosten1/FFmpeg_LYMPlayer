#include "lymvideoplayer.h"
#include <thread>
#include <QThread>
#include <iostream>




#define LYM_ERROR_BUFF(ret) \
    char errbuf[1024] = ""; \
    av_strerror(ret, errbuf, sizeof (errbuf));


#define RRROR_END(ret,fun) \
    if (ret < 0) { \
       LYM_ERROR_BUFF(ret); \
       std::cout  << #fun<< " Error " << errbuf << std::endl; \
       fataerror(); \
       return; \
    }

#define RRROR_RETRUN(ret,msg) \
    if (ret < 0) { \
    LYM_ERROR_BUFF(ret); \
    std::cout  << #msg<< " Error " << errbuf << std::endl; \
    return -1; \
    }

LYMVideoPlayer::LYMVideoPlayer(QObject *parent) : QObject(parent)
{
    if(SDL_Init(SDL_INIT_AUDIO) != 0){
        std::cout  <<"SDL_Init failed！！！！" << SDL_GetError()<< std::endl;
    }
    aPackets_ = std::make_unique<std::list<AVPacket>>();
    vPackets_ = std::make_unique<std::list<AVPacket>>();
    aCondLock_ = std::make_unique<LYMCodationLock>();
    vCondLock_ = std::make_unique<LYMCodationLock>();
}
LYMVideoPlayer::~LYMVideoPlayer(){
    // 清除所有初始化的子系统
    SDL_Quit();
};
void LYMVideoPlayer::play(){
    if(state_ == Playing)return;
    // 状态可能是 暂停 停止
    if(state_ == Stopped){
        //解析读取文件
        std::thread([this](){
            //子线程读取文件
            readFile();
        }).detach();//读取完文件释放线程
    }


}
void LYMVideoPlayer::pause(){
    if(state_ != Playing)return;
    // 状态可能是 正在播放
    //
    SetState(Paused);
}
void LYMVideoPlayer::stop(){
    if(state_ == Stopped)return;
    // 状态可能是 正在播放 暂停
    //
    SetState(Stopped);
    //释放资源
    std::thread([this](){
        SDL_Delay(100);
        freeSouce();
    }).detach();
//    freeSouce();
}

int64_t LYMVideoPlayer::getDuration(){
    if(formatcontext_)return formatcontext_->duration;
    return 0;
}
bool LYMVideoPlayer::isPlaying(){
    return state_ == Playing;
}
/**获取状态**/
LYMVideoPlayer::PlayState LYMVideoPlayer::getState(){

    return state_;
}
void LYMVideoPlayer::SetFileName(std::string fileNmae){
    if(fileNmae.length() < 0)return;
     memcpy(fileName_,fileNmae.c_str(),fileNmae.length()+1);
}
void LYMVideoPlayer::onInitFinish(std::function<void (LYMVideoPlayer *)> initFinish){
    initFinish_ = initFinish;
}
#pragma mark --- 私有方法
// Private Method
void LYMVideoPlayer::SetState(LYMVideoPlayer::PlayState stateT){
    if(stateT == state_){
        return;
    }
    state_ = stateT;
    // 发送槽信号
    emit statsChanged(this);
}
void LYMVideoPlayer::readFile(){
    int ret = 0;
    //    const char  *inFileName = fileName_;
    // 创建解封装上下文
    std::cout  << " 开始读取文件 " << fileName_ << std::endl;
    ret =  avformat_open_input(&formatcontext_,fileName_, nullptr, nullptr);

    RRROR_END(ret,avformat_open_input);
    ret = avformat_find_stream_info(formatcontext_, nullptr);
    RRROR_END(ret,avformat_find_stream_info);
    //打印流信息到控制台
    av_dump_format(formatcontext_, 0, fileName_, 0);
    fflush(stderr);
    SetState(Playing);
    bool hasAudio = setupAudio() >= 0;
    bool hasVodeo  = setupVideo() >= 0;
    if(!hasAudio && !hasVodeo){
        RRROR_END(-1,avformat_open_input);
    }


    // 这里初始化完毕
    if(initFinish_)initFinish_(this);


    while (true) {
        //如果已经停止播放了 这里就不去获取数据
        if(state_ == Stopped)break;
        if(vPackets_->size()  >= 500 || aPackets_->size() >= 1000){
            SDL_Delay(10);
            continue;
        }
        AVPacket pkt;
        ret = av_read_frame(formatcontext_, &pkt);
        if(ret == 0){
            if (pkt.stream_index == aStream_->index) {
                addAudioPkt(pkt);
            }else if (pkt.stream_index == vStream_->index){
                addVideoPkt(pkt);
            }else{
                av_packet_unref(&pkt);
            }
        }else if(ret == AVERROR_EOF){
            //读取到文件末尾了  直接退出循环
            LYM_ERROR_BUFF(ret)
            std::cout << "读取到文件末尾了,退出 error：" <<errbuf<< std::endl;
            break;
        }else{
            LYM_ERROR_BUFF(ret)
            std::cout << "av_read_frame error：" <<errbuf<< std::endl;
            continue;
        }


    }
    std::cout  <<  "VideoPlayVideo end"  << std::endl;
}

int LYMVideoPlayer::ininDeCodec(AVMediaType type, AVCodecContext **decodecCtx, AVStream **stream){
    //    编码器
    AVCodec    *decodec  = nullptr;

    //返回的是流的索引
    int ret = av_find_best_stream(formatcontext_, type, -1, -1, nullptr, -1);
    RRROR_RETRUN(ret,av_find_best_stream);
    *stream = formatcontext_->streams[ret];
    if (!*stream) {
        av_log(NULL, AV_LOG_DEBUG, "formatcontext_->streams is null");
        return -1;
    }
    // 第一步 找到解码器 从流中查找
    //    if (stream->codecpar->codec_id == AV_CODEC_ID_AAC) {
    //        decodec = avcodec_find_decoder_by_name("libfdk_aac");
    //    }else{
    //        decodec = avcodec_find_decoder(stream->codecpar->codec_id);
    //    }
    decodec = avcodec_find_decoder((*stream)->codecpar->codec_id);
    if (!decodec) {
        av_log(NULL, AV_LOG_DEBUG, "avcodec_find_decoder_by_name error");
        return -1;
    }
    //    第三步 通过找到的编码器 创建解码器上下文
    //编码器的上下文
    *decodecCtx = avcodec_alloc_context3(decodec);
    if (!decodecCtx) {
        av_log(NULL, AV_LOG_DEBUG, "avcodec_alloc_context3 error");
        return -1;
    }
    // 从流中拷贝数据到上下文
    ret = avcodec_parameters_to_context(*decodecCtx,(*stream)->codecpar);
    RRROR_RETRUN(ret,avcodec_parameters_to_context);
    //        第四步 打开编码 器
    ret = avcodec_open2(*decodecCtx, decodec, nullptr);
    if (ret < 0) {
        char errbuf[1024] = {0};
        av_strerror(ret, errbuf, 1024);
        av_log(nullptr, AV_LOG_DEBUG,"avcodec_open2 ERROR [%d] %s\n",ret,errbuf);
        return -1;
    }
    return 0;
}
void LYMVideoPlayer::freeSouce(){
    avformat_close_input(&formatcontext_);
    freeAudioSource();
    freeVideoSource();
}
void LYMVideoPlayer::fataerror(){
    SetState(Stopped);
    emit playerFailed(this);
    freeSouce();
}
