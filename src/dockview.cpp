/*
    SPDX-FileCopyrightText: 2026 Cesar <yugurta@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "dockview.h"
#include "dockcorona.h"

#include <QGuiApplication>
#include <QScreen>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickItem>
#include <QResizeEvent>
#include <QShowEvent>
#include <QDBusConnection>
#include <QTimer>
#include <QDebug>

#include <Plasma/Applet>
#include <Plasma/Containment>
#include <Plasma/Corona>
#include <plasmaquick/appletquickitem.h>
#include <plasmaquick/configview.h>

#include <LayerShellQt/Window>
#include "dockbackend.h"

DockView::DockView(Plasma::Corona *corona, QWindow *parent)
    : QQuickView(parent)
    , m_corona(corona)
{
    setColor(Qt::transparent);

    m_backend = DockBackend::instance();
    m_backend->setLaunchpadCallback([this]() {
        if (auto c = qobject_cast<DockCorona *>(m_corona)) {
            c->toggleLaunchpad();
        }
    });
    rootContext()->setContextProperty(QStringLiteral("dockBackend"), m_backend);

    m_layerWindow = LayerShellQt::Window::get(this);
    if (m_layerWindow) {
        m_layerWindow->setScope(QStringLiteral("macos-dock"));
        m_layerWindow->setLayer(LayerShellQt::Window::LayerTop);
        m_layerWindow->setDesiredSize(QSize(0, m_dockCanvasHeight));
        m_layerWindow->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityNone);
        m_layerWindow->setCloseOnDismissed(true);
        updateLayerWindow();
        updateExclusiveZone();
    }

    adaptToScreen();

    // Monitor screen lifecycle for DPMS resume, multi-monitor, and resolution changes
    connect(qGuiApp, &QGuiApplication::screenAdded, this, [this](QScreen *s) {
        qDebug() << "DockView: Screen added:" << (s ? s->name() : QStringLiteral("null"));
        QTimer::singleShot(250, this, &DockView::adaptToScreen);
        QTimer::singleShot(1000, this, &DockView::adaptToScreen);
    });

    connect(qGuiApp, &QGuiApplication::screenRemoved, this, [this](QScreen *s) {
        qDebug() << "DockView: Screen removed:" << (s ? s->name() : QStringLiteral("null"));
        QTimer::singleShot(250, this, &DockView::adaptToScreen);
    });

    connect(qGuiApp, &QGuiApplication::primaryScreenChanged, this, [this](QScreen *s) {
        qDebug() << "DockView: Primary screen changed:" << (s ? s->name() : QStringLiteral("null"));
        QTimer::singleShot(250, this, &DockView::adaptToScreen);
    });

    // Listen to logind PrepareForSleep signal to immediately restore surface when waking from suspend
    QDBusConnection::systemBus().connect(
        QStringLiteral("org.freedesktop.login1"),
        QStringLiteral("/org/freedesktop/login1"),
        QStringLiteral("org.freedesktop.login1.Manager"),
        QStringLiteral("PrepareForSleep"),
        this,
        SLOT(onPrepareForSleep(bool))
    );

    // Watchdog timer to ensure dock is permanently visible
    auto watchdogTimer = new QTimer(this);
    watchdogTimer->setInterval(8000);
    connect(watchdogTimer, &QTimer::timeout, this, [this]() {
        auto s = QGuiApplication::primaryScreen();
        if (s && !s->name().contains(QLatin1String("placeholder"), Qt::CaseInsensitive) && s->geometry().width() > 0) {
            if (!isVisible() || width() <= 0 || height() <= 0) {
                qWarning() << "DockView: Watchdog detected dock hidden or unmapped, re-adapting to screen!";
                adaptToScreen();
            }
        }
    });
    watchdogTimer->start();
}

DockView::~DockView()
{
    if (m_appletInterface) {
        m_appletInterface->setParentItem(nullptr);
    }
}

void DockView::setApplet(Plasma::Applet *applet)
{
    m_applet = applet;
    if (!m_applet) {
        return;
    }

    m_appletInterface = PlasmaQuick::AppletQuickItem::itemForApplet(applet);
    if (!m_appletInterface) {
        return;
    }

    if (auto engine = qmlEngine(m_appletInterface)) {
        engine->rootContext()->setContextProperty(QStringLiteral("dockBackend"), m_backend);
    }
    m_appletInterface->setProperty("dockBackend", QVariant::fromValue(static_cast<QObject *>(m_backend)));

    m_appletInterface->setParentItem(contentItem());
    m_appletInterface->setX(0);
    m_appletInterface->setY(0);
    m_appletInterface->setProperty("isStandaloneView", true);
    m_appletInterface->setVisible(true);
    m_appletInterface->setProperty("hideOnWindowDeactivate", false);

    const auto updateMaskMethod = metaObject()->method(metaObject()->indexOfSlot("updateMask()"));
    const auto updateZoneMethod = metaObject()->method(metaObject()->indexOfSlot("updateExclusiveZone()"));

    // Track dock capsule bounds to set accurate input mask
    const auto metaObj = m_appletInterface->metaObject();
    const int capsuleXIdx = metaObj->indexOfProperty("dockCapsuleX");
    if (capsuleXIdx >= 0) {
        const auto prop = metaObj->property(capsuleXIdx);
        if (prop.hasNotifySignal()) {
            connect(m_appletInterface.data(), prop.notifySignal(), this, updateMaskMethod);
        }
    }

    const int capsuleWIdx = metaObj->indexOfProperty("dockCapsuleWidth");
    if (capsuleWIdx >= 0) {
        const auto prop = metaObj->property(capsuleWIdx);
        if (prop.hasNotifySignal()) {
            connect(m_appletInterface.data(), prop.notifySignal(), this, updateMaskMethod);
        }
    }

    // Dynamically track dock thickness (iconSize + verticalPadding * 2 + elevation)
    // so maximized windows stop cleanly above the dock capsule without overlapping
    const int thicknessIdx = metaObj->indexOfProperty("targetThickness");
    if (thicknessIdx >= 0) {
        const auto prop = metaObj->property(thicknessIdx);
        if (prop.hasNotifySignal()) {
            connect(m_appletInterface.data(), prop.notifySignal(), this, updateZoneMethod);
        }
    }

    const int visModeIdx = metaObj->indexOfProperty("visibilityMode");
    if (visModeIdx >= 0) {
        const auto prop = metaObj->property(visModeIdx);
        if (prop.hasNotifySignal()) {
            connect(m_appletInterface.data(), prop.notifySignal(), this, updateZoneMethod);
        }
    }

    const int hiddenIdx = metaObj->indexOfProperty("isDockHidden");
    if (hiddenIdx >= 0) {
        const auto prop = metaObj->property(hiddenIdx);
        if (prop.hasNotifySignal()) {
            connect(m_appletInterface.data(), prop.notifySignal(), this, updateMaskMethod);
        }
    }

    updateExclusiveZone();

    if (applet->containment()) {
        connect(applet->containment(), &Plasma::Containment::configureRequested, this, [this](Plasma::Applet *a) {
            if (a == m_applet) {
                showConfigurationInterface();
            }
        });
    }

    updateScreenGeometry();
}

void DockView::showConfigurationInterface()
{
    if (!m_applet) {
        return;
    }
    if (m_configView) {
        m_configView->raise();
        m_configView->requestActivate();
        return;
    }
    m_configView = new PlasmaQuick::ConfigView(m_applet);
    m_configView->init();
    m_configView->show();
}

void DockView::resizeEvent(QResizeEvent *event)
{
    QQuickView::resizeEvent(event);
    if (m_appletInterface) {
        m_appletInterface->setX(0);
        m_appletInterface->setY(0);
        m_appletInterface->setSize(event->size());
    }
    updateMask();
}

void DockView::showEvent(QShowEvent *event)
{
    QQuickView::showEvent(event);
    updateScreenGeometry();
}

void DockView::hideEvent(QHideEvent *event)
{
    QQuickView::hideEvent(event);
    qDebug() << "DockView: hideEvent triggered";
    Q_EMIT surfaceDismissed();
}

void DockView::closeEvent(QCloseEvent *event)
{
    QQuickView::closeEvent(event);
    qDebug() << "DockView: closeEvent triggered (surface dismissed by compositor)";
    Q_EMIT surfaceDismissed();
}

void DockView::onPrepareForSleep(bool sleeping)
{
    if (!sleeping) {
        qDebug() << "DockView: System woke from sleep, restoring dock surface";
        QTimer::singleShot(300, this, &DockView::adaptToScreen);
        QTimer::singleShot(1200, this, &DockView::adaptToScreen);
    }
}

void DockView::adaptToScreen()
{
    auto targetScreen = QGuiApplication::primaryScreen();
    if (!targetScreen) {
        const auto screens = QGuiApplication::screens();
        if (!screens.isEmpty()) {
            targetScreen = screens.first();
        }
    }

    if (!targetScreen) {
        return;
    }

    // Ignore placeholder/empty screens during DPMS sleep transition
    if (targetScreen->name().contains(QLatin1String("placeholder"), Qt::CaseInsensitive)
        || targetScreen->geometry().width() <= 0
        || targetScreen->geometry().height() <= 0) {
        return;
    }

    // Re-bind geometry notifications
    disconnect(m_screenGeometryConnection);
    m_screenGeometryConnection = connect(targetScreen, &QScreen::geometryChanged, this, &DockView::updateScreenGeometry);

    disconnect(m_screenResolutionConnection);
    m_screenResolutionConnection = connect(targetScreen, &QScreen::availableGeometryChanged, this, &DockView::updateScreenGeometry);

    if (this->screen() != targetScreen) {
        setScreen(targetScreen);
    }

    if (m_layerWindow) {
        m_layerWindow->setScreen(targetScreen);
        m_layerWindow->setDesiredSize(QSize(targetScreen->geometry().width(), m_dockCanvasHeight));
        m_layerWindow->setLayer(LayerShellQt::Window::LayerTop);
        m_layerWindow->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityNone);
        m_layerWindow->setCloseOnDismissed(true);
        updateLayerWindow();
        updateExclusiveZone();
    }

    updateScreenGeometry();

    if (!isVisible()) {
        show();
    }
    requestUpdate();
}

void DockView::updateScreenGeometry()
{
    auto screen = this->screen() ? this->screen() : QGuiApplication::primaryScreen();
    if (!screen || screen->geometry().isEmpty()) {
        return;
    }

    const QRect geom = screen->geometry();
    const QPoint dockPos(geom.x(), geom.y() + geom.height() - m_dockCanvasHeight);

    setPosition(dockPos);
    resize(geom.width(), m_dockCanvasHeight);

    if (m_layerWindow) {
        m_layerWindow->setDesiredSize(QSize(geom.width(), m_dockCanvasHeight));
    }

    if (m_appletInterface) {
        m_appletInterface->setX(0);
        m_appletInterface->setY(0);
        m_appletInterface->setSize(QSizeF(geom.width(), m_dockCanvasHeight));
        m_appletInterface->setVisible(true);
    }

    updateMask();
}

void DockView::updateMask()
{
    if (!m_appletInterface) {
        setMask(QRect());
        return;
    }

    const int totalH = height() > 0 ? height() : m_dockCanvasHeight;
    const QVariant hiddenVar = m_appletInterface->property("isDockHidden");
    const bool isHidden = hiddenVar.isValid() && hiddenVar.toBool();

    if (isHidden) {
        // Thin trigger zone at the very bottom edge of the screen
        const int triggerHeight = 4;
        setMask(QRegion(0, totalH - triggerHeight, width() > 0 ? width() : 1920, triggerHeight));
        return;
    }

    const QVariant wVar = m_appletInterface->property("dockCapsuleWidth");
    const QVariant xVar = m_appletInterface->property("dockCapsuleX");
    if (!wVar.isValid() || !xVar.isValid() || wVar.toReal() <= 0) {
        setMask(QRect());
        return;
    }

    const int capsuleW = wVar.toInt();
    const int capsuleX = xVar.toInt();

    // Generous horizontal headroom for magnification blast radius
    const int margin = 80;
    const int maskX = qMax(0, capsuleX - margin);
    const int maskW = capsuleW + margin * 2;

    setMask(QRegion(maskX, 0, maskW, totalH));
}

void DockView::updateLayerWindow()
{
    if (!m_layerWindow) {
        return;
    }
    // Centralized layer-shell anchor setup (ported from Plasma PanelView::updateLayerWindow).
    // Dock is always a bottom horizontal panel: anchor bottom + left + right (Fitts law).
    LayerShellQt::Window::Anchors anchors;
    anchors.setFlag(LayerShellQt::Window::AnchorBottom);
    anchors.setFlag(LayerShellQt::Window::AnchorLeft);
    anchors.setFlag(LayerShellQt::Window::AnchorRight);
    m_layerWindow->setAnchors(anchors);
    m_layerWindow->setExclusiveEdge(LayerShellQt::Window::AnchorBottom);
    m_layerWindow->setMargins(QMargins(0, 0, 0, 0));
}

void DockView::updateExclusiveZone()
{
    if (!m_layerWindow) {
        return;
    }

    int zone = 74; // Fallback: 48 (icon) + 12 (verticalPadding*2) + 12 (elevation) + 2 (breathing gap)
    if (m_appletInterface) {
        const QVariant visModeVar = m_appletInterface->property("visibilityMode");
        const int visMode = visModeVar.isValid() ? visModeVar.toInt() : 0;

        if (visMode == 0) { // AlwaysVisible
            const QVariant thicknessVar = m_appletInterface->property("targetThickness");
            if (thicknessVar.isValid() && thicknessVar.toInt() > 0) {
                // targetThickness represents (iconSize + verticalPadding * 2 + elevation).
                // Add a subtle 2px breathing gap so maximized window frames sit cleanly above the glass border without clipping.
                zone = thicknessVar.toInt() + 2;
            }
        } else {
            // AutoHide (1), DodgeWindows (2), WindowsGoBelow (3) do NOT reserve space
            zone = 0;
        }
    }

    m_layerWindow->setExclusiveEdge(LayerShellQt::Window::AnchorBottom);
    m_layerWindow->setExclusiveZone(zone);
}
