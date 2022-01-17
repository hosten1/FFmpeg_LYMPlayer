#include "lymvideoplayer.h"
#include <iostream>


#define LYM_ERROR_BUFF(ret) \
char errbuf[1024] = ""; \
av_strerror(ret, errbuf, sizeof (errbuf));


#define RRROR_END(ret,fun) \
if (ret < 0) { \
    LYM_ERROR_BUFF(ret); \
    emit playerFailed(this);\
    std::cout  << #fun<< " Error " << errbuf << std::endl; \
    goto __END; \
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

    vFrame_ = av_frame_alloc();
    if(!vFrame_){
        std::cout  << "av_frame_alloc video Error " << std::endl;
        return -1;
    }
    initVideoSDL();
//    voutFile_ = fopen(vSpec_->outFile.c_str(), "wb+");
//    if (voutFile_ == nullptr) {
//        av_log(NULL, AV_LOG_ERROR, "打开PCM文件失败！！！！！！！ %s\n",vSpec_->outFile.c_str());
//        return -1;
//    }
//    vSpec_->width = vDecodecCtx -> width;
//    vSpec_->heitht = vDecodecCtx -> height;
//    vSpec_->fmt = vDecodecCtx -> pix_fmt;
//    AVRational ratio = av_guess_frame_rate(formatcontext_, formatcontext_->streams[vStreamIdx_], nullptr);
//    vSpec_->fps = ratio.num / ratio.den;
//    //创建用于存放一帧数据的缓冲区  如果成功就返回帧的大小
//    ret = av_image_alloc(imgBUff_, imgLinesizes_, vSpec_->width, vSpec_->heitht, vSpec_->fmt, 1);
//    RRROR_RETRUN(ret,av_image_alloc);
//    imgSize_ = ret;
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
void LYMVideoPlayer::freeVideoSource(){
    clearVideoPkts();
    avcodec_free_context(&vDecodecCtx_);
}
