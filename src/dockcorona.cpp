/*
    SPDX-FileCopyrightText: 2026 Cesar <yugurta@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "dockcorona.h"
#include "dockview.h"
#include "dockbackend.h"

#include <QGuiApplication>
#include <QScreen>
#include <QDebug>
#include <QDBusConnection>
#include <QTimer>

#include <KPackage/PackageLoader>
#include <Plasma/PluginLoader>
#include <plasmaquick/appletquickitem.h>

DockCorona::DockCorona(QObject *parent)
    : Plasma::Corona(parent)
{
    KPackage::Package package = KPackage::PackageLoader::self()->loadPackage(QStringLiteral("Plasma/Shell"));
    package.setPath(QStringLiteral("org.kde.plasma.desktop"));
    setKPackage(package);
}

DockCorona::~DockCorona() = default;

QRect DockCorona::screenGeometry(uint id) const
{
    const auto screens = QGuiApplication::screens();
    if (id < static_cast<uint>(screens.size())) {
        return screens.at(id)->geometry();
    }
    if (auto s = QGuiApplication::primaryScreen()) {
        return s->geometry();
    }
    return {};
}

void DockCorona::init()
{
    loadLayout(QStringLiteral("macosdockrc"));

    if (containments().isEmpty()) {
        m_containment = createContainment(QStringLiteral("empty"));
        if (m_containment) {
            m_containment->setLocation(Plasma::Types::BottomEdge);
            m_containment->setFormFactor(Plasma::Types::Horizontal);
            saveLayout(QStringLiteral("macosdockrc"));
        }
    } else {
        m_containment = containments().constFirst();
        m_containment->setLocation(Plasma::Types::BottomEdge);
        m_containment->setFormFactor(Plasma::Types::Horizontal);
    }

    if (!m_containment) {
        qWarning() << "Failed to initialize dock containment";
        return;
    }

    // Look for existing applet or load new instance
    Plasma::Applet *appletPtr = nullptr;
    for (Plasma::Applet *a : m_containment->applets()) {
        if (a->pluginMetaData().pluginId() == QStringLiteral("com.cesar.macosdock")) {
            appletPtr = a;
            break;
        }
    }

    if (!appletPtr) {
        auto a = Plasma::PluginLoader::self()->loadApplet(QStringLiteral("com.cesar.macosdock"), 0, {});
        if (a) {
            appletPtr = a.get();
            a->setParent(this);
            m_containment->addApplet(std::move(a));
            saveLayout(QStringLiteral("macosdockrc"));
        }
    }

    if (appletPtr) {
        KConfigGroup appletConfig = appletPtr->config();
        KConfigGroup generalConfig = appletConfig.group(QStringLiteral("General"));

        const QStringList defaultLaunchers = {
            QStringLiteral("preferred://filemanager"),
            QStringLiteral("applications:launchpad.desktop"),
            QStringLiteral("preferred://browser"),
            QStringLiteral("applications:org.kde.kdeconnect.sms.desktop"),
            QStringLiteral("applications:proton-mail.desktop"),
            QStringLiteral("applications:brave-mnhkaebcjjhencmpkapnbdaogjamfbcj-Default.desktop"),
            QStringLiteral("applications:org.kde.gwenview.desktop"),
            QStringLiteral("applications:brave-hnpfjngllnobngcgfapefoaidbinmjnm-Default.desktop"),
            QStringLiteral("applications:org.cesar.kphone.desktop"),
            QStringLiteral("applications:proton-calendar.desktop"),
            QStringLiteral("applications:org.kde.kaddressbook.desktop"),
            QStringLiteral("applications:org.cesar.kreminders.desktop"),
            QStringLiteral("applications:org.cesar.kquicknote.desktop"),
            QStringLiteral("applications:mpv.desktop"),
            QStringLiteral("applications:org.kde.audiotube.desktop"),
            QStringLiteral("applications:com.shellyorg.shelly.desktop"),
            QStringLiteral("applications:org.cesar.kphonemirroring.desktop"),
            QStringLiteral("applications:systemsettings.desktop")
        };

        const QStringList currentLaunchers = generalConfig.readEntry("launchers", QStringList{});
        if (currentLaunchers.isEmpty()) {
            generalConfig.writeEntry("launchers", defaultLaunchers);
            generalConfig.writeEntry("elevation", 12);
            generalConfig.writeEntry("hoverElevation", 8);
            generalConfig.writeEntry("iconSpacing", 12);
            generalConfig.writeEntry("zoomBlastRadius", 1);
            generalConfig.writeEntry("zoomEnabled", true);
            generalConfig.writeEntry("zoomMultiplier", 1.5);
            generalConfig.writeEntry("containerBackgroundType", 4);
            generalConfig.sync();

            appletConfig.writeEntry("launchers", defaultLaunchers);
            appletConfig.writeEntry("elevation", 12);
            appletConfig.writeEntry("hoverElevation", 8);
            appletConfig.writeEntry("iconSpacing", 12);
            appletConfig.writeEntry("zoomBlastRadius", 1);
            appletConfig.writeEntry("zoomEnabled", true);
            appletConfig.writeEntry("zoomMultiplier", 1.5);
            appletConfig.writeEntry("containerBackgroundType", 4);
            appletConfig.sync();
        }

        connect(appletPtr, &Plasma::Applet::configNeedsSaving, this, [this]() {
            saveLayout(QStringLiteral("macosdockrc"));
        });
        connect(m_containment, &Plasma::Applet::configNeedsSaving, this, [this]() {
            saveLayout(QStringLiteral("macosdockrc"));
        });

        // Load or find Plasma Drawer applet in the dock containment
        for (Plasma::Applet *a : m_containment->applets()) {
            if (a->pluginMetaData().pluginId() == QStringLiteral("p-connor.plasma-drawer")) {
                m_drawerApplet = a;
                break;
            }
        }

        if (!m_drawerApplet) {
            auto a = Plasma::PluginLoader::self()->loadApplet(QStringLiteral("p-connor.plasma-drawer"), 0, {});
            if (a) {
                m_drawerApplet = a.get();
                a->setParent(this);
                m_containment->addApplet(std::move(a));
                saveLayout(QStringLiteral("macosdockrc"));
            }
        }

        recreateView();

        // Monitor screen lifecycle for DPMS resume, multi-monitor, and resolution changes
        connect(qGuiApp, &QGuiApplication::screenAdded, this, [this](QScreen *s) {
            qDebug() << "DockCorona: Screen added:" << (s ? s->name() : QStringLiteral("null"));
            QTimer::singleShot(300, this, &DockCorona::recreateView);
            QTimer::singleShot(1200, this, &DockCorona::recreateView);
        });

        connect(qGuiApp, &QGuiApplication::primaryScreenChanged, this, [this](QScreen *s) {
            qDebug() << "DockCorona: Primary screen changed:" << (s ? s->name() : QStringLiteral("null"));
            QTimer::singleShot(300, this, &DockCorona::recreateView);
            QTimer::singleShot(1200, this, &DockCorona::recreateView);
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

        // Listen to screen lock / unlock / turn on
        QDBusConnection::sessionBus().connect(
            QStringLiteral("org.freedesktop.ScreenSaver"),
            QStringLiteral("/org/freedesktop/ScreenSaver"),
            QStringLiteral("org.freedesktop.ScreenSaver"),
            QStringLiteral("ActiveChanged"),
            this,
            SLOT(onScreenSaverActiveChanged(bool))
        );

        // Watchdog timer to ensure dock is permanently visible
        auto watchdogTimer = new QTimer(this);
        watchdogTimer->setInterval(4000);
        connect(watchdogTimer, &QTimer::timeout, this, [this]() {
            auto s = QGuiApplication::primaryScreen();
            if (s && !s->name().isEmpty() && !s->name().contains(QLatin1String("placeholder"), Qt::CaseInsensitive) && s->geometry().width() > 0) {
                if (!m_view || !m_view->isVisible()) {
                    qWarning() << "DockCorona: Watchdog detected dock hidden or unmapped on" << s->name() << ", recreating view!";
                    recreateView();
                }
            }
        });
        watchdogTimer->start();

        QDBusConnection::sessionBus().registerService(QStringLiteral("com.cesar.macosdock"));
        QDBusConnection::sessionBus().registerObject(QStringLiteral("/Dock"), this, QDBusConnection::ExportAllSlots);
    } else {
        qWarning() << "Failed to load applet com.cesar.macosdock";
    }
}

void DockCorona::recreateView()
{
    auto primary = QGuiApplication::primaryScreen();
    if (!primary || primary->name().isEmpty() || primary->name().contains(QLatin1String("placeholder"), Qt::CaseInsensitive) || primary->geometry().width() <= 0) {
        qDebug() << "DockCorona::recreateView: ignoring invalid screen:" << (primary ? primary->name() : QStringLiteral("null"));
        return;
    }

    qDebug() << "DockCorona::recreateView on screen:" << primary->name() << primary->geometry();

    if (m_view) {
        m_view.reset();
    }

    m_view = std::make_unique<DockView>(this);
    connect(m_view.get(), &DockView::surfaceDismissed, this, [this]() {
        qDebug() << "DockCorona: dock view surface dismissed by compositor, queueing recreate";
        QTimer::singleShot(300, this, &DockCorona::recreateView);
    });

    Plasma::Applet *appletPtr = nullptr;
    if (m_containment) {
        for (Plasma::Applet *a : m_containment->applets()) {
            if (a->pluginMetaData().pluginId() == QStringLiteral("com.cesar.macosdock")) {
                appletPtr = a;
                break;
            }
        }
    }

    if (appletPtr && m_view) {
        m_view->setApplet(appletPtr);
        m_view->adaptToScreen();
    }

    if (m_drawerApplet && m_view) {
        auto drawerItem = PlasmaQuick::AppletQuickItem::itemForApplet(m_drawerApplet);
        if (drawerItem) {
            drawerItem->setParentItem(m_view->contentItem());
            drawerItem->setVisible(false);
            drawerItem->setSize(QSizeF(0, 0));
            drawerItem->compactRepresentationItem();
            drawerItem->fullRepresentationItem();
        }
    }
}

void DockCorona::onPrepareForSleep(bool sleeping)
{
    if (!sleeping) {
        qDebug() << "DockCorona: System woke from sleep, recreating view";
        QTimer::singleShot(300, this, &DockCorona::recreateView);
        QTimer::singleShot(1200, this, &DockCorona::recreateView);
    }
}

void DockCorona::onScreenSaverActiveChanged(bool active)
{
    if (!active) {
        qDebug() << "DockCorona: ScreenSaver unlocked/resumed, recreating view";
        QTimer::singleShot(300, this, &DockCorona::recreateView);
        QTimer::singleShot(1200, this, &DockCorona::recreateView);
    }
}

void DockCorona::toggleLaunchpad()
{
    if (m_drawerApplet) {
        Q_EMIT m_drawerApplet->activated();
        if (auto item = PlasmaQuick::AppletQuickItem::itemForApplet(m_drawerApplet)) {
            item->setExpanded(!item->isExpanded());
        }
    }
}

void DockCorona::openTrash()
{
    if (m_view && m_view->backend()) {
        m_view->backend()->openTrash();
    }
}

void DockCorona::emptyTrash()
{
    if (m_view && m_view->backend()) {
        m_view->backend()->emptyTrash();
    }
}

void DockCorona::openDownloads()
{
    if (m_view && m_view->backend()) {
        m_view->backend()->openDownloads();
    }
}

void DockCorona::showConfigurationInterface()
{
    if (m_view) {
        m_view->showConfigurationInterface();
    }
}
