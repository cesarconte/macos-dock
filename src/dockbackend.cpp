/*
    SPDX-FileCopyrightText: 2026 Cesar <yugurta@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "dockbackend.h"

#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QStandardPaths>
#include <QTimer>

#include <KIO/CopyJob>
#include <KIO/EmptyTrashJob>

DockBackend::DockBackend(QObject *parent)
    : QObject(parent)
{
    m_trashFilesPath = QDir::homePath() + QStringLiteral("/.local/share/Trash/files");
    const QString trashInfoPath = QDir::homePath() + QStringLiteral("/.local/share/Trash/info");
    const QString trashRootPath = QDir::homePath() + QStringLiteral("/.local/share/Trash");
    m_downloadsPath = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);

    QDir().mkpath(m_trashFilesPath);
    QDir().mkpath(trashInfoPath);

    m_watcher.addPath(m_trashFilesPath);
    m_watcher.addPath(trashInfoPath);
    m_watcher.addPath(trashRootPath);

    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &DockBackend::checkTrash);

    auto timer = new QTimer(this);
    timer->setInterval(2000);
    connect(timer, &QTimer::timeout, this, &DockBackend::checkTrash);
    timer->start();

    checkTrash();
}

bool DockBackend::isTrashFull() const
{
    return m_isTrashFull;
}

int DockBackend::trashItemCount() const
{
    return m_trashItemCount;
}

void DockBackend::checkTrash()
{
    QDir dir(m_trashFilesPath);
    const auto entries = dir.entryList(QDir::NoDotAndDotDot | QDir::AllEntries | QDir::Hidden);
    const int count = entries.count();
    const bool full = count > 0;

    if (full != m_isTrashFull || count != m_trashItemCount) {
        m_isTrashFull = full;
        m_trashItemCount = count;
        Q_EMIT trashChanged();
    }
}

void DockBackend::refreshTrash()
{
    checkTrash();
}

void DockBackend::openTrash()
{
    if (QProcess::startDetached(QStringLiteral("dolphin"), {QStringLiteral("trash:/")})) {
        return;
    }
    if (QProcess::startDetached(QStringLiteral("kioclient"), {QStringLiteral("exec"), QStringLiteral("trash:/")})) {
        return;
    }
    QDesktopServices::openUrl(QUrl(QStringLiteral("trash:/")));
}

void DockBackend::emptyTrash()
{
    auto *job = KIO::emptyTrash();
    connect(job, &KJob::result, this, [this](KJob *job) {
        if (!job->error()) {
            checkTrash();

            // Native PipeWire playback for trash empty sound
            const QString soundPath = QStringLiteral("/usr/share/sounds/ocean/stereo/trash-empty.oga");
            if (QFile::exists(soundPath)) {
                QProcess::startDetached(QStringLiteral("pw-play"), {soundPath});
            }
        }
    });
}

void DockBackend::openDownloads()
{
    QDesktopServices::openUrl(QUrl::fromLocalFile(m_downloadsPath));
}

void DockBackend::moveToTrash(const QList<QUrl> &urls)
{
    if (urls.isEmpty()) {
        return;
    }
    auto *job = KIO::trash(urls);
    connect(job, &KJob::result, this, [this](KJob *job) {
        if (!job->error()) {
            checkTrash();
        }
    });
}

void DockBackend::setLaunchpadCallback(std::function<void()> cb)
{
    m_launchpadCallback = std::move(cb);
}

void DockBackend::toggleLaunchpad()
{
    if (m_launchpadCallback) {
        m_launchpadCallback();
    }
}

void DockBackend::copyToDownloads(const QList<QUrl> &urls)
{
    for (const auto &url : urls) {
        if (!url.isLocalFile()) {
            continue;
        }
        const QString srcPath = url.toLocalFile();
        const QFileInfo fi(srcPath);
        const QString destPath = m_downloadsPath + QStringLiteral("/") + fi.fileName();
        QFile::copy(srcPath, destPath);
    }
}
