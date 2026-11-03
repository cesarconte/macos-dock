/*
    SPDX-FileCopyrightText: 2026 Cesar <yugurta@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
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

    onActiveChanged: {
        if (!active) {
            visible = false;
        }
    }

    width: 360
    height: Math.min(480, headerItem.height + gridContainer.implicitHeight + 24)

    mainItem: Item {
        id: mainContainer
        anchors.fill: parent

        // Header
        Item {
            id: headerItem
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 40

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 12
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
                    font.family: "SF Pro Display, -apple-system, Cantarell, Noto Sans, sans-serif"
                    color: Kirigami.Theme.textColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle {
                id: openDolphinBtn
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: openRow.implicitWidth + 16
                height: 26
                radius: 13
                color: openBtnHover.hovered ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.08)

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

                HoverHandler {
                    id: openBtnHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: {
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
            implicitHeight: Math.min(380, Math.ceil(folderModel.count / 3) * 105)

            QQC2.ScrollView {
                anchors.fill: parent
                clip: true
                QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

                GridView {
                    id: gridView
                    anchors.fill: parent
                    cellWidth: 110
                    cellHeight: 105
                    model: folderModel

                    delegate: Item {
                        id: fileItem
                        width: gridView.cellWidth
                        height: gridView.cellHeight

                        required property string fileName
                        required property string filePath
                        required property url fileURL
                        required property bool fileIsDir

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: 10
                            color: fileHover.hovered ? Qt.rgba(1, 1, 1, 0.16) : "transparent"
                            border.color: fileHover.hovered ? Qt.rgba(1, 1, 1, 0.25) : "transparent"
                            border.width: 1

                            Behavior on color {
                                ColorAnimation { duration: 120 }
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            width: parent.width - 12
                            spacing: 4

                            Kirigami.Icon {
                                id: fileIcon
                                source: fileItem.fileIsDir ? "folder" : fileItem.fileURL
                                implicitWidth: 44
                                implicitHeight: 44
                                anchors.horizontalCenter: parent.horizontalCenter
                                fallback: fileItem.fileIsDir ? "folder" : "unknown"
                            }

                            Text {
                                text: fileItem.fileName
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                font.pixelSize: 11
                                font.family: "SF Pro Text, -apple-system, Cantarell, Noto Sans, sans-serif"
                                color: Kirigami.Theme.textColor
                                elide: Text.ElideMiddle
                                maximumLineCount: 2
                                wrapMode: Text.WrapAnywhere
                            }
                        }

                        HoverHandler {
                            id: fileHover
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: {
                                DockBackend.openUrl(fileItem.fileURL);
                                stackDialog.visible = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
