#ifndef COSTUMSLIDER_H
#define COSTUMSLIDER_H

#include <QSlider>

class CostumSlider : public QSlider
{
    Q_OBJECT
public:
    explicit CostumSlider(QWidget *parent = nullptr);
signals:
private:
   void mousePressEvent(QMouseEvent *ev) override;
};

#endif // COSTUMSLIDER_H
