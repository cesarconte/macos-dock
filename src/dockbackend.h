/*
    SPDX-FileCopyrightText: 2026 Cesar <yugurta@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <QObject>
#include <QList>
#include <QUrl>
#include <QFileSystemWatcher>
#include <functional>

class DockIndicatorManager;

class DockBackend : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isTrashFull READ isTrashFull NOTIFY trashChanged)
    Q_PROPERTY(int trashItemCount READ trashItemCount NOTIFY trashChanged)
    Q_PROPERTY(QString downloadsPath READ downloadsPath CONSTANT)
    Q_PROPERTY(int indicatorsVersion READ indicatorsVersion NOTIFY indicatorsChanged)

public:
    static DockBackend *instance();
    explicit DockBackend(QObject *parent = nullptr);
    ~DockBackend() override = default;

    bool isTrashFull() const;
    int trashItemCount() const;
    QString downloadsPath() const;
    int indicatorsVersion() const { return m_indicatorsVersion; }

    DockIndicatorManager *indicatorManager() const { return m_indicatorManager; }

    Q_INVOKABLE int badgeCount(const QString &appId, const QString &launcherUrl, const QString &title = QString()) const;
    Q_INVOKABLE bool badgeVisible(const QString &appId, const QString &launcherUrl, const QString &title = QString()) const;
    Q_INVOKABLE double progress(const QString &appId, const QString &launcherUrl) const;
    Q_INVOKABLE bool progressVisible(const QString &appId, const QString &launcherUrl) const;
    Q_INVOKABLE bool demandsAttention(const QString &appId, const QString &launcherUrl) const;

public Q_SLOTS:
    void openTrash();
    void emptyTrash();
    void openDownloads();
    void openUrl(const QUrl &url);
    void toggleLaunchpad();
    void setLaunchpadCallback(std::function<void()> cb);
    void moveToTrash(const QList<QUrl> &urls);
    void copyToDownloads(const QList<QUrl> &urls);
    void refreshTrash();

Q_SIGNALS:
    void trashChanged();
    void indicatorsChanged();

private:
    void checkTrash();

    QString m_trashFilesPath;
    QString m_downloadsPath;
    QFileSystemWatcher m_watcher;
    std::function<void()> m_launchpadCallback;
    bool m_isTrashFull = false;
    int m_trashItemCount = 0;

    DockIndicatorManager *m_indicatorManager = nullptr;
    int m_indicatorsVersion = 0;
};
