/*
    SPDX-FileCopyrightText: 2026 Cesar <yugurta@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3

PlasmaCore.ToolTipArea {
    id: specialItem

    required property int itemIndex
    required property Item tasksRoot
    required property string iconSource
    required property string title
    property bool isTrash: false
    property bool isDownloads: false

    mainText: title
    location: tasksRoot ? tasksRoot.effectiveLocation : PlasmaCore.Types.BottomEdge

    readonly property real targetZoomFactor: tasksRoot ? tasksRoot.magnificationFactorForIndex(itemIndex) : 0.0
    readonly property real effectiveZoom: Math.max(0.0, targetZoomFactor)
    readonly property real currentScale: 1.0 + ((tasksRoot ? tasksRoot.zoomMultiplier : 1.5) - 1.0) * effectiveZoom
    readonly property real currentHoverLift: (tasksRoot ? tasksRoot.hoverElevation : 12) * effectiveZoom
    readonly property real extraSpan: tasksRoot ? (tasksRoot.iconSize * (currentScale - 1.0) + (tasksRoot.iconSpacing * 0.5) * effectiveZoom) : 0.0

    z: Math.round(effectiveZoom * 100)

    implicitWidth: tasksRoot.iconSize
    implicitHeight: tasksRoot.iconSize

    width: implicitWidth + (!tasksRoot.vertical ? extraSpan : 0)
    height: implicitHeight + (tasksRoot.vertical ? extraSpan : 0)

    HoverHandler {
        id: hoverHandler
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        cursorShape: Qt.PointingHandCursor

        onPointChanged: {
            if (!tasksRoot || !hovered) return;
            const ratio = tasksRoot.vertical
                ? (point.position.y / specialItem.height - 0.5)
                : (point.position.x / specialItem.width - 0.5);
            tasksRoot.setHoverPosition(specialItem.itemIndex, ratio);
        }

        onHoveredChanged: {
            if (!tasksRoot) return;
            if (hovered) {
                tasksRoot.setHoverPosition(specialItem.itemIndex, 0.0);
            } else {
                tasksRoot.clearHoveredTask(specialItem.itemIndex);
            }
        }
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: {
            triggerBounce();
            if (specialItem.isTrash && typeof dockBackend !== "undefined") {
                dockBackend.openTrash();
            } else if (specialItem.isDownloads && typeof dockBackend !== "undefined") {
                dockBackend.openDownloads();
            }
        }
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: {
            if (specialItem.isTrash) {
                trashContextMenu.popup();
            }
        }
    }

    DropArea {
        anchors.fill: parent
        onDropped: drop => {
            if (drop.hasUrls && typeof dockBackend !== "undefined") {
                if (specialItem.isTrash) {
                    dockBackend.moveToTrash(drop.urls);
                } else if (specialItem.isDownloads) {
                    dockBackend.copyToDownloads(drop.urls);
                }
                drop.acceptProposedAction();
            }
        }
    }

    Item {
        id: iconBox
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: Math.round(tasksRoot.iconSize * specialItem.currentScale)
        height: Math.round(tasksRoot.iconSize * specialItem.currentScale)

        transform: [
            Translate {
                id: bounceTranslate
                x: 0
                y: 0
            },
            Translate {
                id: hoverTranslate
                x: tasksRoot.vertical ? (tasksRoot.effectiveLocation === PlasmaCore.Types.LeftEdge ? specialItem.currentHoverLift : -specialItem.currentHoverLift) : 0
                y: !tasksRoot.vertical ? (tasksRoot.effectiveLocation === PlasmaCore.Types.TopEdge ? specialItem.currentHoverLift : -specialItem.currentHoverLift) : 0
            }
        ]

        Kirigami.Icon {
            id: icon
            anchors.fill: parent
            source: specialItem.iconSource
            active: hoverHandler.hovered
            smooth: true
        }
    }

    // Bounce animation on click
    property bool bouncing: false
    SequentialAnimation {
        id: bounceAnim
        running: specialItem.bouncing
        onFinished: specialItem.bouncing = false

        NumberAnimation {
            target: bounceTranslate
            property: "y"
            to: -Math.min(10, Math.max(6, Math.round(tasksRoot.iconSize * 0.18)))
            duration: 180
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: bounceTranslate
            property: "y"
            to: 0
            duration: 160
            easing.type: Easing.InQuad
        }
        NumberAnimation {
            target: bounceTranslate
            property: "y"
            to: -Math.round(tasksRoot.iconSize * 0.08)
            duration: 120
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: bounceTranslate
            property: "y"
            to: 0
            duration: 120
            easing.type: Easing.InQuad
        }
    }

    function triggerBounce(): void {
        bouncing = true;
    }

    PlasmaComponents3.Menu {
        id: trashContextMenu

        PlasmaComponents3.MenuItem {
            text: i18n("Abrir papelera")
            icon.name: "document-open"
            onTriggered: {
                if (typeof dockBackend !== "undefined") {
                    dockBackend.openTrash();
                }
            }
        }

        PlasmaComponents3.MenuItem {
            text: i18n("Vaciar papelera")
            icon.name: "trash-empty"
            enabled: typeof dockBackend !== "undefined" && dockBackend.isTrashFull
            onTriggered: {
                if (typeof dockBackend !== "undefined") {
                    dockBackend.emptyTrash();
                }
            }
        }
    }
}
