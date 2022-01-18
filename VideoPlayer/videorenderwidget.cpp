#include "videorenderwidget.h"
#include <QDebug>
#include <QPainter>
#include <QRect>
#include <iostream>
#include <QImage>

videoRenderWidget::videoRenderWidget(QWidget *parent) : QWidget(parent)
{
    qDebug() << ":videoRenderWidget(QWidget *parent)";
}
videoRenderWidget::~videoRenderWidget(){
   freeImg();
}
void videoRenderWidget::paintEvent(QPaintEvent *event){
    if(img_ == nullptr)return;

    QPainter(this).drawImage(rect_,*img_);
}
void videoRenderWidget::onPlayerStateChanged(LYMVideoPlayer *videoPlayer){
     if(videoPlayer->getState() != LYMVideoPlayer::Stopped)return;
     freeImg();
     update();

}
void videoRenderWidget::onPlayerFrameDecode(LYMVideoPlayer *player,uint8_t *data,int dataLen ,LYMVideoPlayer::DecodeVideoSpec &videoSpec){

    freeImg();
    if(data != nullptr){
        img_ = new QImage((uchar*)data,videoSpec.width,videoSpec.height,QImage::Format_RGB888);
        //计算视频画面的尺寸

        int h = height();
        int w = width();
        int dx = 0;
        int dy = 0;
        int dw = videoSpec.width;
        int dh = videoSpec.height;
        // 计算目标尺寸
        if(dw > w || dh > h){//缩放
            if(dw * h > w * dh){
                dh = w *dh / dw;
                dw = w;
            }else {
                dw = h * dw / dh;
                dh = h;
            }

        }
        dx = (w - dw) >> 1;
        dy = (h - dh) >> 1;
        rect_ = QRect(dx,dy,dw,dh);
    }
     update();



//   std::cout<< "sws_scale(): " << &(data) << "  imageSize ="<<dataLen
//            << "  videoSpec.width =" <<videoSpec.width
//            <<"  videoSpec.width =" <<videoSpec.height<<std::endl;
}
void videoRenderWidget::freeImg(){
    if(img_){
        delete  img_;
        img_ = nullptr;
    }
}
