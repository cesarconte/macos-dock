/*
    SPDX-FileCopyrightText: 2026 Cesar <yugurta@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QHash>
#include <QRegularExpression>

struct IndicatorData {
    int badgeCount = 0;
    bool badgeVisible = false;
    double progress = 0.0;
    bool progressVisible = false;
    bool urgent = false;
};

class DockIndicatorManager : public QObject
{
    Q_OBJECT

public:
    explicit DockIndicatorManager(QObject *parent = nullptr);
    ~DockIndicatorManager() override = default;

    int badgeCount(const QString &appId, const QString &launcherUrl, const QString &title) const;
    bool badgeVisible(const QString &appId, const QString &launcherUrl, const QString &title) const;
    double progress(const QString &appId, const QString &launcherUrl) const;
    bool progressVisible(const QString &appId, const QString &launcherUrl) const;
    bool demandsAttention(const QString &appId, const QString &launcherUrl) const;

    // Direct data management (used in tests and internal updates)
    void setIndicator(const QString &key, const IndicatorData &data);
    IndicatorData getIndicator(const QString &key) const;
    void clearIndicator(const QString &key);

    // Parsing helpers
    static QString normalizeKey(const QString &key);
    static int parseBadgeFromTitle(const QString &title);
    static int parseBadgeFromText(const QString &text);

public Q_SLOTS:
    void onUnityLauncherUpdate(const QString &appUri, const QVariantMap &properties);
    void onStatusNotifierItemRegistered(const QString &service);
    void onStatusNotifierItemUnregistered(const QString &service);
    void refreshAllSniItems();
    void inspectSniService(const QString &service);

Q_SIGNALS:
    void indicatorsChanged();

private:
    void initUnityListener();
    void initSniListener();
    QString defaultBrowserKey() const;

    QHash<QString, IndicatorData> m_indicators;
    mutable QString m_cachedDefaultBrowser;
    QHash<QString, QString> m_sniServiceMap; // service -> canonicalKey
};
