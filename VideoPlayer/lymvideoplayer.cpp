#include "lymvideoplayer.h"
#include <thread>
#include <QThread>
#include <iostream>


static int const KMaxVideoPktSize = 1000;
static int const KMaxAudioPktSize = 2000;


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

//    av_log_set_level(AV_LOG_DEBUG);
    if(SDL_Init(SDL_INIT_AUDIO) != 0){
        std::cout  <<"SDL_Init failed！！！！" << SDL_GetError()<< std::endl;
    }
    aPackets_ = std::make_unique<std::list<AVPacket>>();
    vPackets_ = std::make_unique<std::list<AVPacket>>();
    aCondLock_ = std::make_unique<LYMCodationLock>();
    vCondLock_ = std::make_unique<LYMCodationLock>();
}
LYMVideoPlayer::~LYMVideoPlayer(){

    stop();
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
    if(state_ == Paused){
        SetState(Playing);
    }

    std::cout  << " 点击了播放 state_ =" << state_ << std::endl;


}
void LYMVideoPlayer::pause(){
    if(state_ != Playing)return;
    // 状态可能是 正在播放
    //
    SetState(Paused);
     std::cout  << " 点击了暂停 state_ =" << state_ << std::endl;
}
void LYMVideoPlayer::stop(){
    if(state_ == Stopped)return;
    // 状态可能是 正在播放 暂停
    state_ = Stopped;
    //释放资源
    freeSouce();
    emit statsChanged(this);
     std::cout  << " 点击了停止 state_ =" << state_ << std::endl;
}

int64_t LYMVideoPlayer::getDuration(){

    return (formatcontext_) ? round(formatcontext_->duration * av_q2d(AV_TIME_BASE_Q))  : 0;
}
/*当前的播放时刻 s**/
int LYMVideoPlayer::GetCurrentTime(){
 return round(aTimes_);
}
/*设置当前的播放时刻 s**/
bool LYMVideoPlayer::SetCurrentTime(int seekTime){
    // 防止直接拖动到文件尾部
  if(seekTime >= GetCurrentTime()){
      seekTime -= 5;
  }
  seekTime_ = seekTime;
//  std::cout << "SetCurrentTime seekTime ="<< seekTime <<std::endl;
  return true;
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
//void LYMVideoPlayer::onInitFinish(std::function<void (LYMVideoPlayer *)> initFinish){
//    initFinish_ = initFinish;
//}
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
    hasAudio_ = setupAudio() >= 0;
    hasVideo_  = setupVideo() >= 0;
    if(!hasAudio_ && !hasVideo_){
        RRROR_END(-1,avformat_open_input);
    }


    // 这里初始化完毕
     emit InitFinishd(this);
     SetState(Playing);
     // 开始播放 音频
     SDL_PauseAudio(0);
     //开启播放状态之后才开启视频解码线程
   videoPlayThread_ = std::make_unique<std::thread>([this](){
        //子线程解码视频
        decodeVideoData();
        std::cout << " lym 视频线程结束了。。。 failed ！！！！" << std::endl;
    });


    while (true) {
        //如果已经停止播放了 这里就不去获取数据
        if(state_ == Stopped)break;
        if(state_ == Paused && seekTime_ == -1){
//            std::cout << " lym 暂停 state_ = " << state_ << " seekTime_" <<seekTime_ << std::endl;
            SDL_Delay(5);
            continue;
        }
        if(seekTime_ >= 0){
            int streamIdx = 0;
            if(hasAudio_){
                streamIdx = aStream_->index;
            }else{
                streamIdx = vStream_->index;
            }
            //转成 ffmpeg的时间戳
            int64_t ts = seekTime_ / av_q2d(formatcontext_->streams[streamIdx]->time_base);
            ret = av_seek_frame(formatcontext_,streamIdx,ts,AVSEEK_FLAG_BACKWARD);
            if(ret < 0) {
                seekTime_ = -1;
                std::cout << " lym av_seek_frame failed ！！！！" << std::endl;
                continue;

            }else {
                aSeekTime_ = seekTime_;
                vSeekTime_ = seekTime_;
                seekTime_ = -1;
                aTimes_ = 0;
                vTimes_ = 0;
                clearAudioPkts();
                clearVideoPkts();
            }
        }
        int aPSize =  aPackets_->size();
        int vPSize = vPackets_->size();
        //限制数据大小 防止过大文件占用内存
        if( vPSize >= KMaxVideoPktSize || aPSize >= KMaxAudioPktSize*0.9){
            SDL_Delay(5);
             std::cout<< "lym read packet full vPackets_size =  " << vPSize << " aPackets_size ="<< aPSize << std::endl;
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
            if(vPSize == 0 && aPSize == 0){
                fmtCtxCanFree_ = true;
                break;
            }
        }else{
            LYM_ERROR_BUFF(ret)
            std::cout << "av_read_frame error：" <<errbuf<< std::endl;
            continue;
        }



    }
    if(fmtCtxCanFree_){
        stop();
    }else{
        fmtCtxCanFree_ = true;
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
        std::cout << "formatcontext_->streams is null"<< std::endl;
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
        std::cout << "avcodec_find_decoder_by_name error"<< std::endl;
        return -1;
    }
    //    第三步 通过找到的编码器 创建解码器上下文
    //编码器的上下文
    *decodecCtx = avcodec_alloc_context3(decodec);
    if (!decodecCtx) {
        std::cout << "avcodec_alloc_context3 error"<< std::endl;
        return -1;
    }
    // 从流中拷贝数据到上下文
    ret = avcodec_parameters_to_context(*decodecCtx,(*stream)->codecpar);
    RRROR_RETRUN(ret,avcodec_parameters_to_context);
    //        第四步 打开编码 器
    ret = avcodec_open2(*decodecCtx, decodec, nullptr);
    RRROR_RETRUN(ret,avcodec_open2);

    return 0;
}
void LYMVideoPlayer::freeSouce(){    
    std::cout << __func__ <<"----开始释放--- " << std::endl;
    while (hasAudio_ && !aCanFree_) {
        std::cout << __func__ <<"----释放资源等待 aStream_---- " << std::endl;
        SDL_Delay(10);
    }
    while (hasVideo_ && !vCanFree_) {
        std::cout << __func__ <<"----释放资源等待 vStream_---- " << std::endl;
       SDL_Delay(10);
    }
    while (!fmtCtxCanFree_) {
        std::cout << __func__ <<"----释放资源等待 fmtCtxCanFree_----  " << std::endl;
       SDL_Delay(10);
    }
    videoPlayThread_->detach();

    avformat_close_input(&formatcontext_);
    freeAudioSource();
    freeVideoSource();
    fmtCtxCanFree_ = false;
    seekTime_ = -1;
    std::cout << __func__ <<"----释放资源结束---- " << std::endl;
}
void LYMVideoPlayer::fataerror(){
    state_ = Playing;
    freeSouce();
    emit playerFailed(this);

}
