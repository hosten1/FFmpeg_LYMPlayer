QT       += core gui

QT += quick widgets opengl

CONFIG += c++11

# You can make your code fail to compile if it uses deprecated APIs.
# In order to do so, uncomment the following line.
#DEFINES += QT_DISABLE_DEPRECATED_BEFORE=0x060000    # disables all the APIs deprecated before Qt 6.0.0

QMAKE_INFO_PLIST += $$PWD/VideoPlayer.entitlements
SOURCES += \
    Costumslider.cpp \
    LYMVideoPlayer_audio.cpp \
    LYMVideoPlayer_video.cpp \
    lymcodationlock.cpp \
    lymvideoplayer.cpp \
    main.cpp \
    mainwindow.cpp \
    OpenGLDisplay.cpp\
    videorenderwidget.cpp

HEADERS += \
    CostumSlider.h \
    lymcodationlock.h \
    lymvideoplayer.h \
    mainwindow.h \
    OpenGLDisplay.h\
    videorenderwidget.h

FORMS += \
    mainwindow.ui

# Default rules for deployment.
qnx: target.path = /tmp/$${TARGET}/bin
else: unix:!android: target.path = /opt/$${TARGET}/bin
!isEmpty(target.path): INSTALLS += target

macx: LIBS += -L$$PWD/lib/ -lavutil.56.51.100 \
                           -lavcodec.58.91.100 \
                           -lavdevice.58.10.100 \
                           -lavfilter.7.85.100 \
                           -lavformat.58.45.100 \
                           -lswresample.3.7.100 \
                           -lswscale.5.7.100 \
                           -lpostproc.55.7.100 \
                           -lSDL2-2.0.0



INCLUDEPATH += $$PWD/include
DEPENDPATH += $$PWD/include
INCLUDEPATH += $$PWD/include/SDL2
DEPENDPATH += $$PWD/include/SDL2

win32:CONFIG(release, debug|release): LIBS += -L$$PWD/../../../../../../usr/local/Cellar/qt/6.2.2/lib/release/ -lQtOpenGLWidgets
else:win32:CONFIG(debug, debug|release): LIBS += -L$$PWD/../../../../../../usr/local/Cellar/qt/6.2.2/lib/debug/ -lQtOpenGLWidgets
else:mac: LIBS += -F$$PWD/../../../../../../usr/local/Cellar/qt/6.2.2/lib/ -framework QtOpenGLWidgets
else:unix: LIBS += -L$$PWD/../../../../../../usr/local/Cellar/qt/6.2.2/lib/ -lQtOpenGLWidgets

INCLUDEPATH += $$PWD/../../../../../../usr/local/Cellar/qt/6.2.2/include
DEPENDPATH += $$PWD/../../../../../../usr/local/Cellar/qt/6.2.2/include
