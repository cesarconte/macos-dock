/*
    SPDX-FileCopyrightText: 2026 Cesar
    SPDX-License-Identifier: GPL-3.0-or-later
*/

#include <QGuiApplication>
#include <QLoggingCategory>
#include <QQuickWindow>
#include <QQuickItem>
#include <QTest>
#include <QTimer>

#include "dockcorona.h"
#include "dockview.h"
#include "LayoutAuditor.h"

#include <plasma/applet.h>
#include <plasma/containment.h>

class TestLayoutAudit : public QObject
{
    Q_OBJECT
public:
    TestLayoutAudit() = default;

private Q_SLOTS:
    void initTestCase();
    void cleanupTestCase();
    void auditCapsule();
    void auditWidthSweep();

private:
    DockCorona *m_corona = nullptr;
    DockView *m_view = nullptr;
    Plasma::Applet *m_applet = nullptr;
};

void TestLayoutAudit::initTestCase()
{
    m_corona = new DockCorona();
    m_corona->init();

    if (!m_corona->containments().isEmpty()) {
        auto c = m_corona->containments().constFirst();
        if (!c->applets().isEmpty()) {
            m_applet = c->applets().constFirst();
        }
    }
    if (!m_applet) {
        QFAIL("No applet available");
    }

    m_view = new DockView(m_corona);
    m_view->setApplet(m_applet);
    m_view->resize(1280, 128);
    m_view->show();
    QTest::qWait(800);
}

void TestLayoutAudit::cleanupTestCase()
{
    if (m_view) m_view->hide();
    delete m_view;
    delete m_corona;
}

void TestLayoutAudit::auditCapsule()
{
    auto violations = LayoutAuditor::audit(m_view->contentItem());
    for (auto &v : violations) {
        QFAIL(qPrintable(v.toString()));
    }
}

void TestLayoutAudit::auditWidthSweep()
{
    QQuickItem *root = m_view->contentItem();
    if (!root->childItems().isEmpty()) {
        root = root->childItems().constFirst();
    }

    // Hover magnification state.
    root->setProperty("isMouseOverDock", true);
    root->setProperty("dockHoverProgress", 1.0);
    root->setProperty("continuousHoverPosition", 2.0);
    root->setProperty("hoveredTaskIndex", 2);

    for (int w = 620; w <= 1440; w += 3) {
        m_view->resize(w, 128);
        QTest::qWait(1);
        auto violations = LayoutAuditor::audit(m_view->contentItem());
        for (auto &v : violations) {
            QFAIL(qPrintable(QStringLiteral("hover width=%1: %2").arg(w).arg(v.toString())));
        }
    }

    root->setProperty("isMouseOverDock", false);
    root->setProperty("dockHoverProgress", 0.0);
    root->setProperty("continuousHoverPosition", -1.0);
    root->setProperty("hoveredTaskIndex", -1);

    for (int w = 620; w <= 1440; w += 3) {
        m_view->resize(w, 128);
        QTest::qWait(1);
        auto violations = LayoutAuditor::audit(m_view->contentItem());
        for (auto &v : violations) {
            QFAIL(qPrintable(QStringLiteral("idle width=%1: %2").arg(w).arg(v.toString())));
        }
    }
}

int main(int argc, char *argv[])
{
    qputenv("QT_QPA_PLATFORM", "offscreen");
    QLoggingCategory::setFilterRules(QStringLiteral("kf.windowsystem.warning=false\n"));

    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("macos-dock"));

    TestLayoutAudit tc;
    return QTest::qExec(&tc, argc, argv);
}

#include "test_layout_audit.moc"
