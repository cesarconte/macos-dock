/*
    SPDX-FileCopyrightText: 2026 Cesar <yugurta@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.cesar.dock 1.0

PlasmaCore.PopupPlasmaWindow {
    id: stackDialog

    animated: true
    popupDirection: Qt.TopEdge

    property bool contextMenuOpen: false
    property url currentContextUrl: ""
    property string currentContextName: ""

    property Item hoveredDelegate: null
    property string hoveredFileName: ""
    property var hoveredFileSize: 0
    property bool hoveredIsDir: false
    property real hoveredItemX: 0
    property real hoveredItemY: 0
    property real hoveredItemW: 118
    property real hoveredItemH: 114

    function formatFileSize(bytes): string {
        if (!bytes || bytes <= 0) return "";
        if (bytes < 1024) return bytes + " B";
        const kb = bytes / 1024;
        if (kb < 1024) return kb.toFixed(1) + " KB";
        const mb = kb / 1024;
        if (mb < 1024) return mb.toFixed(1) + " MB";
        const gb = mb / 1024;
        return gb.toFixed(2) + " GB";
    }

    onActiveChanged: {
        if (!active && !contextMenuOpen) {
            visible = false;
        }
    }

    onVisibleChanged: {
        if (!visible) {
            hoveredDelegate = null;
        }
    }

    width: 380
    height: Math.max(220, Math.min(520, headerItem.height + gridContainer.implicitHeight + 32))

    mainItem: Item {
        id: mainContainer
        anchors.fill: parent

        // Header
        Item {
            id: headerItem
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 44

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Kirigami.Icon {
                    source: "folder-download"
                    implicitWidth: 20
                    implicitHeight: 20
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: i18n("Descargas")
                    font.bold: true
                    font.pixelSize: 14
                    font.family: "Cantarell, Noto Sans, sans-serif"
                    color: Kirigami.Theme.textColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle {
                id: openDolphinBtn
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: openRow.implicitWidth + 18
                height: 28
                radius: 14
                color: openBtnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.08)

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                Row {
                    id: openRow
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: i18n("Abrir en Dolphin")
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: Kirigami.Theme.textColor
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Kirigami.Icon {
                        source: "document-open-folder"
                        implicitWidth: 14
                        implicitHeight: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: openBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        DockBackend.openDownloads();
                        stackDialog.visible = false;
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Qt.rgba(1, 1, 1, 0.1)
            }
        }

        // Folder Model
        FolderListModel {
            id: folderModel
            folder: "file://" + DockBackend.downloadsPath
            sortField: FolderListModel.Time
            sortReversed: false
            showDirs: true
            showDotAndDotDot: false
            showOnlyReadable: true
        }

        // Empty state
        Item {
            anchors.top: headerItem.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            visible: folderModel.count === 0

            Column {
                anchors.centerIn: parent
                spacing: 8

                Kirigami.Icon {
                    source: "folder-download"
                    implicitWidth: 48
                    implicitHeight: 48
                    anchors.horizontalCenter: parent.horizontalCenter
                    opacity: 0.4
                }

                Text {
                    text: i18n("La carpeta de descargas está vacía")
                    color: Kirigami.Theme.disabledTextColor
                    font.pixelSize: 12
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // Grid of files
        Item {
            id: gridContainer
            anchors.top: headerItem.bottom
            anchors.topMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            visible: folderModel.count > 0
            implicitHeight: Math.min(420, Math.ceil(folderModel.count / 3) * 114)

            GridView {
                id: gridView
                anchors.fill: parent
                anchors.margins: 6
                cellWidth: 118
                cellHeight: 114
                clip: true
                model: folderModel
                boundsBehavior: Flickable.StopAtBounds

                PlasmaComponents3.ScrollBar.vertical: PlasmaComponents3.ScrollBar {
                    parent: gridView.parent
                    anchors.top: gridView.top
                    anchors.bottom: gridView.bottom
                    anchors.right: gridView.right
                }

                delegate: Item {
                    id: fileItem
                    width: gridView.cellWidth
                    height: gridView.cellHeight

                    required property string fileName
                    required property string filePath
                    required property url fileUrl
                    required property bool fileIsDir
                    required property var fileSize

                    readonly property bool isHovered: mouseArea.containsMouse

                    onIsHoveredChanged: {
                        if (isHovered) {
                            const pt = fileItem.mapToItem(mainContainer, 0, 0);
                            stackDialog.hoveredItemX = pt.x;
                            stackDialog.hoveredItemY = pt.y;
                            stackDialog.hoveredItemW = fileItem.width;
                            stackDialog.hoveredItemH = fileItem.height;
                            stackDialog.hoveredFileName = fileItem.fileName;
                            stackDialog.hoveredFileSize = fileItem.fileSize;
                            stackDialog.hoveredIsDir = fileItem.fileIsDir;
                            stackDialog.hoveredDelegate = fileItem;
                        } else if (stackDialog.hoveredDelegate === fileItem) {
                            stackDialog.hoveredDelegate = null;
                        }
                    }

                    function isImageFile(name: string): bool {
                        const lower = (name || "").toLowerCase();
                        return lower.endsWith(".png") || lower.endsWith(".jpg") || lower.endsWith(".jpeg")
                            || lower.endsWith(".svg") || lower.endsWith(".webp") || lower.endsWith(".gif");
                    }

                    // Highlight capsule
                    Rectangle {
                        id: highlightPill
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: 12
                        color: fileItem.isHovered ? Qt.rgba(1, 1, 1, 0.18) : "transparent"
                        border.color: fileItem.isHovered ? Qt.rgba(1, 1, 1, 0.28) : "transparent"
                        border.width: 1

                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }
                        Behavior on border.color {
                            ColorAnimation { duration: 120 }
                        }
                    }

                    Column {
                        id: contentCol
                        anchors.centerIn: parent
                        width: parent.width - 12
                        spacing: 5

                        Item {
                            width: 48
                            height: 48
                            anchors.horizontalCenter: parent.horizontalCenter

                            Kirigami.Icon {
                                id: fileIcon
                                anchors.fill: parent
                                source: fileItem.fileIsDir ? "folder" : (fileItem.isImageFile(fileItem.fileName) ? fileItem.fileUrl : DockBackend.iconForUrl(fileItem.fileUrl, false))
                                fallback: DockBackend.iconForUrl(fileItem.fileUrl, fileItem.fileIsDir)
                                smooth: true

                                scale: fileItem.isHovered ? 1.08 : 1.0
                                transform: Translate {
                                    y: fileItem.isHovered ? -3 : 0
                                    Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
                                }
                                Behavior on scale {
                                    NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
                                }
                            }
                        }

                        Text {
                            text: fileItem.fileName
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: 11
                            font.weight: fileItem.isHovered ? Font.Medium : Font.Normal
                            font.family: "Cantarell, Noto Sans, sans-serif"
                            color: Kirigami.Theme.textColor
                            elide: Text.ElideMiddle
                            maximumLineCount: 2
                            wrapMode: Text.WrapAnywhere
                        }
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        onClicked: mouse => {
                            if (mouse.button === Qt.LeftButton) {
                                DockBackend.openUrl(fileItem.fileUrl);
                                stackDialog.visible = false;
                            } else if (mouse.button === Qt.RightButton) {
                                stackDialog.currentContextUrl = fileItem.fileUrl;
                                stackDialog.currentContextName = fileItem.fileName;
                                fileContextMenu.popup();
                            }
                        }
                    }
                }
            }
        }

        // Shared floating tooltip overlay (drawn at top-level outside GridView clipping)
        Rectangle {
            id: hoverTooltipOverlay
            visible: stackDialog.hoveredDelegate !== null || opacity > 0.0
            opacity: (stackDialog.hoveredDelegate !== null) ? 1.0 : 0.0
            z: 9999

            width: Math.min(270, tooltipCol.implicitWidth + 24)
            height: tooltipCol.implicitHeight + 14
            radius: 10
            color: Qt.rgba(0.12, 0.12, 0.14, 0.94)
            border.color: Qt.rgba(1, 1, 1, 0.22)
            border.width: 1

            Behavior on opacity {
                NumberAnimation { duration: 120 }
            }

            Behavior on x {
                enabled: hoverTooltipOverlay.opacity > 0.5
                NumberAnimation { duration: 110; easing.type: Easing.OutQuad }
            }

            Behavior on y {
                enabled: hoverTooltipOverlay.opacity > 0.5
                NumberAnimation { duration: 110; easing.type: Easing.OutQuad }
            }

            // Strictly clamped horizontally within mainContainer margins [12, mainContainer.width - width - 12]
            x: {
                const idealX = stackDialog.hoveredItemX + (stackDialog.hoveredItemW - width) / 2;
                return Math.max(12, Math.min(mainContainer.width - width - 12, idealX));
            }

            // Smart vertical positioning:
            // If the item's top edge is within 65px of the header (top row), ALWAYS place below the item.
            // Otherwise, place above the item.
            y: {
                const spaceAbove = stackDialog.hoveredItemY - headerItem.height;
                if (spaceAbove < 65) {
                    return Math.min(mainContainer.height - height - 8, stackDialog.hoveredItemY + stackDialog.hoveredItemH + 6);
                } else {
                    return stackDialog.hoveredItemY - height - 6;
                }
            }

            Column {
                id: tooltipCol
                anchors.centerIn: parent
                width: parent.width - 20
                spacing: 2

                Text {
                    text: stackDialog.hoveredFileName
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.family: "Cantarell, Noto Sans, sans-serif"
                    color: "#FFFFFF"
                    elide: Text.ElideMiddle
                    maximumLineCount: 3
                    wrapMode: Text.WrapAnywhere
                }

                Text {
                    visible: !stackDialog.hoveredIsDir && Boolean(stackDialog.hoveredFileSize)
                    text: stackDialog.formatFileSize(stackDialog.hoveredFileSize)
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 10
                    font.family: "Cantarell, Noto Sans, sans-serif"
                    color: Qt.rgba(1, 1, 1, 0.65)
                }
            }
        }

        // Context Menu for Items
        PlasmaComponents3.Menu {
            id: fileContextMenu

            onOpened: stackDialog.contextMenuOpen = true
            onClosed: {
                stackDialog.contextMenuOpen = false;
                if (!stackDialog.active) {
                    stackDialog.visible = false;
                }
            }

            PlasmaComponents3.MenuItem {
                text: i18n("Abrir")
                icon.name: "document-open"
                onTriggered: {
                    DockBackend.openUrl(stackDialog.currentContextUrl);
                    stackDialog.visible = false;
                }
            }

            PlasmaComponents3.MenuItem {
                text: i18n("Mostrar en Dolphin")
                icon.name: "document-open-folder"
                onTriggered: {
                    DockBackend.showInFolder(stackDialog.currentContextUrl);
                    stackDialog.visible = false;
                }
            }

            PlasmaComponents3.MenuSeparator {}

            PlasmaComponents3.MenuItem {
                text: i18n("Copiar")
                icon.name: "edit-copy"
                onTriggered: {
                    DockBackend.copyToClipboard(stackDialog.currentContextUrl);
                }
            }

            PlasmaComponents3.MenuItem {
                text: i18n("Mover a la papelera")
                icon.name: "user-trash"
                onTriggered: {
                    DockBackend.trashUrl(stackDialog.currentContextUrl);
                }
            }
        }
    }
}
