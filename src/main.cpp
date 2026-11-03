/*
    SPDX-FileCopyrightText: 2026 Cesar <yugurta@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include <csignal>

#include <QApplication>
#include <QCommandLineOption>
#include <QCommandLineParser>
#include <QQuickWindow>
#include <QSurfaceFormat>

#include <KDBusService>
#include <KLocalizedString>
#include <KSignalHandler>

#include "dockcorona.h"

using namespace Qt::Literals;

int main(int argc, char **argv)
{
    QCoreApplication::setAttribute(Qt::AA_ShareOpenGLContexts);
    QQuickWindow::setDefaultAlphaBuffer(true);

    auto format = QSurfaceFormat::defaultFormat();
    format.setAlphaBufferSize(8);
    format.setOption(QSurfaceFormat::ResetNotification);
    QSurfaceFormat::setDefaultFormat(format);

    // Allow manual fixed positions in Qt Wayland so popups/tooltips map properly to global coordinates
    qputenv("QT_WAYLAND_DISABLE_FIXED_POSITIONS", "1");

    QApplication app(argc, argv);

    app.setApplicationVersion(QStringLiteral("1.0.0"));
    app.setOrganizationDomain(QStringLiteral("cesar.org"));
    app.setApplicationName(QStringLiteral("macos-dock"));
    app.setDesktopFileName(QStringLiteral("com.cesar.macosdock"));
    KLocalizedString::setApplicationDomain(QByteArrayLiteral("macos-dock"));

    QCommandLineParser parser;
    parser.setApplicationDescription(i18n("macOS Golden Gate Dock for KDE Plasma 6 (Wayland)"));
    parser.addHelpOption();
    parser.addVersionOption();

    QCommandLineOption replaceOption(QStringList() << QStringLiteral("replace"), i18n("Replace existing running instance"));
    parser.addOption(replaceOption);

    QCommandLineOption configOption(QStringList() << QStringLiteral("config"), i18n("Open configuration dialog"));
    parser.addOption(configOption);

    parser.process(app);

    KDBusService::StartupOptions dbusOptions = KDBusService::Unique;
    if (parser.isSet(replaceOption)) {
        dbusOptions |= KDBusService::Replace;
    }

    KDBusService service(dbusOptions);

    auto corona = std::make_unique<DockCorona>();
    corona->init();

    if (parser.isSet(configOption)) {
        corona->showConfigurationInterface();
    }

    QObject::connect(&service, &KDBusService::activateRequested, [&corona](const QStringList &arguments, const QString &/*workingDirectory*/) {
        if (arguments.contains(QStringLiteral("--config"))) {
            corona->showConfigurationInterface();
        }
    });

    // Handle SIGTERM / SIGINT gracefully
    KSignalHandler::self()->watchSignal(SIGTERM);
    KSignalHandler::self()->watchSignal(SIGINT);
    QObject::connect(KSignalHandler::self(), &KSignalHandler::signalReceived, &app, [&app](int /*signal*/) {
        app.quit();
    });

    return app.exec();
}
