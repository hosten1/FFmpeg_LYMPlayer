#include "lymvideoplayer.h"
#include <iostream>

//输出通道数
#define kFFMPEAGaAUDIORECORDDSTCHANNELlAYOUT (AV_CH_LAYOUT_STEREO)
static int const dstChLayout = AV_CH_LAYOUT_STEREO;
static AVSampleFormat const dstSampleFmt = AV_SAMPLE_FMT_S16;
static int const dstSampleRate = 44100;



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

int LYMVideoPlayer::setupAudio(void){

    int ret = ininDeCodec(AVMEDIA_TYPE_AUDIO, &aDecodecCtx_,&aStream_);
    RRROR_RETRUN(ret,ininDeCodec);
    ret = initAuidoSwr();
    RRROR_RETRUN(ret,initAuidoSwr);
    //初始化sdl
    ret = initAuidoSDL();
    RRROR_RETRUN(ret,initAuidoSDL);



    //    sampleFrameSize_ = av_get_bytes_per_sample(aSpec_->fmt) * aDecodecCtx -> channels;
    return 0;
}
void LYMVideoPlayer::addAudioPkt(AVPacket pkt){
    aCondLock_->lock();
    aPackets_->push_back(pkt);
    aCondLock_->signal();
    aCondLock_->unlock();
}
int LYMVideoPlayer::initAuidoSwr(){
    //    创建重采样的上下文
    aInSwrSpec_.sampleRate = aDecodecCtx_->sample_rate;
    aInSwrSpec_.fmt = aDecodecCtx_->sample_fmt;
    aInSwrSpec_.channals = aDecodecCtx_->channels;
    aInSwrSpec_.channalLayout = aDecodecCtx_->channel_layout;


    aOutSwrSpec_.sampleRate = dstSampleRate;
    aOutSwrSpec_.fmt = dstSampleFmt;
    aOutSwrSpec_.channals = av_get_channel_layout_nb_channels(dstChLayout);
    aOutSwrSpec_.channalLayout = dstChLayout;
    aOutSwrSpec_.bytesPerSampleFrame = aOutSwrSpec_.channals * av_get_bytes_per_sample(aOutSwrSpec_.fmt);
    // AV_CH_LAYOUT_STEREO是立体声 AV_CH_LAYOUT_MONO是单声道
    swrContext_ = swr_alloc_set_opts(nullptr,/*上下文*/
                                    aOutSwrSpec_.channalLayout,/*输出声道数*/
                                    aOutSwrSpec_.fmt,/*输出位数*/
                                    aOutSwrSpec_.sampleRate,/*输出采样*/
                                    aInSwrSpec_.channalLayout,
                                    aInSwrSpec_.fmt,// 输入采样格式 我的mac 是 32位浮点
                                    aInSwrSpec_.sampleRate,
                                    0, nullptr);

    if (swrContext_ == nullptr) {
        av_log(nullptr, AV_LOG_DEBUG,"重采样失败\n");
        return -1;
    }
    if (swr_init(swrContext_) < 0) {
        av_log(nullptr, AV_LOG_DEBUG,"重采样初始化失败\n");
        return -1;
    }
    //初始化重采样输入参数
    aSwrInFrame_ = av_frame_alloc();
    if(!aSwrInFrame_){
        std::cout  << "av_frame_alloc aSwrInFrame_ Error " << std::endl;
        return -1;
    }
    aOutFrame_ = av_frame_alloc();
    if(!aOutFrame_){
        std::cout  << "av_frame_alloc aOutFrame_ Error " << std::endl;
        return -1;
    }

    //创建输出缓冲区
    int  ret = av_samples_alloc(aOutFrame_->data,
                                aOutFrame_->linesize,
                                aOutSwrSpec_.channals,
                                4096,
                                aOutSwrSpec_.fmt,1);
    RRROR_RETRUN(ret,av_samples_alloc);
    std::cout <<"输出缓冲区 channels = " <<   aOutSwrSpec_.channals
             << " srcSampleRate = " << aOutSwrSpec_.sampleRate
             << " dst_nb_samples = "<< aOutFrame_->nb_samples
             << std::endl;
    return 0;
}
int LYMVideoPlayer::initAuidoSDL(){
    SDL_AudioSpec spec;
    // 采样率
    spec.freq = aOutSwrSpec_.sampleRate;
    // 采样格式（s16le）
    spec.format = AUDIO_S16LSB;
    // 声道数
    spec.channels = av_get_channel_layout_nb_channels(aOutSwrSpec_.channalLayout);
    // 音频缓冲区的样本数量（这个值必须是2的幂）
    // 512 * 2 *
    spec.samples = 1024*4;
    // 回调
    spec.callback = sdlAudioDataCallBack;
    // 传递给回调的参数

    spec.userdata = this;

    //打开音频设备
    if (SDL_OpenAudio(&spec, nullptr)) {
        std::cout << "SDL_OpenAudio Error" << SDL_GetError() << std::endl;
        // 清除所有初始化的子系统
        SDL_Quit();
        return -1;
    }
    return 0;
}
void LYMVideoPlayer::setVolumn(int volumn){
  volumn_ = volumn;
}
int LYMVideoPlayer::getVolumn(){
    return volumn_;
}
void LYMVideoPlayer::setMute(bool isMute){
     isMute_ = isMute;
}
bool LYMVideoPlayer::isMuteFun(){
    return isMute_;
}
void LYMVideoPlayer::clearAudioPkts(){
    aCondLock_->lock();
    for(AVPacket &pkt : *aPackets_){
        av_packet_unref(&pkt);
    }
    aPackets_->clear();
    aCondLock_->unlock();
}
void LYMVideoPlayer::sdlAudioDataCallBack(void *userData,Uint8 * stream, int len){
    LYMVideoPlayer *audioP = static_cast<LYMVideoPlayer*>(userData);
    audioP->sdlAudioDataCB(stream,len);
}


