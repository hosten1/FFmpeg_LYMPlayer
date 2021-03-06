#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QMainWindow>
#include "lymvideoplayer.h"


class CostumSlider;
using namespace std;
QT_BEGIN_NAMESPACE
namespace Ui { class MainWindow; }
QT_END_NAMESPACE

class MainWindow : public QMainWindow
{
    Q_OBJECT

public:
    MainWindow(QWidget *parent = nullptr);
    ~MainWindow();

private slots:
    void onPlayerStateChanged(LYMVideoPlayer *videoPlayer);
     void onPlayerStateFailed(LYMVideoPlayer *videoPlayer);
     void onTimePlayerChanged(LYMVideoPlayer *player,double time);
     void onInitFinishd(LYMVideoPlayer *player);
     void onSliderClickValueChange(CostumSlider *slider);



    void on_stopBtn_clicked();

    void on_openFileBtn_clicked();

    void on_playBtn_clicked();

    void on_currentSlider_valueChanged(int value);

    void on_silenceBtn_clicked();

    void on_volumeSlider_valueChanged(int value);
protected:
    void closeEvent(QCloseEvent *event) override;
private:
    Ui::MainWindow *ui;
    unique_ptr<LYMVideoPlayer> player_;
    QString getdurationText(int64_t value);

};
#endif // MAINWINDOW_H
