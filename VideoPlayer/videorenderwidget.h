#ifndef VIDEORENDERWIDGET_H
#define VIDEORENDERWIDGET_H

#include <QWidget>
#include "lymvideoplayer.h"

class QImage;
class QRect;

class videoRenderWidget : public QWidget
{
    Q_OBJECT
public:
    explicit videoRenderWidget(QWidget *parent = nullptr);
    ~videoRenderWidget();
public slots:
    void onPlayerFrameDecode(LYMVideoPlayer *player,uint8_t *data ,LYMVideoPlayer::DecodeVideoSpec &videoSpec);
    void onPlayerStateChanged(LYMVideoPlayer *videoPlayer);
private:
    QImage *img_ = nullptr;
    QRect rect_;

  void paintEvent(QPaintEvent *event) override;
  void freeImg();
signals:

};

#endif // VIDEORENDERWIDGET_H
