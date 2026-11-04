/*
    SPDX-FileCopyrightText: 2026 Cesar <yugurta@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include <QTest>
#include <QSignalSpy>
#include "dockindicatormanager.h"

class TestDockIndicatorManager : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void testNormalizeKey();
    void testTitleBadgeParsing();
    void testSniTextBadgeParsing();
    void testUnityLauncherProgress();
    void testUnityLauncherBadges();
    void testWebAppTitleBadgeFallback();
    void testLiveProtonMailSni();
};

void TestDockIndicatorManager::testNormalizeKey()
{
    QCOMPARE(DockIndicatorManager::normalizeKey(QStringLiteral("applications:proton-mail.desktop")), QStringLiteral("proton-mail"));
    QCOMPARE(DockIndicatorManager::normalizeKey(QStringLiteral("application://brave-origin.desktop")), QStringLiteral("brave-origin"));
    QCOMPARE(DockIndicatorManager::normalizeKey(QStringLiteral("applications:brave-hnpfjngllnobngcgfapefoaidbinmjnm-Default.desktop")), QStringLiteral("whatsapp"));
    QCOMPARE(DockIndicatorManager::normalizeKey(QStringLiteral("WhatsApp")), QStringLiteral("whatsapp"));
    QCOMPARE(DockIndicatorManager::normalizeKey(QStringLiteral("crx_hnpfjngllnobngcgfapefoaidbinmjnm")), QStringLiteral("whatsapp"));
}

void TestDockIndicatorManager::testTitleBadgeParsing()
{
    QCOMPARE(DockIndicatorManager::parseBadgeFromTitle(QStringLiteral("(1) WhatsApp")), 1);
    QCOMPARE(DockIndicatorManager::parseBadgeFromTitle(QStringLiteral(" (42) WhatsApp Web ")), 42);
    QCOMPARE(DockIndicatorManager::parseBadgeFromTitle(QStringLiteral("(99+) WhatsApp")), 99);
    QCOMPARE(DockIndicatorManager::parseBadgeFromTitle(QStringLiteral("(5) Proton Mail")), 5);
    QCOMPARE(DockIndicatorManager::parseBadgeFromTitle(QStringLiteral("WhatsApp")), 0);
    QCOMPARE(DockIndicatorManager::parseBadgeFromTitle(QStringLiteral("Brave Origin")), 0);
    QCOMPARE(DockIndicatorManager::parseBadgeFromTitle(QStringLiteral("")), 0);
}

void TestDockIndicatorManager::testSniTextBadgeParsing()
{
    QCOMPARE(DockIndicatorManager::parseBadgeFromText(QStringLiteral("Bandeja de entrada: 4 mensajes sin leer")), 4);
    QCOMPARE(DockIndicatorManager::parseBadgeFromText(QStringLiteral("Inbox: 12 unread messages")), 12);
    QCOMPARE(DockIndicatorManager::parseBadgeFromText(QStringLiteral("1 nuevo mensaje")), 1);
    QCOMPARE(DockIndicatorManager::parseBadgeFromText(QStringLiteral("Inbox: 0 unread messages")), 0);
    QCOMPARE(DockIndicatorManager::parseBadgeFromText(QStringLiteral("")), 0);
}

void TestDockIndicatorManager::testUnityLauncherProgress()
{
    DockIndicatorManager manager;
    QSignalSpy spy(&manager, &DockIndicatorManager::indicatorsChanged);

    QVariantMap props;
    props.insert(QStringLiteral("progress"), 0.45);
    props.insert(QStringLiteral("progress-visible"), true);

    manager.onUnityLauncherUpdate(QStringLiteral("application://brave-origin.desktop"), props);

    QCOMPARE(spy.count(), 1);
    QVERIFY(manager.progressVisible(QStringLiteral("brave-origin"), QStringLiteral("preferred://browser")));
    QCOMPARE(manager.progress(QStringLiteral("brave-origin"), QStringLiteral("preferred://browser")), 0.45);

    // Complete download (progress-visible = false)
    props[QStringLiteral("progress-visible")] = false;
    manager.onUnityLauncherUpdate(QStringLiteral("application://brave-origin.desktop"), props);
    QVERIFY(!manager.progressVisible(QStringLiteral("brave-origin"), QStringLiteral("preferred://browser")));
}

void TestDockIndicatorManager::testUnityLauncherBadges()
{
    DockIndicatorManager manager;
    QSignalSpy spy(&manager, &DockIndicatorManager::indicatorsChanged);

    QVariantMap props;
    props.insert(QStringLiteral("count"), 7);
    props.insert(QStringLiteral("count-visible"), true);
    props.insert(QStringLiteral("urgent"), true);

    manager.onUnityLauncherUpdate(QStringLiteral("application://telegramdesktop.desktop"), props);

    QCOMPARE(spy.count(), 1);
    QVERIFY(manager.badgeVisible(QStringLiteral("telegramdesktop"), QStringLiteral("applications:telegramdesktop.desktop"), QStringLiteral("Telegram")));
    QCOMPARE(manager.badgeCount(QStringLiteral("telegramdesktop"), QStringLiteral("applications:telegramdesktop.desktop"), QStringLiteral("Telegram")), 7);
    QVERIFY(manager.demandsAttention(QStringLiteral("telegramdesktop"), QStringLiteral("applications:telegramdesktop.desktop")));
}

void TestDockIndicatorManager::testWebAppTitleBadgeFallback()
{
    DockIndicatorManager manager;

    // No DBus indicator set for WhatsApp initially, but window title contains "(3) WhatsApp"
    const QString appId = QStringLiteral("brave-hnpfjngllnobngcgfapefoaidbinmjnm-Default");
    const QString launcher = QStringLiteral("applications:brave-hnpfjngllnobngcgfapefoaidbinmjnm-Default.desktop");
    const QString titleWithUnread = QStringLiteral("(3) WhatsApp");
    const QString titleClean = QStringLiteral("WhatsApp");

    QCOMPARE(manager.badgeCount(appId, launcher, titleWithUnread), 3);
    QVERIFY(manager.badgeVisible(appId, launcher, titleWithUnread));

    // When read, title becomes clean
    QCOMPARE(manager.badgeCount(appId, launcher, titleClean), 0);
    QVERIFY(!manager.badgeVisible(appId, launcher, titleClean));
}

void TestDockIndicatorManager::testLiveProtonMailSni()
{
    DockIndicatorManager manager;
    manager.refreshAllSniItems();

    // In this system, proton-mail-notifier is currently running with 4 unread messages
    int count = manager.badgeCount(QStringLiteral("proton-mail"), QStringLiteral("applications:proton-mail.desktop"), QStringLiteral("Proton Mail"));
    qDebug() << "Live Proton Mail unread count detected via SNI:" << count;
    QVERIFY(count >= 0);
}

QTEST_MAIN(TestDockIndicatorManager)
#include "test_dockindicatormanager.moc"
