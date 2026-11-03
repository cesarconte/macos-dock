/*
    SPDX-FileCopyrightText: 2026 Cesar <yugurta@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <QObject>
#include <QList>
#include <QUrl>
#include <QFileSystemWatcher>

class DockBackend : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isTrashFull READ isTrashFull NOTIFY trashChanged)
    Q_PROPERTY(int trashItemCount READ trashItemCount NOTIFY trashChanged)

public:
    explicit DockBackend(QObject *parent = nullptr);
    ~DockBackend() override = default;

    bool isTrashFull() const;
    int trashItemCount() const;

public Q_SLOTS:
    void openTrash();
    void emptyTrash();
    void openDownloads();
    void moveToTrash(const QList<QUrl> &urls);
    void copyToDownloads(const QList<QUrl> &urls);
    void refreshTrash();

Q_SIGNALS:
    void trashChanged();

private:
    void checkTrash();

    QString m_trashFilesPath;
    QString m_downloadsPath;
    QFileSystemWatcher m_watcher;
    bool m_isTrashFull = false;
    int m_trashItemCount = 0;
};
