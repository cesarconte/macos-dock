/*
    SPDX-FileCopyrightText: 2026 Cesar <yugurta@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

Item {
    id: progressOverlay
    anchors.fill: parent

    readonly property real progressVal: (typeof task !== "undefined" && task) ? task.taskProgress : 0.0

    // macOS Progress Pill Track
    Rectangle {
        id: track
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.max(2, Math.round(parent.height * 0.06))

        width: Math.round(parent.width * 0.75)
        height: Math.max(4, Math.round(parent.height * 0.09))
        radius: height / 2
        clip: true

        color: Qt.rgba(0, 0, 0, 0.65)
        border.color: Qt.rgba(255, 255, 255, 0.35)
        border.width: 1

        // Progress Fill
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.max(0, Math.round(parent.width * Math.min(1.0, Math.max(0.0, progressOverlay.progressVal))))
            radius: parent.radius

            gradient: Gradient {
                GradientStop { position: 0.0; color: "#FFFFFF" }
                GradientStop { position: 1.0; color: "#DCDCDC" }
            }
        }
    }
}
