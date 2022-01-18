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
    void onPlayerFrameDecode(LYMVideoPlayer *player,uint8_t *data,int dataLen ,LYMVideoPlayer::DecodeVideoSpec &videoSpec);
private:
    QImage *img_ = nullptr;
    QRect rect_;

  void paintEvent(QPaintEvent *event) override;

signals:

};

#endif // VIDEORENDERWIDGET_H
