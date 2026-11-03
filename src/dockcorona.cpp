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
        KConfigGroup generalConfig = appletConfig.group(QStringLiteral("General"));

        const QStringList defaultLaunchers = {
            QStringLiteral("preferred://filemanager"),
            QStringLiteral("applications:launchpad.desktop"),
            QStringLiteral("preferred://browser"),
            QStringLiteral("applications:org.kde.kdeconnect.sms.desktop"),
            QStringLiteral("applications:proton-mail.desktop"),
            QStringLiteral("applications:google-maps-geo-handler.desktop"),
            QStringLiteral("applications:org.kde.gwenview.desktop"),
            QStringLiteral("applications:org.kde.kdeconnect.app.desktop"),
            QStringLiteral("applications:org.kde.korganizer.desktop"),
            QStringLiteral("applications:org.cesar.kquicknote.desktop"),
            QStringLiteral("applications:org.cesar.kvoicememos.desktop"),
            QStringLiteral("applications:mpv.desktop"),
            QStringLiteral("applications:antigravity.desktop"),
            QStringLiteral("applications:org.cesar.kdropover.desktop"),
            QStringLiteral("applications:org.kde.konsole.desktop"),
            QStringLiteral("applications:systemsettings.desktop")
        };

        const QStringList currentLaunchers = generalConfig.readEntry("launchers", QStringList{});
        if (currentLaunchers.size() < defaultLaunchers.size()) {
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
