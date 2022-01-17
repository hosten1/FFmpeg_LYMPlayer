#include "CostumSlider.h"
#include <QDebug>
#include <QStyle>
#include <QMouseEvent>

CostumSlider::CostumSlider(QWidget *parent) : QSlider(parent)
{
  qDebug() << ":CostumSlider(QWidget *parent)";
}
void CostumSlider::mousePressEvent(QMouseEvent *ev){
   int valueI = QStyle::sliderValueFromPosition(minimum(),maximum(),ev->pos().x(),width());
  setValue(valueI);
    QSlider::mousePressEvent(ev);
}
