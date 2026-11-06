/*
    SPDX-FileCopyrightText: 2026 Cesar <yugurta@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <Plasma/Corona>
#include <memory>

class DockView;
namespace Plasma {
class Applet;
}

class DockCorona : public Plasma::Corona
{
    Q_OBJECT

public:
    explicit DockCorona(QObject *parent = nullptr);
    ~DockCorona() override;

    QRect screenGeometry(uint id) const override;

    void init();
    void showConfigurationInterface();

public Q_SLOTS:
    void recreateView();
    void onPrepareForSleep(bool sleeping);
    void onScreenSaverActiveChanged(bool active);
    void toggleLaunchpad();
    void openTrash();
    void emptyTrash();
    void openDownloads();

private:
    Plasma::Containment *m_containment = nullptr;
    std::unique_ptr<DockView> m_view;
    Plasma::Applet *m_drawerApplet = nullptr;
};