void LYMVideoPlayer::sdlAudioDataCB(Uint8 *stream, int len){
    // 清空stream  也就是静音
     SDL_memset(stream, 0, len);
    while (len > 0) {
        if(state_ == Paused){
           //暂停
            break;
        }
        if(state_ == Stopped){
            aCanFree_ = true;
            break;
        }
        if(aSwrBufferIdx_ >= aSwrBUfferSize_){
            //解码音频数据
            aSwrBUfferSize_= decodeAudioData();
            if(aSwrBUfferSize_ < 0){
                memset(aOutFrame_->data[0],0,aSwrBUfferSize_ = 1024);
            }
            aSwrBufferIdx_= 0;
        }
        int srcLen = aSwrBUfferSize_ - aSwrBufferIdx_;
        srcLen = std::min(srcLen,len);

        //计算音量 换算
        int volumn = (isMute_ == true) ? 0:(volumn_ *1.0 / Max) * SDL_MIX_MAXVOLUME;
//        SDL缓冲区数据
        SDL_MixAudio(stream,//目的缓冲区
                             aOutFrame_->data[0]+aSwrBufferIdx_,//源缓冲区
                             srcLen,//音频数据长度
                             volumn);//音量大小，0-128 之间的数。SDL_MIX_MAXVOLUME代表最大音量。
       len -= srcLen;
       stream += srcLen;
       aSwrBufferIdx_ += srcLen;


    }
}

