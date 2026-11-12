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

class DockBackend;

class DockView : public QQuickView
{
    Q_OBJECT

public:
    explicit DockView(Plasma::Corona *corona, QWindow *parent = nullptr);
    ~DockView() override;

    void setApplet(Plasma::Applet *applet);
    void showConfigurationInterface();
    DockBackend *backend() const { return m_backend; }

protected:
    void resizeEvent(QResizeEvent *event) override;
    void showEvent(QShowEvent *event) override;
    void hideEvent(QHideEvent *event) override;
    void closeEvent(QCloseEvent *event) override;

Q_SIGNALS:
    void surfaceDismissed();

public Q_SLOTS:
    void updateMask();
    void updateExclusiveZone();
    void updateLayerWindow();
    void updateScreenGeometry();
    void adaptToScreen();
    void onPrepareForSleep(bool sleeping);

private:
    Plasma::Corona *m_corona = nullptr;
    Plasma::Applet *m_applet = nullptr;
    QPointer<PlasmaQuick::AppletQuickItem> m_appletInterface;
    QPointer<PlasmaQuick::ConfigView> m_configView;
    LayerShellQt::Window *m_layerWindow = nullptr;
    DockBackend *m_backend = nullptr;
    int m_dockCanvasHeight = 128;
QRegion m_lastMaskRegion;
    QMetaObject::Connection m_screenGeometryConnection;
    QMetaObject::Connection m_screenResolutionConnection;
};
