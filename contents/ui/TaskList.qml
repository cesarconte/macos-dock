/*
    SPDX-FileCopyrightText: 2012-2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.core as PlasmaCore

GridLayout {
    id: grid
    property bool animating: false

    property int animationsRunning: 0
    onAnimationsRunningChanged: {
        animating = animationsRunning > 0;
    }

    required property int count
    property int iconSpacing: 4

    property bool vertical: false

    rows: vertical ? count : 1
    columns: vertical ? 1 : count

    rowSpacing: vertical ? iconSpacing : 0
    columnSpacing: vertical ? 0 : iconSpacing
}
