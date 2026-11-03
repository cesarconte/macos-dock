/*
    SPDX-FileCopyrightText: 2026 Cesar <yugurta@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <Plasma/Corona>
#include <memory>

class DockView;

class DockCorona : public Plasma::Corona
{
    Q_OBJECT

public:
    explicit DockCorona(QObject *parent = nullptr);
    ~DockCorona() override;

    QRect screenGeometry(uint id) const override;

    void init();
    void showConfigurationInterface();

private:
    Plasma::Containment *m_containment = nullptr;
    std::unique_ptr<DockView> m_view;
};
