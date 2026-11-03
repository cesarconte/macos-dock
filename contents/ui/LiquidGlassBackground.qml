/*
    SPDX-FileCopyrightText: 2024 Matt Anis
    SPDX-FileCopyrightText: 2026 Cesar

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: root

    property real radius: Math.min(width, height) / 3
    // 0 = Solid, 1 = Transparent (Panel Colorizer / Native), 2 = Translucent, 3 = LiquidGlass, 4 = LiquidGlass
    property int backgroundType: 1
    property color customBackgroundColor: "#202024"
    property int customBorderWidth: 1
    property color customBorderColor: "#38ffffff"
    property bool isVertical: false

    property real blurOpacity: 0.35
    property real blurSaturation: 1.3
    property real blurContrast: 1.0
    property real blurBrightness: 1.0

    // ==========================================
    // MODE 0: SOLID BACKGROUND
    // ==========================================
    Rectangle {
        id: solidBackground
        visible: root.backgroundType === 0
        anchors.fill: parent
        radius: root.radius
        color: root.customBackgroundColor
        border.color: root.customBorderWidth > 0 ? root.customBorderColor : "transparent"
        border.width: root.customBorderWidth
    }

    // ==========================================
    // MODE 1: TRANSPARENT (PANEL COLORIZER / NATIVE PANEL)
    // ==========================================
    // When using Panel Colorizer, the panel container handles the blur, background,
    // borders, and floating margin. No duplicate elements are rendered.

    // ==========================================
    // MODE 2: TRANSLUCENT CAPSULE
    // ==========================================
    Rectangle {
        id: translucentBackground
        visible: root.backgroundType === 2
        anchors.fill: parent
        radius: root.radius
        color: Qt.rgba(root.customBackgroundColor.r, root.customBackgroundColor.g, root.customBackgroundColor.b, root.blurOpacity)
        border.color: root.customBorderWidth > 0 ? root.customBorderColor : "transparent"
        border.width: root.customBorderWidth
    }

    // ==========================================
    // MODE 3 & 4: LIQUID GLASS (STANDALONE GLASS)
    // ==========================================
    Item {
        id: liquidGlassContainer
        visible: root.backgroundType === 3 || root.backgroundType === 4
        anchors.fill: parent

        Rectangle {
            id: glassBase
            anchors.fill: parent
            radius: root.radius
            color: {
                const isDark = Kirigami.Theme.backgroundColor.hslLightness < 0.5;
                return isDark
                    ? Qt.rgba(0.12, 0.12, 0.15, root.blurOpacity)
                    : Qt.rgba(0.96, 0.97, 1.0, root.blurOpacity);
            }
            border.color: root.customBorderWidth > 0 ? root.customBorderColor : "transparent"
            border.width: root.customBorderWidth

            // Internal gloss sheen
            Rectangle {
                anchors.fill: parent
                anchors.margins: Math.max(0, root.customBorderWidth)
                radius: Math.max(0, root.radius - root.customBorderWidth)
                color: "transparent"
                gradient: Gradient {
                    orientation: root.isVertical ? Gradient.Horizontal : Gradient.Vertical
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.16) }
                    GradientStop { position: 0.35; color: Qt.rgba(1, 1, 1, 0.04) }
                    GradientStop { position: 0.75; color: Qt.rgba(1, 1, 1, 0.01) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.06) }
                }
            }
        }
    }
}
