#ifndef OPENGLDISPLAY_H
#define OPENGLDISPLAY_H

#include <QtOpenGLWidgets/QOpenGLWidget>
#include <QOpenGLFunctions>
#include <QScopedPointer>
#include <QException>
#include <QWidget>
#include "lymvideoplayer.h"


class OpenGLDisplay : public QOpenGLWidget, public QOpenGLFunctions
{
public:
    explicit OpenGLDisplay(QWidget* parent = nullptr);
    ~OpenGLDisplay();

    void InitDrawBuffer(unsigned bsize);
    void DisplayVideoFrame(unsigned char *data, int frameWidth, int frameHeight);
public slots:
    void onPlayerFrameDecode(LYMVideoPlayer *player,uint8_t *data ,LYMVideoPlayer::DecodeVideoSpec &videoSpec);
    void onPlayerStateChanged(LYMVideoPlayer *videoPlayer);

protected:
    void initializeGL() override;
    void resizeGL(int w, int h) override;
    void paintGL() override;

private:
    struct OpenGLDisplayImpl;
    QScopedPointer<OpenGLDisplayImpl> impl;
    bool isInit_ = false;
};

/***********************************************************************/

class OpenGlException: public QException
{
public:
     void raise() const { throw *this; }
     OpenGlException *clone() const { return new OpenGlException(*this); }
};

#endif // OPENGLDISPLAY_H
