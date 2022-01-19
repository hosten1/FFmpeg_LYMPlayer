#include "mainwindow.h"
#include "ui_mainwindow.h"
#include <QFileDialog>
#include <QDebug>
#include <qstring.h>
#include <QMessageBox>
#include "videorenderwidget.h"


MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent)
    , ui(new Ui::MainWindow)
{
    ui->setupUi(this);
   // 注册信号的参数类型 保证能发出信号
    qRegisterMetaType<LYMVideoPlayer::DecodeVideoSpec>("DecodeVideoSpec&");
     qRegisterMetaType<LYMVideoPlayer>("LYMVideoPlayer");
    //创建播放器
    player_ = make_unique<LYMVideoPlayer>();

    ui->volumeSlider->setRange(LYMVideoPlayer::LYMVolumnRange::Min,LYMVideoPlayer::LYMVolumnRange::Max);
    ui->volumeSlider->setValue(LYMVideoPlayer::LYMVolumnRange::Max);
    //连接槽函数
    connect(player_.get(),&LYMVideoPlayer::statsChanged,
            this,&MainWindow::onPlayerStateChanged);
    connect(player_.get(),&LYMVideoPlayer::playerFailed,
            this,&MainWindow::onPlayerStateFailed);
    connect(player_.get(),&LYMVideoPlayer::frameDecode,
            ui->videoWidget,&videoRenderWidget::onPlayerFrameDecode);
    connect(player_.get(),&LYMVideoPlayer::statsChanged,
             ui->videoWidget,&videoRenderWidget::onPlayerStateChanged);
    connect(player_.get(),&LYMVideoPlayer::InitFinishd,
             this,&MainWindow::onInitFinishd);
    connect(player_.get(),&LYMVideoPlayer::timePlayerChanged,
             this,&MainWindow::onTimePlayerChanged);
    connect(ui->currentSlider,&CostumSlider::clickedValueChange,
             this,&MainWindow::onSliderClickValueChange);
    ui->playStackedWidget->setCurrentWidget(ui->openFIlePage);
}

