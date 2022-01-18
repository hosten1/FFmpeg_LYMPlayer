#include "lymvideoplayer.h"
#include <iostream>
#include <thread>

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
#define RRROR_CONTINUE(ret,fun) \
    if (ret < 0) { \
    LYM_ERROR_BUFF(ret); \
    std::cout  << #fun<< " Error " << errbuf << std::endl; \
    continue; \
    }

#define RRROR_RETRUN(ret,msg) \
    if (ret < 0) { \
    LYM_ERROR_BUFF(ret); \
    std::cout  << #msg<< " Error " << errbuf << std::endl; \
    return -1; \
    }


int LYMVideoPlayer::setupVideo(void){

    int ret = ininDeCodec(AVMEDIA_TYPE_VIDEO, &vDecodecCtx_,&vStream_);
    RRROR_RETRUN(ret,ininDeCodec);

    ret = initVideoSws();
    RRROR_RETRUN(ret,initVideoSws);

    std::thread([this](){
        //子线程解码视频
        decodeVideoData();
    }).detach();
    //开启新的线程去解码
    ret = initVideoSDL();
    RRROR_RETRUN(ret,initVideoSDL);
    return 0;
}
int LYMVideoPlayer::initVideoSws(){

    vOutSpec_.width = vDecodecCtx_->width;
    vOutSpec_.height = vDecodecCtx_->height;
    vOutSpec_.fmt = AV_PIX_FMT_RGB24;

// 初始化 视频转换上下文
    vSwsCtx_ = sws_getContext(vDecodecCtx_->width,vDecodecCtx_->height, vDecodecCtx_->pix_fmt,
                              vOutSpec_.width, vOutSpec_.height, vOutSpec_.fmt,
                              SWS_BILINEAR, nullptr,nullptr, nullptr);
    if(!vSwsCtx_){
        return -1;
    }

    //初始化重采样输入参数
    vSwsInFrame_ = av_frame_alloc();
    if(!aSwrInFrame_){
        std::cout  << "av_frame_alloc vSwsInFrame_ Error " << std::endl;
        return -1;
    }
    vSwsoutFrame_ = av_frame_alloc();
    if(!aOutFrame_){
        std::cout  << "av_frame_alloc vSwsoutFrame_ Error " << std::endl;
        return -1;
    }
    int ret = av_image_alloc(vSwsoutFrame_->data, vSwsoutFrame_->linesize,
                             vOutSpec_.width, vOutSpec_.height,
                             vOutSpec_.fmt, 1);
    RRROR_RETRUN(ret,av_image_alloc);
    return 0;
}
void LYMVideoPlayer::addVideoPkt(AVPacket pkt){
    vCondLock_->lock();
    vPackets_->push_back(pkt);
    vCondLock_->signal();
    vCondLock_->unlock();
}
void LYMVideoPlayer::clearVideoPkts(){
    vCondLock_->lock();
    for(AVPacket &pkt : *vPackets_){
        av_packet_unref(&pkt);
    }
    vPackets_->clear();
    vCondLock_->unlock();
}
int LYMVideoPlayer::initVideoSDL(){

}
void LYMVideoPlayer::decodeVideoData(){
    while (true) {
        vCondLock_->lock();
        if(vPackets_->empty()){
            vCondLock_->unlock();
            continue;
        }
        // 取出头部的视频包
        AVPacket vPkt = vPackets_->front();
        vPackets_->pop_front();
        vCondLock_->unlock();

        int ret = avcodec_send_packet(vDecodecCtx_, &vPkt);
        av_packet_unref(&vPkt);
        RRROR_CONTINUE(ret,avcodec_send_packet);
        // 这里的数据不一定是返回一个，有可能返回多个
        // 返回值大于零 说明给编码器发送数据是成功的
        while (ret >= 0) {
            //获取编码后的音频数据，如果成功，需要重复的去获取，直到失败
            ret =  avcodec_receive_frame( vDecodecCtx_, vSwsInFrame_);
            // 这里说明编码的数据不够
            if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
                break;
            }else if(ret < 0){
                LYM_ERROR_BUFF(ret);
                std::cout  << "avcodec_receive_frame "<< " Error " << errbuf << std::endl;
                break;
            }
            //延迟下
             SDL_Delay(1000/23.0f);
            //重采样成rgb格式数据
            ret = sws_scale(vSwsCtx_, vSwsInFrame_->data, vSwsInFrame_->linesize,
                            0, vDecodecCtx_->height,
                            vSwsoutFrame_->data, vSwsoutFrame_->linesize);
            int imageSize = av_image_get_buffer_size(vOutSpec_.fmt, vOutSpec_.width, vOutSpec_.height, 1);
//            std::cout<< "sws_scale(): " << &(vSwsoutFrame_->data[0]) << "  ret ="<<ret << "  imageSize ="<<imageSize<<std::endl;

            emit frameDecode(this,vSwsoutFrame_->data[0],imageSize,vOutSpec_);

        }
    }

}
void LYMVideoPlayer::freeVideoSource(){
    clearVideoPkts();
    sws_freeContext(vSwsCtx_);
    if(vSwsoutFrame_){
        av_freep(&vSwsoutFrame_->data[0]);
        av_frame_free(&vSwsoutFrame_);
    }
    av_frame_free(&vSwsInFrame_);
    avcodec_free_context(&vDecodecCtx_);
}
