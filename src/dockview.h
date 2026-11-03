/*
    SPDX-FileCopyrightText: 2026 Cesar <yugurta@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <QPointer>
#include <QQuickView>
#include <QRect>

namespace Plasma
{
class Applet;
class Corona;
}

namespace PlasmaQuick
{
class AppletQuickItem;
class ConfigView;
}

namespace LayerShellQt
{
class Window;
}

class DockView : public QQuickView
{
    Q_OBJECT

public:
    explicit DockView(Plasma::Corona *corona, QWindow *parent = nullptr);
    ~DockView() override;

    void setApplet(Plasma::Applet *applet);
    void showConfigurationInterface();

protected:
    void resizeEvent(QResizeEvent *event) override;
    void showEvent(QShowEvent *event) override;

public Q_SLOTS:
    void updateMask();
    void updateScreenGeometry();

private:
    Plasma::Corona *m_corona = nullptr;
    Plasma::Applet *m_applet = nullptr;
    QPointer<PlasmaQuick::AppletQuickItem> m_appletInterface;
    QPointer<PlasmaQuick::ConfigView> m_configView;
    LayerShellQt::Window *m_layerWindow = nullptr;
    int m_dockCanvasHeight = 128;
};
