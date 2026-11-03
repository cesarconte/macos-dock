/*
    SPDX-FileCopyrightText: 2026 Cesar <yugurta@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

Item {
    id: root
    anchors.fill: parent

    readonly property bool hasBadge: task.smartLauncherItem && task.smartLauncherItem.countVisible && task.smartLauncherItem.count > 0

    Badge {
        id: badgeRect

        anchors.top: parent.top
        anchors.topMargin: -Math.round(height * 0.15)
        anchors.right: parent.right
        anchors.rightMargin: -Math.round(height * 0.15)

        height: Math.max(16, Math.round(parent.height * 0.42))
        visible: root.hasBadge
        number: task.smartLauncherItem ? task.smartLauncherItem.count : 0

        scale: visible ? 1.0 : 0.0
        opacity: visible ? 1.0 : 0.0

        Behavior on scale {
            NumberAnimation { duration: 180; easing.type: Easing.OutBack }
        }
        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }
    }
}
