/*
    SPDX-FileCopyrightText: 2026 Cesar <yugurta@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "dockbackend.h"
#include "dockindicatormanager.h"

#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QStandardPaths>
#include <QTimer>

#include <KIO/CopyJob>
#include <KIO/EmptyTrashJob>
#include <KIO/OpenUrlJob>
#include <KIO/ApplicationLauncherJob>
#include <KIO/JobUiDelegateFactory>
#include <KIO/OpenFileManagerWindowJob>
#include <KService>
#include <QClipboard>
#include <QGuiApplication>
#include <QMimeData>
#include <QMimeDatabase>
#include <QMimeType>
#include <QSet>
#include <QXmlStreamReader>

static DockBackend *s_instance = nullptr;

DockBackend *DockBackend::instance()
{
    if (!s_instance) {
        s_instance = new DockBackend();
    }
    return s_instance;
}

DockBackend::DockBackend(QObject *parent)
    : QObject(parent)
{
    s_instance = this;
    m_trashFilesPath = QDir::homePath() + QStringLiteral("/.local/share/Trash/files");
    const QString trashInfoPath = QDir::homePath() + QStringLiteral("/.local/share/Trash/info");
    const QString trashRootPath = QDir::homePath() + QStringLiteral("/.local/share/Trash");
    m_downloadsPath = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);

    QDir().mkpath(m_trashFilesPath);
    QDir().mkpath(trashInfoPath);

    m_watcher.addPath(m_trashFilesPath);
    m_watcher.addPath(trashInfoPath);
    m_watcher.addPath(trashRootPath);

    if (!m_downloadsPath.isEmpty() && QDir(m_downloadsPath).exists()) {
        m_watcher.addPath(m_downloadsPath);
        QDir d(m_downloadsPath);
        m_knownDownloadFiles = d.entryList(QDir::Files | QDir::NoDotAndDotDot);
    }

    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this](const QString &path) {
        if (path == m_downloadsPath) {
            checkDownloads();
        } else {
            checkTrash();
        }
    });

    auto timer = new QTimer(this);
    timer->setInterval(2000);
    connect(timer, &QTimer::timeout, this, [this]() {
        checkTrash();
        checkDownloads();
    });
    timer->start();

    checkTrash();

    m_indicatorManager = new DockIndicatorManager(this);
    connect(m_indicatorManager, &DockIndicatorManager::indicatorsChanged, this, [this]() {
        m_indicatorsVersion++;
        Q_EMIT indicatorsChanged();
    });
    connect(m_indicatorManager, &DockIndicatorManager::downloadFinished, this, &DockBackend::downloadFinished);
}

bool DockBackend::isTrashFull() const
{
    return m_isTrashFull;
}

int DockBackend::trashItemCount() const
{
    return m_trashItemCount;
}

QString DockBackend::downloadsPath() const
{
    return m_downloadsPath;
}

int DockBackend::badgeCount(const QString &appId, const QString &launcherUrl, const QString &title) const
{
    return m_indicatorManager ? m_indicatorManager->badgeCount(appId, launcherUrl, title) : 0;
}

bool DockBackend::badgeVisible(const QString &appId, const QString &launcherUrl, const QString &title) const
{
    return m_indicatorManager ? m_indicatorManager->badgeVisible(appId, launcherUrl, title) : false;
}

double DockBackend::progress(const QString &appId, const QString &launcherUrl) const
{
    return m_indicatorManager ? m_indicatorManager->progress(appId, launcherUrl) : 0.0;
}

bool DockBackend::progressVisible(const QString &appId, const QString &launcherUrl) const
{
    return m_indicatorManager ? m_indicatorManager->progressVisible(appId, launcherUrl) : false;
}

bool DockBackend::demandsAttention(const QString &appId, const QString &launcherUrl) const
{
    return m_indicatorManager ? m_indicatorManager->demandsAttention(appId, launcherUrl) : false;
}

QString DockBackend::iconForUrl(const QUrl &url, bool isDir) const
{
    if (isDir) {
        return QStringLiteral("folder");
    }
    QMimeDatabase db;
    QMimeType mime = db.mimeTypeForUrl(url);
    if (mime.isValid()) {
        const QString iconName = mime.iconName();
        if (!iconName.isEmpty()) {
            return iconName;
        }
        const QString genericIconName = mime.genericIconName();
        if (!genericIconName.isEmpty()) {
            return genericIconName;
        }
    }
    return QStringLiteral("application-octet-stream");
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

void DockBackend::checkDownloads()
{
    if (m_downloadsPath.isEmpty()) {
        return;
    }

    QDir dir(m_downloadsPath);
    if (!dir.exists()) {
        return;
    }

    const auto currentFiles = dir.entryList(QDir::Files | QDir::NoDotAndDotDot);
    bool hasNewCompletedDownload = false;

    for (const QString &file : currentFiles) {
        if (file.endsWith(QLatin1String(".crdownload")) ||
            file.endsWith(QLatin1String(".part")) ||
            file.endsWith(QLatin1String(".tmp")) ||
            file.endsWith(QLatin1String(".download"))) {
            continue;
        }

        if (!m_knownDownloadFiles.contains(file)) {
            hasNewCompletedDownload = true;
            break;
        }
    }

    m_knownDownloadFiles = currentFiles;

    if (hasNewCompletedDownload) {
        Q_EMIT newDownloadItemAdded();
    }
}

void DockBackend::refreshTrash()
{
    checkTrash();
}

void DockBackend::openTrash()
{
    qDebug() << "DockBackend::openTrash() CALLED";
    auto service = KService::serviceByDesktopName(QStringLiteral("org.kde.dolphin"));
    if (service) {
        auto *job = new KIO::ApplicationLauncherJob(service);
        job->setUrls({QUrl(QStringLiteral("trash:/"))});
        job->start();
        return;
    }
    if (QProcess::startDetached(QStringLiteral("dolphin"), {QStringLiteral("trash:/")})) {
        return;
    }
    auto *job = new KIO::OpenUrlJob(QUrl(QStringLiteral("trash:/")));
    job->start();
}

void DockBackend::emptyTrash()
{
    qDebug() << "DockBackend::emptyTrash() CALLED";
    auto *job = KIO::emptyTrash();
    connect(job, &KJob::result, this, [this](KJob *job) {
        if (!job->error()) {
            checkTrash();

            // Native PipeWire playback for trash empty sound
            const QString soundPath = QStringLiteral("/usr/share/sounds/ocean/stereo/trash-empty.oga");
            if (QFile::exists(soundPath)) {
                QProcess::startDetached(QStringLiteral("pw-play"), {soundPath});
            }
        } else {
            qWarning() << "KIO::emptyTrash error:" << job->errorString();
        }
    });
}

void DockBackend::openDownloads()
{
    qDebug() << "DockBackend::openDownloads() CALLED";
    auto service = KService::serviceByDesktopName(QStringLiteral("org.kde.dolphin"));
    if (service) {
        auto *job = new KIO::ApplicationLauncherJob(service);
        job->setUrls({QUrl::fromLocalFile(m_downloadsPath)});
        job->start();
        return;
    }
    if (QProcess::startDetached(QStringLiteral("dolphin"), {m_downloadsPath})) {
        return;
    }
    auto *job = new KIO::OpenUrlJob(QUrl::fromLocalFile(m_downloadsPath));
    job->start();
}

void DockBackend::openUrl(const QUrl &url)
{
    qDebug() << "DockBackend::openUrl() CALLED with" << url;
    auto *job = new KIO::OpenUrlJob(url);
    job->setUiDelegate(KIO::createDefaultJobUiDelegate());
    job->setShowOpenOrExecuteDialog(true);
    job->setRunExecutables(true);
    connect(job, &KJob::result, this, [url](KJob *job) {
        if (job->error()) {
            qWarning() << "OpenUrlJob error, falling back to QDesktopServices:" << job->errorString();
            QDesktopServices::openUrl(url);
        }
    });
    job->start();
}

void DockBackend::showInFolder(const QUrl &url)
{
    qDebug() << "DockBackend::showInFolder() CALLED with" << url;
    auto *job = KIO::highlightInFileManager({url});
    if (job) {
        job->start();
    }
}

void DockBackend::copyToClipboard(const QUrl &url)
{
    qDebug() << "DockBackend::copyToClipboard() CALLED with" << url;
    auto *clipboard = QGuiApplication::clipboard();
    if (!clipboard) {
        return;
    }
    auto *mimeData = new QMimeData();
    mimeData->setUrls({url});
    mimeData->setText(url.isLocalFile() ? url.toLocalFile() : url.toString());
    clipboard->setMimeData(mimeData);
}

void DockBackend::trashUrl(const QUrl &url)
{
    moveToTrash({url});
}

void DockBackend::moveToTrash(const QList<QUrl> &urls)
{
    qDebug() << "DockBackend::moveToTrash() CALLED with" << urls;
    if (urls.isEmpty()) {
        return;
    }
    auto *job = KIO::trash(urls);
    connect(job, &KJob::result, this, [this](KJob *job) {
        if (!job->error()) {
            checkTrash();
        } else {
            qWarning() << "KIO::trash error:" << job->errorString();
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
    qDebug() << "DockBackend::copyToDownloads() CALLED with" << urls;
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

QVariantList DockBackend::finderPlaces() const
{
    QVariantList list;
    QSet<QString> addedPaths;

    auto addPlace = [&list, &addedPaths](const QString &title, const QString &path, const QString &icon) {
        if (!path.isEmpty() && !addedPaths.contains(path)) {
            addedPaths.insert(path);
            QVariantMap m;
            m.insert(QStringLiteral("title"), title);
            m.insert(QStringLiteral("path"), path);
            m.insert(QStringLiteral("icon"), icon.isEmpty() ? QStringLiteral("folder") : icon);
            list.append(m);
        }
    };

    // 1. Parse user places from ~/.local/share/user-places.xbel (Dolphin Places / Favoritos)
    const QString xbelPath = QDir::homePath() + QStringLiteral("/.local/share/user-places.xbel");
    QFile file(xbelPath);
    if (file.open(QIODevice::ReadOnly)) {
        QXmlStreamReader xml(&file);
        QString currentHref;
        QString currentTitle;
        QString currentIcon;
        bool isHidden = false;

        while (!xml.atEnd()) {
            xml.readNext();
            if (xml.isStartElement()) {
                if (xml.name() == QLatin1String("bookmark")) {
                    currentHref = xml.attributes().value(QLatin1String("href")).toString();
                    currentTitle.clear();
                    currentIcon.clear();
                    isHidden = false;
                } else if (xml.name() == QLatin1String("title")) {
                    currentTitle = xml.readElementText();
                } else if (xml.name() == QLatin1String("icon")) {
                    currentIcon = xml.attributes().value(QLatin1String("name")).toString();
                } else if (xml.name() == QLatin1String("IsHidden")) {
                    if (xml.readElementText() == QLatin1String("true")) {
                        isHidden = true;
                    }
                }
            } else if (xml.isEndElement() && xml.name() == QLatin1String("bookmark")) {
                if (!isHidden && !currentHref.isEmpty() && !currentHref.startsWith(QLatin1String("recentlyused:"))) {
                    QUrl url(currentHref);
                    QString path = url.isLocalFile() ? url.toLocalFile() : currentHref;
                    QString title = currentTitle;

                    if (title == QLatin1String("Home")) title = tr("Carpeta personal");
                    else if (title == QLatin1String("Desktop")) title = tr("Escritorio");
                    else if (title == QLatin1String("Downloads")) title = tr("Descargas");
                    else if (title == QLatin1String("Documents")) title = tr("Documentos");
                    else if (title == QLatin1String("Pictures")) title = tr("Imágenes");
                    else if (title == QLatin1String("Music")) title = tr("Música");
                    else if (title == QLatin1String("Videos")) title = tr("Vídeos");
                    else if (title == QLatin1String("Trash")) title = tr("Papelera");
                    else if (title == QLatin1String("Network")) title = tr("Red");

                    addPlace(title, path, currentIcon);
                }
            }
        }
    }

    // Fallbacks si xbel estaba vacío o ausente
    if (list.isEmpty()) {
        addPlace(tr("Carpeta personal"), QDir::homePath(), QStringLiteral("user-home"));
        addPlace(tr("Descargas"), QStandardPaths::writableLocation(QStandardPaths::DownloadLocation), QStringLiteral("folder-download"));
        addPlace(tr("Documentos"), QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation), QStringLiteral("folder-documents"));
        addPlace(tr("Escritorio"), QStandardPaths::writableLocation(QStandardPaths::DesktopLocation), QStringLiteral("user-desktop"));
        addPlace(tr("Imágenes"), QStandardPaths::writableLocation(QStandardPaths::PicturesLocation), QStringLiteral("folder-pictures"));
        addPlace(tr("Música"), QStandardPaths::writableLocation(QStandardPaths::MusicLocation), QStringLiteral("folder-music"));
        addPlace(tr("Vídeos"), QStandardPaths::writableLocation(QStandardPaths::MoviesLocation), QStringLiteral("folder-videos"));
        addPlace(tr("Papelera"), QStringLiteral("trash:/"), QStringLiteral("user-trash"));
        addPlace(tr("Red"), QStringLiteral("remote:/"), QStringLiteral("network-workgroup"));
    }

    // 2. Integración automática de montajes / carpetas multimedia dedicadas (/media/Vídeos y /media/Música)
    if (QDir(QStringLiteral("/media/Vídeos")).exists()) {
        addPlace(tr("Vídeos (/media)"), QStringLiteral("/media/Vídeos"), QStringLiteral("folder-videos"));
    }
    if (QDir(QStringLiteral("/media/Música")).exists()) {
        addPlace(tr("Música (/media)"), QStringLiteral("/media/Música"), QStringLiteral("folder-music"));
    }

    return list;
}

void DockBackend::openFolder(const QString &path)
{
    qDebug() << "DockBackend::openFolder() CALLED with" << path;
    if (path.isEmpty()) {
        return;
    }
    if (QProcess::startDetached(QStringLiteral("dolphin"), {path})) {
        return;
    }
    QDesktopServices::openUrl(path.contains(QLatin1String(":/")) ? QUrl(path) : QUrl::fromLocalFile(path));
}

void DockBackend::openNewDolphinWindow(const QString &path)
{
    qDebug() << "DockBackend::openNewDolphinWindow() CALLED with" << path;
    const QString target = path.isEmpty() ? QDir::homePath() : path;
    if (QProcess::startDetached(QStringLiteral("dolphin"), {QStringLiteral("--new-window"), target})) {
        return;
    }
    openFolder(target);
}

void DockBackend::relaunchDolphin()
{
    qDebug() << "DockBackend::relaunchDolphin() CALLED";
    QProcess::execute(QStringLiteral("killall"), {QStringLiteral("dolphin")});
    QTimer::singleShot(250, []() {
        QProcess::startDetached(QStringLiteral("dolphin"), {});
    });
}

QVariantList DockBackend::jumpListActions(const QString &launcherUrl) const
{
    QVariantList list;
    if (launcherUrl.isEmpty()) {
        return list;
    }

    QString id = launcherUrl;
    if (id.startsWith(QLatin1String("applications:"))) {
        id.remove(0, 13);
    } else if (id.startsWith(QLatin1String("application://"))) {
        id.remove(0, 14);
    } else if (id.startsWith(QLatin1String("file://"))) {
        id.remove(0, 7);
    }

    KService::Ptr service = KService::serviceByStorageId(id);
    if (!service && id.endsWith(QLatin1String(".desktop"))) {
        service = KService::serviceByDesktopName(id.left(id.length() - 8));
    }
    if (!service) {
        service = KService::serviceByDesktopName(id);
    }

    if (service) {
        const auto actions = service->actions();
        for (const auto &act : actions) {
            if (!act.noDisplay()) {
                QVariantMap m;
                m.insert(QStringLiteral("name"), act.name());
                m.insert(QStringLiteral("text"), act.text());
                m.insert(QStringLiteral("icon"), act.icon());
                m.insert(QStringLiteral("exec"), act.exec());
                list.append(m);
            }
        }
    }

    return list;
}

void DockBackend::executeServiceAction(const QString &launcherUrl, const QString &actionName)
{
    qDebug() << "DockBackend::executeServiceAction() CALLED with" << launcherUrl << actionName;
    QString id = launcherUrl;
    if (id.startsWith(QLatin1String("applications:"))) {
        id.remove(0, 13);
    } else if (id.startsWith(QLatin1String("application://"))) {
        id.remove(0, 14);
    } else if (id.startsWith(QLatin1String("file://"))) {
        id.remove(0, 7);
    }

    KService::Ptr service = KService::serviceByStorageId(id);
    if (!service && id.endsWith(QLatin1String(".desktop"))) {
        service = KService::serviceByDesktopName(id.left(id.length() - 8));
    }
    if (!service) {
        service = KService::serviceByDesktopName(id);
    }

    if (service) {
        const auto actions = service->actions();
        for (const auto &act : actions) {
            if (act.name() == actionName) {
                auto *job = new KIO::ApplicationLauncherJob(act);
                job->setUiDelegate(KIO::createDefaultJobUiDelegate());
                job->start();
                return;
            }
        }
    }
}