MainWindow::~MainWindow()
{
    delete ui;
}
void MainWindow::closeEvent(QCloseEvent *event){
    player_ -> stop();
    qDebug()<<"closeEvent ";
}
void MainWindow::onInitFinishd(LYMVideoPlayer *player){
    int64_t micseconds =  player->getDuration();
    qDebug()<<"onInitFinishd: "<< micseconds;

    ui->currentSlider->setRange(0,100);

    ui->durationLab->setText(getdurationText(micseconds));
}
void MainWindow::onSliderClickValueChange(CostumSlider *slider){
    if(player_->getState() == LYMVideoPlayer::Stopped)return;
   if(slider == ui->currentSlider){
       /*
        * currentIdx       GetCurrentTime
        *  __________   =   _______

        *  maximum         getDuration
 */
       int currentTimer =  (slider->value() * 1.0f / (ui->currentSlider->maximum() )) *  (player_->getDuration()*1.0f);
       player_->SetCurrentTime(currentTimer);
   }
}
void MainWindow::onPlayerStateFailed(LYMVideoPlayer *videoPlayer){
    QMessageBox::critical(nullptr,"提示","播放失败！");
}
void MainWindow::onPlayerStateChanged(LYMVideoPlayer * videoPlayer){
    if(!videoPlayer)return;
    qDebug()<<"槽函数回调: "<<videoPlayer->getState();
    LYMVideoPlayer::PlayState state = videoPlayer->getState();
    if(state == LYMVideoPlayer::Playing){
        ui->playBtn->setText("暂停");
    }else{
        ui->playBtn->setText("播放");
    }

    if(state == LYMVideoPlayer::Stopped){
        ui->playBtn->setEnabled(false);
        ui->stopBtn->setEnabled(false);
        ui->currentSlider->setEnabled(false);
        ui->volumeSlider->setEnabled(false);
        ui->silenceBtn->setEnabled(false);


        ui->durationLab->setText(getdurationText(0));
        ui->currentSlider->setValue(0);
        //显示打开文件的页面
        ui->playStackedWidget->setCurrentWidget(ui->openFIlePage);

    }else{
        ui->playBtn->setEnabled(true);
        ui->stopBtn->setEnabled(true);
        ui->currentSlider->setEnabled(true);
        ui->volumeSlider->setEnabled(true);
        ui->silenceBtn->setEnabled(true);
        //显示播放视频的页面
        ui->playStackedWidget->setCurrentWidget(ui->videoPlayPage);
    }
}
void MainWindow::onTimePlayerChanged(LYMVideoPlayer *player,double time){
      if(player->GetCurrentTime() == 0) return;
      /*
       * currentIdx       GetCurrentTime
       *  __________   =   _______

       *  maximum         getDuration
*/
     double totalTime = (player->getDuration()*1.0f);
     int currentIdx =  (player->GetCurrentTime()*1.0f / totalTime ) * (ui->currentSlider->maximum()) ;
//     qDebug()<<"onTimePlayerChanged: " << " totalTime= "<<totalTime
//            << "scale = "<< (player->GetCurrentTime()*1.0f / totalTime )
//                                        << " currentSlider  "<<ui->currentSlider->maximum()
//                                        << " currentT " <<currentIdx;

      ui->currentSlider->setValue(currentIdx);
      ui->currentLab->setText(getdurationText(player->GetCurrentTime()));
}
void MainWindow::on_stopBtn_clicked()
{
    player_->stop();
    //    int count = ui->playStackedWidget->count();
    //    int idx = ui->playStackedWidget->currentIndex();
    //    //设置当前的画面  点击按钮后可以切换页面
    //  ui->playStackedWidget->setCurrentIndex(++idx % count);
}

void MainWindow::on_openFileBtn_clicked()
{
    //     /*"audio(*.mp3 *.aac);;video(*.mp4 *.mkv)"*/"
    QString name = QFileDialog::getOpenFileName(nullptr,
                                                "选择多媒体文件",
                                                "/Users/luoyongmeng/Downloads/",
                                                "音视频文件(*.mp4 *.mkv *.mp3 *.aac)");
    qDebug()<<"打开的文件是: "<<name;
    if(name.isEmpty())return;
    player_->SetFileName(name.toUtf8().toStdString());
    player_->play();

}

void MainWindow::on_playBtn_clicked()
{
    LYMVideoPlayer::PlayState state = player_->getState();
    if(state == LYMVideoPlayer::Playing){
        player_->pause();
    }else{
        player_->play();
    }
}

void MainWindow::on_currentSlider_valueChanged(int value)
{
//    qDebug()<<"on_currentSlider_valueChanged " << value;
//    ui->currentLab->setText(getdurationText(value));
}

void MainWindow::on_silenceBtn_clicked()
{
   if(player_->isMuteFun()){
      player_->setMute(false);
      ui->silenceBtn->setText("静音");
   }else{
      player_->setMute(true);
      ui->silenceBtn->setText("恢复");
   }
}

void MainWindow::on_volumeSlider_valueChanged(int value)
{
    ui->volumeLabel->setText(QString("%1").arg(value));
    player_->setVolumn(value);
    qDebug()<<"on_volumeSlider_valueChanged " << value;
}

QString MainWindow::getdurationText(int64_t value){
    int64_t seconds = value;
    int h =  seconds / (60*60);
    int min = (seconds % (60*60))/60;
    int sec = seconds % 60;
    QString hStr = QString("0%1").arg(h).right(2);
    QString minStr = QString("0%1").arg(min).right(2);
    QString secStr = QString("0%1").arg(sec).right(2);
    QString duraStr = QString("%1:%2:%3").arg(hStr).arg(minStr).arg(secStr);
    return duraStr;
}
