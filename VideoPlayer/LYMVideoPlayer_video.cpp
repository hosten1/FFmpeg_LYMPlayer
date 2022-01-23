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
    return 0;
}
int LYMVideoPlayer::initVideoSws(){
    int inWidth = vDecodecCtx_->width;
    int inHeight = vDecodecCtx_->height;
    //  保证视频是 16的倍数
    vOutSpec_.width  = inWidth  >> 4 << 4;
    vOutSpec_.height = inHeight >> 4 << 4;
    vOutSpec_.fmt = AV_PIX_FMT_RGB24;
    int imageSize = av_image_get_buffer_size(vOutSpec_.fmt, vOutSpec_.width, vOutSpec_.height, 1);
    vOutSpec_.imageSize = imageSize;
    // 初始化 视频转换上下文
    vSwsCtx_ = sws_getContext(inWidth,inHeight, vDecodecCtx_->pix_fmt,
                              vOutSpec_.width, vOutSpec_.height, vOutSpec_.fmt,
                              SWS_BILINEAR, nullptr,nullptr, nullptr);
    if(!vSwsCtx_){
        std::cout  << "sws_getContext Error " << std::endl;
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
void LYMVideoPlayer::decodeVideoData(){
    while (true) {
        if(state_ == Paused && vSeekTime_ == -1){
           //暂停  等待5ms防止过快执行
            std::cout << " lym 暂停 decodeVideoData state_ = " << state_ << " vSeekTime_"  << vSeekTime_ << std::endl;
            continue;
        }
        if(state_ == Stopped){
            vCanFree_ = true;
            break;
        }
        vCondLock_->lock();
        if(vPackets_->empty()){
            vCondLock_->unlock();
            SDL_Delay(2);
            continue;
        }
        // 取出头部的视频包
        AVPacket vPkt = vPackets_->front();
        vPackets_->pop_front();
        vCondLock_->unlock();

        int ret = avcodec_send_packet(vDecodecCtx_, &vPkt);
        if(vPkt.dts != AV_NOPTS_VALUE){
            //计算当前时间
            vTimes_ = av_q2d(vStream_->time_base) * vPkt.dts;
            if(!hasAudio_){
                emit timePlayerChanged(this,vTimes_);
            }
        }
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
            //发现视频时间早于 seektime ,就不进行渲染
            if(vSeekTime_ >= 0){
                if( vTimes_ < vSeekTime_){
                    continue;
                }else{
                    vSeekTime_ = -1;
                }
            }

            //重采样成rgb格式数据
            ret = sws_scale(vSwsCtx_, vSwsInFrame_->data, vSwsInFrame_->linesize,
                            0, vDecodecCtx_->height,
                            vSwsoutFrame_->data, vSwsoutFrame_->linesize);

//            double pts =   0.0;
//            if(vSwsInFrame_->pts != AV_NOPTS_VALUE) {
//                pts =   av_q2d(aStream_->time_base) * vSwsInFrame_->pts;
//            } else {
//                pts = 0.0;
//            }
            // 如果视频的时间大于音频时间，则暂停视频
            if(hasAudio_){
                while(vTimes_ > aTimes_ && state_ == Playing){
//                     std::cout<<"lym vTimes_ = "<< vTimes_ <<
//                                " aTimes_ = " << aTimes_ <<
//                                " frameCnt_="<< frameCnt_ <<
//                                " vPts="<< pts <<std::endl;
//                    //延迟下 按照5ms
                    SDL_Delay(5);
                    // 停止后，这里有可能 线程复活后获取数据
                    if(state_ == Stopped){
                        vCanFree_ = true;
                        return;
                    }
                }
            }else{
                // TODO:没有音频的情况
                SDL_Delay(1000/25.0f);
                // 停止后，这里有可能 线程复活后获取数据
                if(state_ == Stopped){
                    vCanFree_ = true;
                    return;
                }
            }

            uint8_t *data = (uint8_t *)av_malloc(vOutSpec_.imageSize);
            memcpy(data,vSwsoutFrame_->data[0],vOutSpec_.imageSize);

            //            uint8_t *data = (uint8_t *)av_malloc(vOutSpec_.imageSize);
            //            size_t videoFirst = vSwsoutFrame_->linesize[0]*vOutSpec_.height;
            //            memcpy(data,vSwsoutFrame_->data[0],videoFirst);
            //            size_t videoSecond = vSwsoutFrame_->linesize[1]*vOutSpec_.height >> 1;
            //            memcpy(data + videoFirst,vSwsoutFrame_->data[1],videoSecond);
            //            memcpy(data + videoSecond + videoFirst,vSwsoutFrame_->data[2],vSwsoutFrame_->linesize[2]*vOutSpec_.height >> 1);

            emit frameDecode(this,data,vOutSpec_);
            frameCnt_++;
            SDL_Delay(10);


        }
    }

}
void LYMVideoPlayer::freeVideoSource(){
    std::cout << __func__ <<"开始释放视频资源 》》》》》》》 " << std::endl;
    clearVideoPkts();
    vStream_ = nullptr;
    if(vSwsoutFrame_){
        av_freep(&vSwsoutFrame_->data[0]);
        av_frame_free(&vSwsoutFrame_);
    }
    av_frame_free(&vSwsInFrame_);
    avcodec_free_context(&vDecodecCtx_);
    sws_freeContext(vSwsCtx_);
    vSwsCtx_ = nullptr;
    vCanFree_ = false;
    hasVideo_ = false;
    vTimes_ = 0.0;
    vSeekTime_ = -1;
    std::cout << __func__ <<"释放视频资源完成 《《《《《 " << std::endl;
}
