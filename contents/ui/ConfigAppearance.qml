/*
    SPDX-FileCopyrightText: 2013 Eike Hein <hein@kde.org>
    SPDX-FileCopyrightText: 2024 Matt Anis

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs as QtDialogs

import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

KCMUtils.SimpleKCM {
    id: root

    readonly property bool plasmaPaAvailable: Qt.createComponent("PulseAudio.qml").status === Component.Ready
    readonly property bool plasmoidVertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool iconOnly: true

    property alias cfg_iconSize: iconSizeSpinBox.value
    property alias cfg_iconSpacing: iconSpacingSpinBox.value
    property alias cfg_elevation: elevationSpinBox.value
    property alias cfg_horizontalPadding: horizontalPaddingSpinBox.value
    property alias cfg_verticalPadding: verticalPaddingSpinBox.value

    property alias cfg_zoomEnabled: zoomEnabledCheckBox.checked
    property alias cfg_zoomAnimationType: zoomAnimationTypeComboBox.currentIndex
    property real cfg_zoomMultiplier: Plasmoid.configuration.zoomMultiplier !== undefined ? Plasmoid.configuration.zoomMultiplier : 1.5
    property alias cfg_zoomBlastRadius: zoomBlastRadiusSpinBox.value
    property alias cfg_hoverElevation: hoverElevationSpinBox.value

    property alias cfg_containerBackgroundType: containerBackgroundTypeComboBox.currentIndex
    property color cfg_containerBackgroundColor: Plasmoid.configuration.containerBackgroundColor || "#202024"
    property real cfg_blurOpacity: Plasmoid.configuration.blurOpacity !== undefined ? Plasmoid.configuration.blurOpacity : 0.35
    property real cfg_blurSaturation: Plasmoid.configuration.blurSaturation !== undefined ? Plasmoid.configuration.blurSaturation : 1.3
    property real cfg_blurContrast: Plasmoid.configuration.blurContrast !== undefined ? Plasmoid.configuration.blurContrast : 1.0
    property real cfg_blurBrightness: Plasmoid.configuration.blurBrightness !== undefined ? Plasmoid.configuration.blurBrightness : 1.0
    property alias cfg_containerBorderWidth: containerBorderWidthSpinBox.value
    property color cfg_containerBorderColor: Plasmoid.configuration.containerBorderColor || "#38ffffff"
    property alias cfg_autoAdjustPanelThickness: autoAdjustPanelThicknessCheckBox.checked

    onCfg_zoomMultiplierChanged: {
        zoomMultiplierSpinBox.value = Math.round(cfg_zoomMultiplier * 10);
    }
    onCfg_blurOpacityChanged: {
        blurOpacitySpinBox.value = Math.round(cfg_blurOpacity * 100);
    }
    onCfg_blurSaturationChanged: {
        blurSaturationSpinBox.value = Math.round(cfg_blurSaturation * 10);
    }
    onCfg_blurContrastChanged: {
        blurContrastSpinBox.value = Math.round(cfg_blurContrast * 10);
    }
    onCfg_blurBrightnessChanged: {
        blurBrightnessSpinBox.value = Math.round(cfg_blurBrightness * 10);
    }

    property alias cfg_showToolTips: showToolTips.checked
    property alias cfg_highlightWindows: highlightWindows.checked
    property bool cfg_indicateAudioStreams
    property bool cfg_interactiveMute
    property bool cfg_tooltipControls

    // Legacy / fallback bindings to preserve config schema compatibility
    property alias cfg_fill: fill.checked
    property alias cfg_maxStripes: maxStripes.value
    property alias cfg_forceStripes: forceStripes.checked
    property alias cfg_taskMaxWidth: taskMaxWidth.currentIndex

    Component.onCompleted: {
        if (maxStripes.value === 1) {
            forbidStripes.checked = true;
        } else if (!Plasmoid.configuration.forceStripes && maxStripes.value > 1) {
            allowStripes.checked = true;
        } else if (Plasmoid.configuration.forceStripes && maxStripes.value > 1) {
            forceStripes.checked = true;
        }
    }

    Kirigami.FormLayout {
        // ==========================================
        // 1. ICONS & DIMENSIONS
        // ==========================================
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18nc("@title:group", "Icons & Dimensions")
        }

        QQC2.SpinBox {
            id: iconSizeSpinBox
            Kirigami.FormData.label: i18nc("@label:spinbox", "Icon size (px):")
            from: 24
            to: 256
            stepSize: 4
            value: Plasmoid.configuration.iconSize || 48
        }

        QQC2.SpinBox {
            id: iconSpacingSpinBox
            Kirigami.FormData.label: i18nc("@label:spinbox", "Icon spacing (px):")
            from: 0
            to: 64
            stepSize: 1
            value: Plasmoid.configuration.iconSpacing !== undefined ? Plasmoid.configuration.iconSpacing : 4
        }

        QQC2.SpinBox {
            id: elevationSpinBox
            Kirigami.FormData.label: i18nc("@label:spinbox", "Elevation offset (px):")
            from: 0
            to: 64
            stepSize: 1
            value: Plasmoid.configuration.elevation !== undefined ? Plasmoid.configuration.elevation : 8
        }

        QQC2.SpinBox {
            id: horizontalPaddingSpinBox
            Kirigami.FormData.label: i18nc("@label:spinbox", "Horizontal padding (px):")
            from: 0
            to: 64
            stepSize: 1
            value: Plasmoid.configuration.horizontalPadding !== undefined ? Plasmoid.configuration.horizontalPadding : 10
        }

        QQC2.SpinBox {
            id: verticalPaddingSpinBox
            Kirigami.FormData.label: i18nc("@label:spinbox", "Vertical padding (px):")
            from: 0
            to: 64
            stepSize: 1
            value: Plasmoid.configuration.verticalPadding !== undefined ? Plasmoid.configuration.verticalPadding : 8
        }

        QQC2.CheckBox {
            id: fill
            text: i18nc("@option:check section General", "Fill free space on panel")
        }

        // ==========================================
        // 2. MAGNIFICATION & ANIMATION
        // ==========================================
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18nc("@title:group", "Magnification & Animation")
        }

        QQC2.CheckBox {
            id: zoomEnabledCheckBox
            Kirigami.FormData.label: i18nc("@label:checkbox", "Magnification:")
            text: i18nc("@option:check", "Magnify icons on hover")
            checked: Plasmoid.configuration.zoomEnabled !== undefined ? Plasmoid.configuration.zoomEnabled : true
        }

        QQC2.ComboBox {
            id: zoomAnimationTypeComboBox
            visible: zoomEnabledCheckBox.checked
            Kirigami.FormData.label: i18nc("@label:combobox", "Animation physics:")
            model: [
                i18nc("@item:inlistbox", "Spring physics (Elastic & snappy)"),
                i18nc("@item:inlistbox", "Smooth (Cubic ease-out)")
            ]
            currentIndex: Plasmoid.configuration.zoomAnimationType !== undefined ? Plasmoid.configuration.zoomAnimationType : 0
        }

        QQC2.SpinBox {
            id: zoomMultiplierSpinBox
            visible: zoomEnabledCheckBox.checked
            Kirigami.FormData.label: i18nc("@label:spinbox", "Zoom scale:")
            from: 10
            to: 35
            stepSize: 1
            value: Math.round((Plasmoid.configuration.zoomMultiplier !== undefined ? Plasmoid.configuration.zoomMultiplier : 1.5) * 10)
            textFromValue: function(value, locale) {
                return (value / 10.0).toFixed(1) + "x";
            }
            valueFromText: function(text, locale) {
                return Math.round(parseFloat(text) * 10);
            }
            onValueChanged: {
                root.cfg_zoomMultiplier = value / 10.0;
            }
        }

        QQC2.SpinBox {
            id: zoomBlastRadiusSpinBox
            visible: zoomEnabledCheckBox.checked
            Kirigami.FormData.label: i18nc("@label:spinbox", "Blast radius (icons):")
            from: 1
            to: 4
            stepSize: 1
            value: Plasmoid.configuration.zoomBlastRadius !== undefined ? Plasmoid.configuration.zoomBlastRadius : 2
        }

        QQC2.SpinBox {
            id: hoverElevationSpinBox
            visible: zoomEnabledCheckBox.checked
            Kirigami.FormData.label: i18nc("@label:spinbox", "Hover lift (px):")
            from: 0
            to: 32
            stepSize: 2
            value: Plasmoid.configuration.hoverElevation !== undefined ? Plasmoid.configuration.hoverElevation : 12
        }

        // ==========================================
        // 3. CAPSULE & STYLE
        // ==========================================
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18nc("@title:group", "Capsule & Style")
        }

        QQC2.ComboBox {
            id: containerBackgroundTypeComboBox
            Kirigami.FormData.label: i18nc("@label:combobox", "Container background:")
            model: [
                i18nc("@option:combobox", "Solid"),
                i18nc("@option:combobox", "Transparent (Recommended for Panel Colorizer)"),
                i18nc("@option:combobox", "Translucent"),
                i18nc("@option:combobox", "Liquid Glass")
            ]
            currentIndex: Plasmoid.configuration.containerBackgroundType !== undefined ? Plasmoid.configuration.containerBackgroundType : 1
        }

        RowLayout {
            visible: containerBackgroundTypeComboBox.currentIndex === 0 || containerBackgroundTypeComboBox.currentIndex === 2
            Kirigami.FormData.label: i18nc("@label", "Background color:")
            spacing: Kirigami.Units.smallSpacing

            Rectangle {
                width: Kirigami.Units.gridUnit * 1.5
                height: Kirigami.Units.gridUnit * 1.5
                radius: Kirigami.Units.smallSpacing
                color: root.cfg_containerBackgroundColor
                border.color: Kirigami.Theme.separatorColor
                border.width: 1
            }

            QQC2.Button {
                text: i18nc("@action:button", "Choose Color…")
                icon.name: "color-picker"
                onClicked: bgColorDialog.open()
            }

            QtDialogs.ColorDialog {
                id: bgColorDialog
                selectedColor: root.cfg_containerBackgroundColor
                onAccepted: {
                    root.cfg_containerBackgroundColor = selectedColor;
                }
            }
        }

        QQC2.SpinBox {
            id: blurOpacitySpinBox
            visible: containerBackgroundTypeComboBox.currentIndex === 2 || containerBackgroundTypeComboBox.currentIndex >= 3
            Kirigami.FormData.label: i18nc("@label:spinbox", "Capsule opacity:")
            from: 5
            to: 95
            stepSize: 5
            value: Math.round((Plasmoid.configuration.blurOpacity !== undefined ? Plasmoid.configuration.blurOpacity : 0.35) * 100)
            textFromValue: function(value, locale) {
                return value + "%";
            }
            valueFromText: function(text, locale) {
                return parseInt(text.replace("%", ""), 10) || 0;
            }
            onValueChanged: {
                root.cfg_blurOpacity = value / 100.0;
            }
        }

        QQC2.SpinBox {
            id: blurSaturationSpinBox
            visible: containerBackgroundTypeComboBox.currentIndex >= 3
            Kirigami.FormData.label: i18nc("@label:spinbox", "Vibrancy (saturation):")
            from: 0
            to: 20
            stepSize: 1
            value: Math.round((Plasmoid.configuration.blurSaturation !== undefined ? Plasmoid.configuration.blurSaturation : 1.3) * 10)
            textFromValue: function(value, locale) {
                return (value / 10.0).toFixed(1) + "x";
            }
            valueFromText: function(text, locale) {
                return Math.round(parseFloat(text) * 10) || 0;
            }
            onValueChanged: {
                root.cfg_blurSaturation = value / 10.0;
            }
        }

        QQC2.SpinBox {
            id: blurContrastSpinBox
            visible: containerBackgroundTypeComboBox.currentIndex >= 3
            Kirigami.FormData.label: i18nc("@label:spinbox", "Blur contrast:")
            from: 5
            to: 15
            stepSize: 1
            value: Math.round((Plasmoid.configuration.blurContrast !== undefined ? Plasmoid.configuration.blurContrast : 1.0) * 10)
            textFromValue: function(value, locale) {
                return (value / 10.0).toFixed(1) + "x";
            }
            valueFromText: function(text, locale) {
                return Math.round(parseFloat(text) * 10) || 0;
            }
            onValueChanged: {
                root.cfg_blurContrast = value / 10.0;
            }
        }

        QQC2.SpinBox {
            id: blurBrightnessSpinBox
            visible: containerBackgroundTypeComboBox.currentIndex >= 3
            Kirigami.FormData.label: i18nc("@label:spinbox", "Blur brightness:")
            from: 5
            to: 15
            stepSize: 1
            value: Math.round((Plasmoid.configuration.blurBrightness !== undefined ? Plasmoid.configuration.blurBrightness : 1.0) * 10)
            textFromValue: function(value, locale) {
                return (value / 10.0).toFixed(1) + "x";
            }
            valueFromText: function(text, locale) {
                return Math.round(parseFloat(text) * 10) || 0;
            }
            onValueChanged: {
                root.cfg_blurBrightness = value / 10.0;
            }
        }

        QQC2.SpinBox {
            id: containerBorderWidthSpinBox
            visible: containerBackgroundTypeComboBox.currentIndex !== 1
            Kirigami.FormData.label: i18nc("@label:spinbox", "Border thickness (px):")
            from: 0
            to: 10
            stepSize: 1
            value: Plasmoid.configuration.containerBorderWidth !== undefined ? Plasmoid.configuration.containerBorderWidth : 1
        }

        RowLayout {
            visible: containerBackgroundTypeComboBox.currentIndex !== 1 && containerBorderWidthSpinBox.value > 0
            Kirigami.FormData.label: i18nc("@label", "Border color:")
            spacing: Kirigami.Units.smallSpacing

            Rectangle {
                width: Kirigami.Units.gridUnit * 1.5
                height: Kirigami.Units.gridUnit * 1.5
                radius: Kirigami.Units.smallSpacing
                color: root.cfg_containerBorderColor
                border.color: Kirigami.Theme.separatorColor
                border.width: 1
            }

            QQC2.Button {
                text: i18nc("@action:button", "Choose Color…")
                icon.name: "color-picker"
                onClicked: borderColorDialog.open()
            }

            QtDialogs.ColorDialog {
                id: borderColorDialog
                selectedColor: root.cfg_containerBorderColor
                onAccepted: {
                    root.cfg_containerBorderColor = selectedColor;
                }
            }
        }

        QQC2.CheckBox {
            id: autoAdjustPanelThicknessCheckBox
            Kirigami.FormData.label: i18nc("@label:checkbox", "Panel thickness:")
            text: i18nc("@option:check", "Auto-adjust panel thickness to fit dock")
            checked: Plasmoid.configuration.autoAdjustPanelThickness !== undefined ? Plasmoid.configuration.autoAdjustPanelThickness : true
        }

        // ==========================================
        // 4. PREVIEWS & INDICATORS
        // ==========================================
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18nc("@title:group", "Previews & Indicators")
        }

        QQC2.CheckBox {
            id: showToolTips
            Kirigami.FormData.label: i18nc("@label for preview checkboxes", "Window previews:")
            text: i18nc("@option:check section General", "Show window previews when hovering over tasks")
        }

        QQC2.CheckBox {
            id: highlightWindows
            visible: showToolTips.checked
            text: i18nc("@option:check section General", "Hide other windows when hovering over previews")
        }

        QQC2.CheckBox {
            id: indicateAudioStreams
            Kirigami.FormData.label: i18nc("@label for audio indicator checkboxes", "Audio indicator:")
            text: i18nc("@option:check section General", "Show an indicator when a task is playing audio")
            checked: root.cfg_indicateAudioStreams && root.plasmaPaAvailable
            onToggled: root.cfg_indicateAudioStreams = checked
            enabled: root.plasmaPaAvailable
        }

        QQC2.CheckBox {
            id: interactiveMute
            visible: indicateAudioStreams.checked && root.plasmaPaAvailable
            text: i18nc("@option:check section General", "Mute task when clicking indicator")
            checked: root.cfg_interactiveMute && root.plasmaPaAvailable
            onToggled: root.cfg_interactiveMute = checked
            enabled: indicateAudioStreams.checked && root.plasmaPaAvailable
        }

        QQC2.CheckBox {
            id: tooltipControls
            Kirigami.FormData.label: i18nc("@label for media controls checkbox", "Media controls:")
            text: i18nc("@option:check section General", "Show media and volume controls in tooltip")
            checked: root.cfg_tooltipControls && root.plasmaPaAvailable
            onToggled: root.cfg_tooltipControls = checked
            enabled: root.plasmaPaAvailable
        }

        // Hidden controls to maintain compatibility with Plasmoid configuration bindings
        Item {
            visible: false
            QQC2.ComboBox { id: taskMaxWidth; model: [] }
            QQC2.RadioButton { id: forbidStripes }
            QQC2.RadioButton { id: allowStripes }
            QQC2.RadioButton { id: forceStripes }
            QQC2.SpinBox { id: maxStripes; value: 1 }
        }
    }
}
