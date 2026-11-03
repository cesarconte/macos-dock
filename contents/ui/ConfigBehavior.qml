/*
    SPDX-FileCopyrightText: 2013 Eike Hein <hein@kde.org>
    SPDX-FileCopyrightText: 2024 Matt Anis

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

import org.kde.plasma.workspace.dbus as DBus
import org.kde.taskmanager as TaskManager

KCMUtils.SimpleKCM {
    id: root

    readonly property bool iconOnly: true

    property alias cfg_groupingStrategy: groupingStrategy.currentIndex
    property alias cfg_groupedTaskVisualization: groupedTaskVisualization.currentIndex
    property alias cfg_groupPopups: groupPopups.checked
    property alias cfg_onlyGroupWhenFull: onlyGroupWhenFull.checked
    property int cfg_sortingStrategy
    property alias cfg_separateLaunchers: separateLaunchers.checked
    property alias cfg_hideLauncherOnStart: hideLauncherOnStart.checked
    property alias cfg_middleClickAction: middleClickAction.currentIndex
    property alias cfg_wheelEnabled: wheelEnabled.currentIndex
    property alias cfg_wheelSkipMinimized: wheelSkipMinimized.checked
    property alias cfg_showOnlyCurrentScreen: showOnlyCurrentScreen.checked
    property alias cfg_showOnlyCurrentDesktop: showOnlyCurrentDesktop.checked
    property alias cfg_showOnlyCurrentActivity: showOnlyCurrentActivity.checked
    property alias cfg_showOnlyMinimized: showOnlyMinimized.checked
    property alias cfg_minimizeActiveTaskOnClick: minimizeActive.checked
    property alias cfg_unhideOnAttention: unhideOnAttention.checked
    property alias cfg_reverseMode: reverseMode.checked

    headerPaddingEnabled: false
    header: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        Kirigami.InlineMessage {
            id: annoyingAppWorkaroundMessage

            Layout.fillWidth: true
            position: Kirigami.InlineMessage.Position.Header

            text: i18nc("@info", "If you're using this setting to work around an application that demands attention too often, first look for a setting in the app to disable that behavior. If you don't find one, consider reporting this as a bug to the app's developer.")
        }
    }

    DBus.DBusServiceWatcher {
        id: effectWatcher
        busType: DBus.BusType.Session
        watchedService: "org.kde.KWin.Effect.WindowView1"
    }

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        // ==========================================
        // 1. GROUPING & SORTING
        // ==========================================
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18nc("@title:group", "Grouping & Sorting")
        }

        QQC2.ComboBox {
            id: groupingStrategy
            Kirigami.FormData.label: i18nc("@label:listbox how to group tasks", "Group:")
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 14
            model: [
                i18nc("@item:inlistbox how to group tasks", "Do not group"),
                i18nc("@item:inlistbox how to group tasks", "By program name")
            ]
        }

        QQC2.ComboBox {
            id: groupedTaskVisualization
            Kirigami.FormData.label: i18nc("@label:listbox completes sentence like: … cycles through tasks", "Clicking grouped task:")
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 14

            enabled: groupingStrategy.currentIndex !== 0

            model: [
                i18nc("@item:inlistbox Completes the sentence 'Clicking grouped task cycles through tasks' ", "Cycles through tasks"),
                i18nc("@item:inlistbox Completes the sentence 'Clicking grouped task shows small window previews' ", "Shows small window previews"),
                i18nc("@item:inlistbox Completes the sentence 'Clicking grouped task shows large window previews' ", "Shows large window previews"),
                i18nc("@item:inlistbox Completes the sentence 'Clicking grouped task shows textual list' ", "Shows textual list"),
            ]

            Accessible.name: currentText
            Accessible.onPressAction: currentIndex = currentIndex === count - 1 ? 0 : (currentIndex + 1)
        }

        // "You asked for Window View but Window View is not available" message
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: groupedTaskVisualization.currentIndex === 2 && !effectWatcher.registered
            type: Kirigami.MessageType.Warning
            text: i18nc("@info displayed as InlineMessage", "The compositor does not support displaying windows side by side, so a textual list will be displayed instead.")
        }

        QQC2.ComboBox {
            id: sortingStrategy
            Kirigami.FormData.label: i18nc("@label:listbox sort tasks in grouped task", "Sort order:")
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 14
            textRole: "text"
            valueRole: "value"
            model: [
                {
                    "text": i18nc("@item:inlistbox sort tasks in grouped task", "Do not sort"),
                    "value": TaskManager.TasksModel.SortDisabled,
                },
                {
                    "text": i18nc("@item:inlistbox sort tasks in grouped task", "Manually"),
                    "value": TaskManager.TasksModel.SortManual,
                },
                {
                    "text": i18nc("@item:inlistbox sort tasks in grouped task", "Alphabetically"),
                    "value": TaskManager.TasksModel.SortAlpha,
                },
                {
                    "text": i18nc("@item:inlistbox sort tasks in grouped task", "By desktop"),
                    "value": TaskManager.TasksModel.SortVirtualDesktop,
                },
                {
                    "text": i18nc("@item:inlistbox sort tasks in grouped task", "By activity"),
                    "value": TaskManager.TasksModel.SortActivity,
                },
                {
                    "text": i18nc("@item:inlistbox sort tasks in grouped task", "By horizontal window position"),
                    "value": TaskManager.TasksModel.SortWindowPositionHorizontal,
                },
            ]
            onActivated: root.cfg_sortingStrategy = currentValue
            Component.onCompleted: currentIndex = indexOfValue(root.cfg_sortingStrategy)
        }

        // ==========================================
        // 2. MOUSE ACTIONS
        // ==========================================
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18nc("@title:group", "Mouse Actions")
        }

        QQC2.CheckBox {
            id: minimizeActive
            Kirigami.FormData.label: i18nc("@label for checkbox Part of a sentence: 'Clicking active task minimizes the task'", "Clicking active task:")
            text: i18nc("@option:check Part of a sentence: 'Clicking active task minimizes the task'", "Minimizes the task")
        }

        QQC2.ComboBox {
            id: middleClickAction
            Kirigami.FormData.label: i18nc("@label:listbox completes sentence like: … does nothing", "Middle-click:")
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 14
            model: [
                i18nc("@item:inlistbox Part of a sentence: 'Middle-clicking any task does nothing'", "Does nothing"),
                i18nc("@item:inlistbox Part of a sentence: 'Middle-clicking any task closes window or group'", "Closes window or group"),
                i18nc("@item:inlistbox Part of a sentence: 'Middle-clicking any task opens a new window'", "Opens a new window"),
                i18nc("@item:inlistbox Part of a sentence: 'Middle-clicking any task minimizes/restores window or group'", "Minimizes/Restores window or group"),
                i18nc("@item:inlistbox Part of a sentence: 'Middle-clicking any task toggles grouping'", "Toggles grouping"),
                i18nc("@item:inlistbox Part of a sentence: 'Middle-clicking any task brings it to the current virtual desktop'", "Brings it to the current virtual desktop")
            ]
        }

        QQC2.ComboBox {
            id: wheelEnabled
            Kirigami.FormData.label: i18nc("@label:listbox", "Mouse wheel scroll:")
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 14
            model: [
                i18nc("@item:inlistbox Part of a sentence: 'Scrolling behavior does nothing'", "Does nothing"),
                i18nc("@item:inlistbox Part of a sentence: 'Scrolling behavior cycles through all tasks'", "Cycles through all tasks"),
                i18nc("@item:inlistbox Part of a sentence: 'Scrolling behavior cycles through the hovered task's windows'", "Cycles through the hovered task’s windows"),
                i18nc("@item:inlistbox Part of a sentence: 'Scrolling behavior adjusts the hovered task’s volume'", "Adjusts the hovered task’s volume"),
            ]
        }

        QQC2.CheckBox {
            id: wheelSkipMinimized
            visible: wheelEnabled.currentIndex !== 0
            text: i18nc("@option:check mouse wheel task cycling", "Skip minimized tasks when scrolling")
            enabled: wheelEnabled.currentIndex !== 0
        }

        // ==========================================
        // 3. FILTERS & VISIBILITY
        // ==========================================
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18nc("@title:group", "Filters & Visibility")
        }

        QQC2.CheckBox {
            id: showOnlyCurrentScreen
            Kirigami.FormData.label: i18nc("@label for checkbox group", "Show only tasks:")
            text: i18nc("@option:check completes sentence: show only tasks", "From the current screen")
        }

        QQC2.CheckBox {
            id: showOnlyCurrentDesktop
            text: i18nc("@option:check completes sentence: show only tasks", "From the current desktop")
        }

        QQC2.CheckBox {
            id: showOnlyCurrentActivity
            text: i18nc("@option:check completes sentence: show only tasks", "From the current activity")
        }

        QQC2.CheckBox {
            id: showOnlyMinimized
            text: i18nc("@option:check completes sentence: show only tasks", "That are minimized")
        }

        // ==========================================
        // 4. PANEL & LAYOUT DIRECTION
        // ==========================================
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18nc("@title:group", "Panel & Layout Direction")
        }

        QQC2.CheckBox {
            id: unhideOnAttention
            Kirigami.FormData.label: i18nc("@label for checkbox", "Attention:")
            text: i18nc("@option:check completes sentence: When panel is hidden", "Unhide panel when a window requests attention")
            onToggled: {
                annoyingAppWorkaroundMessage.visible = !unhideOnAttention.checked;
            }
        }

        QQC2.ButtonGroup {
            id: reverseModeRadioButtonGroup
        }

        QQC2.RadioButton {
            Kirigami.FormData.label: i18nc("@label for radiobutton group", "Task layout order:")
            checked: !reverseMode.checked
            text: {
                if (Plasmoid.formFactor === PlasmaCore.Types.Vertical) {
                    return i18nc("@option:check completes sentence: New tasks appear", "Top to bottom");
                }
                if (Application.layoutDirection === Qt.LeftToRight) {
                    return i18nc("@option:check completes sentence: New tasks appear", "Left to right");
                } else {
                    return i18nc("@option:check completes sentence: New tasks appear", "Right to left");
                }
            }
            QQC2.ButtonGroup.group: reverseModeRadioButtonGroup
        }

        QQC2.RadioButton {
            id: reverseMode
            checked: Plasmoid.configuration.reverseMode === true
            text: {
                if (Plasmoid.formFactor === PlasmaCore.Types.Vertical) {
                    return i18nc("@option:check completes sentence: New tasks appear", "Bottom to top");
                }
                if (Application.layoutDirection === Qt.LeftToRight) {
                    return i18nc("@option:check completes sentence: New tasks appear", "Right to left");
                } else {
                    return i18nc("@option:check completes sentence: New tasks appear", "Left to right");
                }
            }
            QQC2.ButtonGroup.group: reverseModeRadioButtonGroup
        }

        // Hidden controls to maintain compatibility with Plasmoid configuration bindings
        Item {
            visible: false
            QQC2.CheckBox { id: groupPopups; enabled: false }
            QQC2.CheckBox { id: onlyGroupWhenFull; enabled: false }
            QQC2.CheckBox { id: separateLaunchers; enabled: false }
            QQC2.CheckBox { id: hideLauncherOnStart; enabled: false }
        }
    }
}
