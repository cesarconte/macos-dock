/*
    SPDX-FileCopyrightText: 2026 Cesar <yugurta@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "dockindicatormanager.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusReply>
#include <QDBusArgument>
#include <QDebug>
#include <QSettings>
#include <QDir>
#include <KService>
#include <KSharedConfig>
#include <KConfigGroup>

DockIndicatorManager::DockIndicatorManager(QObject *parent)
    : QObject(parent)
{
    initUnityListener();
    initSniListener();
    initJobsModel();
}

QString DockIndicatorManager::normalizeKey(const QString &key)
{
    if (key.isEmpty()) {
        return QString();
    }

    QString norm = key.trimmed();

    if (norm.startsWith(QLatin1String("applications:"), Qt::CaseInsensitive)) {
        norm.remove(0, 13);
    } else if (norm.startsWith(QLatin1String("application://"), Qt::CaseInsensitive)) {
        norm.remove(0, 14);
    } else if (norm.startsWith(QLatin1String("file://"), Qt::CaseInsensitive)) {
        norm.remove(0, 7);
    }

    const int queryIdx = norm.indexOf(QLatin1Char('?'));
    if (queryIdx != -1) {
        norm = norm.left(queryIdx);
    }

    const int slashIdx = norm.lastIndexOf(QLatin1Char('/'));
    if (slashIdx != -1) {
        norm = norm.mid(slashIdx + 1);
    }

    if (norm.endsWith(QLatin1String(".desktop"), Qt::CaseInsensitive)) {
        norm.chop(8);
    }

    norm = norm.toLower();

    // Map common aliases
    if (norm.contains(QLatin1String("whatsapp"))
        || norm.contains(QLatin1String("brave-hnpfjngllnobngcgfapefoaidbinmjnm"))
        || norm.contains(QLatin1String("crx_hnpfjngllnobngcgfapefoaidbinmjnm"))) {
        return QStringLiteral("whatsapp");
    }

    if (norm.contains(QLatin1String("proton-mail")) || norm.contains(QLatin1String("protonmail"))) {
        return QStringLiteral("proton-mail");
    }

    // Brave browser and variants
    if (norm == QLatin1String("brave")
        || norm == QLatin1String("brave-origin")
        || norm == QLatin1String("brave-browser")
        || norm == QLatin1String("brave-bin")) {
        return QStringLiteral("brave");
    }

    // Chrome and Chromium variants
    if (norm == QLatin1String("google-chrome") || norm == QLatin1String("google-chrome-stable")) {
        return QStringLiteral("google-chrome");
    }
    if (norm == QLatin1String("chromium") || norm == QLatin1String("chromium-browser")) {
        return QStringLiteral("chromium");
    }

    return norm;
}

QString DockIndicatorManager::defaultBrowserKey() const
{
    if (!m_cachedDefaultBrowser.isEmpty()) {
        return m_cachedDefaultBrowser;
    }

    // Try reading default browser from KDE config
    KSharedConfig::Ptr config = KSharedConfig::openConfig(QStringLiteral("kdeglobals"));
    KConfigGroup group(config, QStringLiteral("General"));
    QString browser = group.readEntry("BrowserApplication", QString());

    if (browser.isEmpty()) {
        // Fallback: check mimeapps.list
        const QString mimePath = QDir::homePath() + QStringLiteral("/.config/mimeapps.list");
        QSettings mimeSettings(mimePath, QSettings::IniFormat);
        browser = mimeSettings.value(QStringLiteral("Default Applications/x-scheme-handler/https")).toString();
    }

    if (browser.isEmpty()) {
        browser = QStringLiteral("brave-origin.desktop");
    }

    m_cachedDefaultBrowser = normalizeKey(browser);
    return m_cachedDefaultBrowser;
}

int DockIndicatorManager::parseBadgeFromTitle(const QString &title)
{
    if (title.isEmpty()) {
        return 0;
    }

    static const QRegularExpression rx(QStringLiteral("^\\s*\\(([0-9]+)\\+?\\)"));
    const auto match = rx.match(title);
    if (match.hasMatch()) {
        return match.captured(1).toInt();
    }
    return 0;
}

int DockIndicatorManager::parseBadgeFromText(const QString &text)
{
    if (text.isEmpty()) {
        return 0;
    }

    static const QRegularExpression rx(
        QStringLiteral("(\\d+)\\s*(?:mensajes?|messages?|unread|sin leer|nuevos?|new)"),
        QRegularExpression::CaseInsensitiveOption
    );
    const auto match = rx.match(text);
    if (match.hasMatch()) {
        return match.captured(1).toInt();
    }
    return 0;
}

int DockIndicatorManager::badgeCount(const QString &appId, const QString &launcherUrl, const QString &title) const
{
    // 1. Direct indicator matching (Unity / SNI / Jobs)
    const QString normAppId = normalizeKey(appId);
    if (!normAppId.isEmpty() && m_indicators.contains(normAppId)) {
        const auto &ind = m_indicators.value(normAppId);
        if (ind.badgeVisible && ind.badgeCount > 0) {
            return ind.badgeCount;
        }
    }

    QString normLauncher = launcherUrl;
    if (normLauncher.contains(QLatin1String("preferred://browser"))) {
        normLauncher = defaultBrowserKey();
    } else {
        normLauncher = normalizeKey(normLauncher);
    }

    if (!normLauncher.isEmpty() && m_indicators.contains(normLauncher)) {
        const auto &ind = m_indicators.value(normLauncher);
        if (ind.badgeVisible && ind.badgeCount > 0) {
            return ind.badgeCount;
        }
    }

    // 2. Fallback: Parse badge from WebApp / Window title (e.g. "(3) WhatsApp")
    const int titleBadge = parseBadgeFromTitle(title);
    if (titleBadge > 0) {
        return titleBadge;
    }

    return 0;
}

bool DockIndicatorManager::badgeVisible(const QString &appId, const QString &launcherUrl, const QString &title) const
{
    return badgeCount(appId, launcherUrl, title) > 0;
}

double DockIndicatorManager::progress(const QString &appId, const QString &launcherUrl) const
{
    const QString normAppId = normalizeKey(appId);
    if (!normAppId.isEmpty() && m_indicators.contains(normAppId)) {
        const auto &ind = m_indicators.value(normAppId);
        if (ind.progressVisible) {
            return ind.progress;
        }
    }

    QString normLauncher = launcherUrl;
    if (normLauncher.contains(QLatin1String("preferred://browser"))) {
        normLauncher = defaultBrowserKey();
    } else {
        normLauncher = normalizeKey(normLauncher);
    }

    if (!normLauncher.isEmpty() && m_indicators.contains(normLauncher)) {
        const auto &ind = m_indicators.value(normLauncher);
        if (ind.progressVisible) {
            return ind.progress;
        }
    }

    return 0.0;
}

bool DockIndicatorManager::progressVisible(const QString &appId, const QString &launcherUrl) const
{
    const QString normAppId = normalizeKey(appId);
    if (!normAppId.isEmpty() && m_indicators.contains(normAppId)) {
        if (m_indicators.value(normAppId).progressVisible && m_indicators.value(normAppId).progress > 0.0) {
            return true;
        }
    }

    QString normLauncher = launcherUrl;
    if (normLauncher.contains(QLatin1String("preferred://browser"))) {
        normLauncher = defaultBrowserKey();
    } else {
        normLauncher = normalizeKey(normLauncher);
    }

    if (!normLauncher.isEmpty() && m_indicators.contains(normLauncher)) {
        if (m_indicators.value(normLauncher).progressVisible && m_indicators.value(normLauncher).progress > 0.0) {
            return true;
        }
    }

    return false;
}

bool DockIndicatorManager::demandsAttention(const QString &appId, const QString &launcherUrl) const
{
    const QString normAppId = normalizeKey(appId);
    if (!normAppId.isEmpty() && m_indicators.contains(normAppId)) {
        if (m_indicators.value(normAppId).urgent) {
            return true;
        }
    }

    QString normLauncher = launcherUrl;
    if (normLauncher.contains(QLatin1String("preferred://browser"))) {
        normLauncher = defaultBrowserKey();
    } else {
        normLauncher = normalizeKey(normLauncher);
    }

    if (!normLauncher.isEmpty() && m_indicators.contains(normLauncher)) {
        if (m_indicators.value(normLauncher).urgent) {
            return true;
        }
    }

    return false;
}

void DockIndicatorManager::setIndicator(const QString &key, const IndicatorData &data)
{
    const QString norm = normalizeKey(key);
    m_indicators.insert(norm, data);
    Q_EMIT indicatorsChanged();
}

IndicatorData DockIndicatorManager::getIndicator(const QString &key) const
{
    const QString norm = normalizeKey(key);
    return m_indicators.value(norm);
}

void DockIndicatorManager::clearIndicator(const QString &key)
{
    const QString norm = normalizeKey(key);
    if (m_indicators.remove(norm) > 0) {
        Q_EMIT indicatorsChanged();
    }
}

void DockIndicatorManager::initUnityListener()
{
    auto sessionBus = QDBusConnection::sessionBus();

    // Register Unity service and object so Chromium/Brave knows a compatible launcher exists
    sessionBus.registerObject(QStringLiteral("/Unity"), this, QDBusConnection::ExportAllSlots);
    sessionBus.registerService(QStringLiteral("com.canonical.Unity"));

    // Listen for Unity LauncherEntry Update signals broadcast by Chromium, Brave, Telegram, Thunderbird, etc.
    bool ok = sessionBus.connect(
        QString(),
        QString(),
        QStringLiteral("com.canonical.Unity.LauncherEntry"),
        QStringLiteral("Update"),
        this,
        SLOT(onUnityLauncherUpdate(QString,QMap<QString,QVariant>))
    );
    qDebug() << "DockIndicatorManager::initUnityListener sessionBus.connect returned:" << ok;
}

void DockIndicatorManager::onUnityLauncherUpdate(const QString &appUri, const QMap<QString, QVariant> &properties)
{
    qDebug() << "DockIndicatorManager::onUnityLauncherUpdate:" << appUri << properties;
    if (appUri.isEmpty()) {
        return;
    }

    const QString normKey = normalizeKey(appUri);
    IndicatorData data = m_indicators.value(normKey);
    const bool wasDownloading = data.progressVisible && data.progress > 0.0;

    if (properties.contains(QStringLiteral("count"))) {
        data.badgeCount = properties.value(QStringLiteral("count")).toInt();
    }
    if (properties.contains(QStringLiteral("count-visible"))) {
        data.badgeVisible = properties.value(QStringLiteral("count-visible")).toBool();
    } else if (properties.contains(QStringLiteral("count"))) {
        data.badgeVisible = data.badgeCount > 0;
    }

    if (properties.contains(QStringLiteral("progress"))) {
        double p = properties.value(QStringLiteral("progress")).toDouble();
        if (p > 1.0) {
            p = p / 100.0;
        }
        data.progress = qBound(0.0, p, 1.0);
    }
    if (properties.contains(QStringLiteral("progress-visible"))) {
        data.progressVisible = properties.value(QStringLiteral("progress-visible")).toBool();
    }

    if (properties.contains(QStringLiteral("urgent"))) {
        data.urgent = properties.value(QStringLiteral("urgent")).toBool();
    }

    m_indicators.insert(normKey, data);
    Q_EMIT indicatorsChanged();

    const bool isDownloading = data.progressVisible && data.progress > 0.0;
    if (wasDownloading && !isDownloading) {
        qDebug() << "DockIndicatorManager: Download completed for" << normKey;
        Q_EMIT downloadFinished(normKey);
    }
}

void DockIndicatorManager::initSniListener()
{
    // Listen for StatusNotifierWatcher registration signals
    QDBusConnection::sessionBus().connect(
        QStringLiteral("org.kde.StatusNotifierWatcher"),
        QStringLiteral("/StatusNotifierWatcher"),
        QStringLiteral("org.kde.StatusNotifierWatcher"),
        QStringLiteral("StatusNotifierItemRegistered"),
        this,
        SLOT(onStatusNotifierItemRegistered(QString))
    );

    QDBusConnection::sessionBus().connect(
        QStringLiteral("org.kde.StatusNotifierWatcher"),
        QStringLiteral("/StatusNotifierWatcher"),
        QStringLiteral("org.kde.StatusNotifierWatcher"),
        QStringLiteral("StatusNotifierItemUnregistered"),
        this,
        SLOT(onStatusNotifierItemUnregistered(QString))
    );

    refreshAllSniItems();
}

void DockIndicatorManager::refreshAllSniItems()
{
    QDBusInterface watcher(
        QStringLiteral("org.kde.StatusNotifierWatcher"),
        QStringLiteral("/StatusNotifierWatcher"),
        QStringLiteral("org.kde.StatusNotifierWatcher"),
        QDBusConnection::sessionBus()
    );

    const QVariant prop = watcher.property("RegisteredStatusNotifierItems");
    const QStringList items = prop.toStringList();
    for (const QString &item : items) {
        inspectSniService(item);
    }
}

void DockIndicatorManager::onStatusNotifierItemRegistered(const QString &service)
{
    inspectSniService(service);
}

void DockIndicatorManager::onStatusNotifierItemUnregistered(const QString &service)
{
    if (m_sniServiceMap.contains(service)) {
        const QString canonicalKey = m_sniServiceMap.take(service);
        IndicatorData data = m_indicators.value(canonicalKey);
        data.badgeCount = 0;
        data.badgeVisible = false;
        m_indicators.insert(canonicalKey, data);
        Q_EMIT indicatorsChanged();
    }
}

void DockIndicatorManager::inspectSniService(const QString &service)
{
    QString busName = service;
    QString objectPath = QStringLiteral("/StatusNotifierItem");

    if (service.startsWith(QLatin1Char('/'))) {
        return;
    }
    const int slashIndex = service.indexOf(QLatin1Char('/'));
    if (slashIndex > 0) {
        busName = service.left(slashIndex);
        objectPath = service.mid(slashIndex);
    }

    QDBusInterface sni(busName, objectPath, QStringLiteral("org.kde.StatusNotifierItem"), QDBusConnection::sessionBus());
    if (!sni.isValid()) {
        return;
    }

    const QString id = sni.property("Id").toString();
    const QString title = sni.property("Title").toString();

    // Check if this SNI corresponds to Proton Mail or known mail/messaging apps
    // Note: Ignore "Proton Mail Bridge" as it is the local IMAP bridge daemon, not the mail notifier.
    QString matchedKey;
    if ((id.contains(QLatin1String("proton-mail-notifier"), Qt::CaseInsensitive)
         || id.contains(QLatin1String("protonmail-notifier"), Qt::CaseInsensitive)
         || (id.contains(QLatin1String("proton-mail"), Qt::CaseInsensitive) && !id.contains(QLatin1String("bridge"), Qt::CaseInsensitive))
         || (title.contains(QLatin1String("Proton Mail"), Qt::CaseInsensitive) && !title.contains(QLatin1String("Bridge"), Qt::CaseInsensitive)))) {
        matchedKey = QStringLiteral("proton-mail");
    }

    if (matchedKey.isEmpty()) {
        return;
    }

    m_sniServiceMap.insert(service, matchedKey);

    auto updateFromToolTip = [this, busName, objectPath, matchedKey]() {
        QDBusMessage msg = QDBusMessage::createMethodCall(
            busName,
            objectPath,
            QStringLiteral("org.freedesktop.DBus.Properties"),
            QStringLiteral("Get")
        );
        msg << QStringLiteral("org.kde.StatusNotifierItem") << QStringLiteral("ToolTip");
        QDBusMessage reply = QDBusConnection::sessionBus().call(msg);

        QString description;
        if (reply.type() == QDBusMessage::ReplyMessage && !reply.arguments().isEmpty()) {
            const QVariant firstArg = reply.arguments().at(0);
            QVariant innerVal;
            if (firstArg.canConvert<QDBusVariant>()) {
                innerVal = firstArg.value<QDBusVariant>().variant();
            } else {
                innerVal = firstArg;
            }

            if (innerVal.canConvert<QDBusArgument>()) {
                const QDBusArgument arg = innerVal.value<QDBusArgument>();
                if (arg.currentType() == QDBusArgument::StructureType) {
                    arg.beginStructure();
                    QString iconName;
                    arg >> iconName;

                    // Skip image array
                    arg.beginArray();
                    while (!arg.atEnd()) {
                        arg.beginStructure();
                        int w, h;
                        QByteArray bytes;
                        arg >> w >> h >> bytes;
                        arg.endStructure();
                    }
                    arg.endArray();

                    QString ttTitle;
                    arg >> ttTitle;
                    if (!arg.atEnd()) {
                        arg >> description;
                    }
                    arg.endStructure();
                }
            }
        }

        const int unread = parseBadgeFromText(description);
        IndicatorData data = m_indicators.value(matchedKey);
        data.badgeCount = unread;
        data.badgeVisible = unread > 0;
        m_indicators.insert(matchedKey, data);
        Q_EMIT indicatorsChanged();
    };

    // Connect to NewToolTip signal for dynamic real-time updates
    QDBusConnection::sessionBus().connect(
        busName,
        objectPath,
        QStringLiteral("org.kde.StatusNotifierItem"),
        QStringLiteral("NewToolTip"),
        this,
        SLOT(refreshAllSniItems())
    );

    updateFromToolTip();
}

void DockIndicatorManager::initJobsModel()
{
    // Native Plasma Application Jobs Integration (Dolphin, Discover, Browsers, etc.)
    m_jobsModel = NotificationManager::JobsModel::createJobsModel();
    if (m_jobsModel) {
        m_jobsModel->init();

        connect(m_jobsModel.get(), &QAbstractItemModel::rowsInserted, this, &DockIndicatorManager::updateFromJobsModel);
        connect(m_jobsModel.get(), &QAbstractItemModel::rowsRemoved, this, &DockIndicatorManager::updateFromJobsModel);
        connect(m_jobsModel.get(), &QAbstractItemModel::dataChanged, this, &DockIndicatorManager::updateFromJobsModel);
        connect(m_jobsModel.get(), &QAbstractItemModel::modelReset, this, &DockIndicatorManager::updateFromJobsModel);

        updateFromJobsModel();
    }
}

void DockIndicatorManager::updateFromJobsModel()
{
    if (!m_jobsModel) {
        return;
    }

    QSet<QString> currentRunningJobKeys;
    const int count = m_jobsModel->rowCount();

    for (int i = 0; i < count; ++i) {
        const QModelIndex idx = m_jobsModel->index(i, 0);
        const int state = idx.data(NotificationManager::Notifications::JobStateRole).toInt();

        if (state == NotificationManager::Notifications::JobStateRunning
            || state == NotificationManager::Notifications::JobStateSuspended) {
            const QString desktopEntry = idx.data(NotificationManager::Notifications::DesktopEntryRole).toString();
            const QString appName = idx.data(NotificationManager::Notifications::ApplicationNameRole).toString();
            const int percentage = idx.data(NotificationManager::Notifications::PercentageRole).toInt();

            QString key = normalizeKey(desktopEntry);
            if (key.isEmpty()) {
                key = normalizeKey(appName);
            }

            if (!key.isEmpty()) {
                currentRunningJobKeys.insert(key);

                IndicatorData data = m_indicators.value(key);
                data.progress = qBound(0.0, percentage / 100.0, 1.0);
                data.progressVisible = true;
                m_indicators.insert(key, data);
            }
        }
    }

    // Clear progress for jobs that have finished or been cancelled
    for (const QString &oldKey : std::as_const(m_activeJobKeys)) {
        if (!currentRunningJobKeys.contains(oldKey)) {
            IndicatorData data = m_indicators.value(oldKey);
            data.progress = 0.0;
            data.progressVisible = false;
            m_indicators.insert(oldKey, data);
        }
    }

    m_activeJobKeys = currentRunningJobKeys;
    Q_EMIT indicatorsChanged();
}