int LYMVideoPlayer::decodeAudioData(){
    aCondLock_->lock();
    //这里 有可能是系统的假唤醒  所以要进行阻塞
    //    while (aPackets_->empty()) {
    //         aCondLock_->wait();
    //    }
    if (aPackets_->empty() || state_ == Stopped) {
//        std::cout<<"lym decodeAudioData error aPackets_->empty() = "<<  aPackets_->empty() << std::endl;
       SDL_Delay(5);
        aCondLock_->unlock();
        return 0;
    }
    //取出头部的数据包
    AVPacket pkt = aPackets_->front();
    aPackets_->pop_front();
    //解锁
    aCondLock_->unlock();

    if(pkt.pts != AV_NOPTS_VALUE){
        //计算当前时间
        aTimes_ = av_q2d(aStream_->time_base) * pkt.pts;
        emit timePlayerChanged(this,aTimes_);

    }else{
        std::cout<<"lym decodeAudioData error = "<< trunc(vTimes_) << " aTimes_ = " << trunc(aTimes_)<<std::endl;
    }
    //发现视频时间早于 seektime ,就不进行渲染
    if(aSeekTime_ >= 0){
        if( aTimes_ < aSeekTime_){
            //释放内部的数据
            av_packet_unref(&pkt);
            return 0;
        }else{
            aSeekTime_ = -1;
        }
    }
    int ret = avcodec_send_packet(aDecodecCtx_, &pkt);
    RRROR_RETRUN(ret,avcodec_send_packet);
    //获取编码后的音频数据，如果成功，需要重复的去获取，直到失败
    ret =  avcodec_receive_frame( aDecodecCtx_,aSwrInFrame_);
    //释放内部的数据
    av_packet_unref(&pkt);
    // 这里说明编码的数据不够
    if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
        return 0;
    }else RRROR_RETRUN(ret,avcodec_receive_frame);

    // 这里的数据不一定是返回一个，有可能返回多个
    // 返回值大于零 说明给编码器发送数据是成功的
    //        while (ret >= 0) {


    //        }


    //        //重采样 数据
    int dst_nb_samples =
            (int)av_rescale_rnd(aOutSwrSpec_.sampleRate, aSwrInFrame_->nb_samples, aInSwrSpec_.sampleRate, AV_ROUND_UP);
    RRROR_RETRUN(dst_nb_samples,av_rescale_rnd);
    ret = swr_convert(swrContext_,
                      aOutFrame_->data, dst_nb_samples,
                      (const uint8_t **)aSwrInFrame_->data,aSwrInFrame_->nb_samples
                      );
    RRROR_RETRUN(ret,swr_convert);
    // 以下两种结算方式等价;以FFmpeg的方式结算是兼容planer的格式音频
    int  ret_nb_samples = av_samples_get_buffer_size(nullptr, aOutSwrSpec_.channals, ret, aOutSwrSpec_.fmt, 1);
    // 返回解码的数据的大小
//    int dataSize = ret * aOutSwrSpec_.bytesPerSampleFrame;
//    printf("\n解码成pcm成功 : sampleRate = %d sample_format = %s  channels = %d dataSize:%d ret_nb_samples:%d",
//           aOutFrame_->sample_rate,
//           av_get_sample_fmt_name((AVSampleFormat)aOutFrame_->format),
//           av_get_channel_layout_nb_channels(aOutFrame_->channel_layout),
//           dataSize,ret_nb_samples);
    return  ret_nb_samples;
}


void LYMVideoPlayer::freeAudioSource(){
    std::cout << __func__ <<"开始释放音频资源 》》》》》》》 " << std::endl;
    aSwrBufferIdx_ = 0;
    aSwrBUfferSize_ = 0;
    aStream_ = nullptr;
    clearAudioPkts();
    avcodec_free_context(&aDecodecCtx_);
    swr_free(&swrContext_);
    if(aOutFrame_){
        av_freep(&aOutFrame_->data[0]);
        av_frame_free(&aOutFrame_);
    }
    av_frame_free(&aSwrInFrame_);
     SDL_PauseAudio(0);
     SDL_CloseAudio();
     aCanFree_ = false;
     hasAudio_ = false;
     aTimes_ = 0.0;
     aSeekTime_ = -1;
     std::cout << __func__ <<"释放音频资源完成 《《《《《 " << std::endl;
}















