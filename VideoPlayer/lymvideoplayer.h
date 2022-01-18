#ifndef LYMVIDEOPLAYER_H
#define LYMVIDEOPLAYER_H

#include <QObject>
#include <list>
#include <string>

#include "lymcodationlock.h"
extern "C" {
    #include "libavutil/avutil.h"
    #include "libavdevice/avdevice.h"
    #include "libavformat/avformat.h"
    #include "libavcodec/avcodec.h"
    #include "libavutil/imgutils.h"
    #include "libswresample/swresample.h"
    #include "libavutil/imgutils.h"
    #include "libswscale/swscale.h"
}


class LYMVideoPlayer : public QObject
{
    Q_OBJECT
public:
    typedef enum PlayState{
        Stopped = 0,
        Playing,
        Paused,
    } PlayState;
    typedef struct DecodeAudioSpec {
        int sampleRate = 0;
        AVSampleFormat fmt;
        int channals = 0;
        int channalLayout = 0;
        int bytesPerSampleFrame = 0;
    }DecodeAudioSpec;
    typedef struct DecodeVideoSpec {
        int width = 0;
        int height = 0;
        AVPixelFormat fmt= AV_PIX_FMT_YUV420P;
        int imageSize = 0;
    }DecodeVideoSpec;
    typedef enum LYMVolumnRange {
          Min = 0,
          Max = 100,
    }LYMVolumnRange;
    explicit LYMVideoPlayer(QObject *parent = nullptr);
    ~LYMVideoPlayer();
    void play();
    void stop();
    void pause();
    bool isPlaying();
    // 获取文件时长 返回 微秒
    int64_t getDuration();
    /**获取状态**/
    PlayState getState();
    /**设置文件名**/
    void SetFileName(std::string fileNmae);
    //文件初始化完成回调
    void onInitFinish( std::function<void (LYMVideoPlayer *player)> initFinish);
    void setVolumn(int volumn);
    int getVolumn();
    void setMute(bool isMute);
    bool isMuteFun();
signals:
    void statsChanged(LYMVideoPlayer *player);
    void playerFailed(LYMVideoPlayer *player);
    void frameDecode(LYMVideoPlayer *player,uint8_t *data,DecodeVideoSpec &videoSpec);
private:
    /**音频属性和方法**/
    AVCodecContext *aDecodecCtx_;
    //流的标记
    AVStream *aStream_ = nullptr;
    AVFrame *aOutFrame_= nullptr;
    std::unique_ptr<std::list<AVPacket>> aPackets_;
    std::unique_ptr<LYMCodationLock> aCondLock_;
    //重采样上下文
    SwrContext *swrContext_ = nullptr;
    DecodeAudioSpec aInSwrSpec_;
    DecodeAudioSpec aOutSwrSpec_;
    AVFrame *aSwrInFrame_= nullptr;
    /** aSwrBUfferSize:重采样后音频的大小*/
    int aSwrBufferIdx_ = 0,aSwrBUfferSize_ = 0;
    int volumn_ = 100;
    bool isMute_ = false;
    bool aCanFree_ = false;
    /**音频时钟*/
    double aTimes_ = 0.0f;

    int setupAudio(void);
    //初始重采样
    int initAuidoSwr();
    int initAuidoSDL();
    void addAudioPkt(AVPacket pkt);
    void clearAudioPkts();
    /**接收sdl播放的数据*/
    static void sdlAudioDataCallBack(void *userData,Uint8 * stream, int len);
    void sdlAudioDataCB(Uint8 * stream, int len);
    int decodeAudioData();
    void freeAudioSource();


    /**视频频属性和方法**/
    AVCodecContext *vDecodecCtx_;
    SwsContext   *vSwsCtx_;
    //流的标记
    AVStream *vStream_ = nullptr;
    AVFrame *vSwsInFrame_= nullptr,*vSwsoutFrame_= nullptr;
    std::unique_ptr<std::list<AVPacket>> vPackets_;
    std::unique_ptr<LYMCodationLock> vCondLock_;
     DecodeVideoSpec vOutSpec_;
     bool vCanFree_ = false;
     /**音频时钟 当前视频包对应的时间*/
     double vTimes_ = 0.0f;

    int setupVideo(void);
    void addVideoPkt(AVPacket pkt);
    void clearVideoPkts();
    int initVideoSDL();
    int initVideoSws();
    void freeVideoSource();
    void decodeVideoData();


    /**当前状态**/
    PlayState state_ = Stopped;
    char fileName_[512];
    bool fmtCtxCanFree_ = false;
    AVFormatContext *formatcontext_;

    std::function<void (LYMVideoPlayer *player)> initFinish_ = nullptr;

    /**改变状态*/
    void SetState(PlayState stateT);
    void readFile(void);

    int ininDeCodec(AVMediaType type,AVCodecContext **decodecCtx,AVStream **stream);

    void freeSouce();
    void fataerror();

};

#endif // LYMVIDEOPLAYER_H
