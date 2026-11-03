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

    if (auto screen = QGuiApplication::primaryScreen()) {
        const QRect geom = screen->geometry();
        setPosition(QPoint(geom.x(), geom.y() + geom.height() - m_dockCanvasHeight));
        resize(geom.width(), m_dockCanvasHeight);
        connect(screen, &QScreen::geometryChanged, this, &DockView::updateScreenGeometry);
    }

    m_layerWindow = LayerShellQt::Window::get(this);
    if (m_layerWindow) {
        m_layerWindow->setScope(QStringLiteral("macos-dock"));
        m_layerWindow->setLayer(LayerShellQt::Window::LayerTop);
        m_layerWindow->setAnchors(LayerShellQt::Window::Anchors(LayerShellQt::Window::AnchorBottom | LayerShellQt::Window::AnchorLeft | LayerShellQt::Window::AnchorRight));
        m_layerWindow->setExclusiveEdge(LayerShellQt::Window::AnchorBottom);
        m_layerWindow->setExclusiveZone(56);
        m_layerWindow->setDesiredSize(QSize(0, m_dockCanvasHeight));
        m_layerWindow->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityNone);
        m_layerWindow->setCloseOnDismissed(false);
    }
}

DockView::~DockView() = default;

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

void DockView::updateScreenGeometry()
{
    auto screen = this->screen() ? this->screen() : QGuiApplication::primaryScreen();
    if (!screen) {
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
    }

    updateMask();
}

void DockView::updateMask()
{
    if (!m_appletInterface) {
        setMask(QRect());
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
    const int maskH = height() > 0 ? height() : m_dockCanvasHeight;

    setMask(QRegion(maskX, 0, maskW, maskH));
}
