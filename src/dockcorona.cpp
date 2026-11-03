/*
    SPDX-FileCopyrightText: 2026 Cesar <yugurta@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "dockcorona.h"
#include "dockview.h"

#include <QGuiApplication>
#include <QScreen>
#include <QDebug>

#include <KPackage/PackageLoader>
#include <Plasma/PluginLoader>

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

    m_view = std::make_unique<DockView>(this);

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
        if (!appletConfig.hasKey("launchers")) {
            KSharedConfig::Ptr plasmaConfig = KSharedConfig::openConfig(QStringLiteral("plasma-org.kde.plasma.desktop-appletsrc"));
            KConfigGroup oldConfig = plasmaConfig->group(QStringLiteral("Containments"))
                                                 .group(QStringLiteral("424"))
                                                 .group(QStringLiteral("Applets"))
                                                 .group(QStringLiteral("431"))
                                                 .group(QStringLiteral("Configuration"))
                                                 .group(QStringLiteral("General"));
            if (oldConfig.hasKey("launchers")) {
                oldConfig.copyTo(&appletConfig);
            } else {
                appletConfig.writeEntry("launchers", QStringList{
                    QStringLiteral("preferred://filemanager"),
                    QStringLiteral("applications:proton-mail.desktop"),
                    QStringLiteral("preferred://browser"),
                    QStringLiteral("applications:antigravity.desktop"),
                    QStringLiteral("applications:mpv.desktop")
                });
                appletConfig.writeEntry("elevation", 12);
                appletConfig.writeEntry("hoverElevation", 8);
                appletConfig.writeEntry("iconSpacing", 12);
                appletConfig.writeEntry("zoomBlastRadius", 1);
                appletConfig.writeEntry("zoomEnabled", true);
                appletConfig.writeEntry("zoomMultiplier", 1.5);
                appletConfig.writeEntry("containerBackgroundType", 4);
            }
            appletConfig.sync();
        }

        m_view->setApplet(appletPtr);
        m_view->show();
    } else {
        qWarning() << "Failed to load applet com.cesar.macosdock";
    }
}

void DockCorona::showConfigurationInterface()
{
    if (m_view) {
        m_view->showConfigurationInterface();
    }
}
