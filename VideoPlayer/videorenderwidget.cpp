#include "videorenderwidget.h"
#include <QDebug>
#include <QPainter>
#include <QRect>
#include <iostream>


videoRenderWidget::videoRenderWidget(QWidget *parent) : QWidget(parent)
{
    qDebug() << ":videoRenderWidget(QWidget *parent)";
}
videoRenderWidget::~videoRenderWidget(){

}
void videoRenderWidget::paintEvent(QPaintEvent *event){
    if(img_ == nullptr)return;

    QPainter(this).drawImage(QRect(0,0,width(),height()),*img_);
}
void videoRenderWidget::onPlayerFrameDecode(LYMVideoPlayer *player,uint8_t *data,int dataLen ,LYMVideoPlayer::DecodeVideoSpec videoSpec){

    if(img_){
        delete  img_;
        img_ = nullptr;
    }
    if(data != nullptr){
         img_ = new QImage((uchar*)data,videoSpec.width,videoSpec.height,QImage::Format_RGB888);
    }
    update();



//   std::cout<< "sws_scale(): " << &(data) << "  imageSize ="<<dataLen
//            << "  videoSpec.width =" <<videoSpec.width
//            <<"  videoSpec.width =" <<videoSpec.height<<std::endl;
}
