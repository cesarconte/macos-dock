/*
    SPDX-FileCopyrightText: 2026 Cesar <yugurta@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

Item {
    id: badgeRect

    property alias text: label.text
    property alias textColor: label.color
    property int number: 0

    readonly property bool isSingleDigit: number >= 0 && number < 10

    implicitHeight: 20
    implicitWidth: isSingleDigit ? height : Math.max(height, label.contentWidth + height * 0.55)

    // Soft drop shadow
    Rectangle {
        anchors.fill: bg
        anchors.topMargin: 1.5
        radius: bg.radius
        color: Qt.rgba(0, 0, 0, 0.35)
        z: 0
    }

    // Notification badge pill
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: height / 2
        z: 1

        gradient: Gradient {
            GradientStop { position: 0.0; color: "#FF4D42" }
            GradientStop { position: 1.0; color: "#D70015" }
        }

        border.color: "#FFFFFF"
        border.width: Math.max(1.2, Math.round(badgeRect.height * 0.08))

        Text {
            id: label
            anchors.centerIn: parent
            color: "#FFFFFF"
            font.bold: true
            font.pixelSize: Math.max(8, Math.round(badgeRect.height * 0.58))
            font.family: "Cantarell, Noto Sans, sans-serif"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: {
                if (badgeRect.number < 0) {
                    return "—";
                } else if (badgeRect.number > 9999) {
                    return "9999+";
                } else {
                    return badgeRect.number.toString();
                }
            }
        }
    }
}
