/*
    SPDX-FileCopyrightText: 2012-2016 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.ksvg as KSvg
import org.kde.plasma.private.mpris as Mpris
import org.kde.kirigami as Kirigami

import org.kde.plasma.workspace.trianglemousefilter

import org.kde.taskmanager as TaskManager
import "code/LayoutMetrics.js" as LayoutMetrics
import "code/TaskTools.js" as TaskTools
import org.kde.plasma.workspace.dbus as DBus

PlasmoidItem {
    id: tasks

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    readonly property bool vertical: {
        if (Plasmoid.location === PlasmaCore.Types.LeftEdge || Plasmoid.location === PlasmaCore.Types.RightEdge) {
            return true;
        }
        if (Plasmoid.location === PlasmaCore.Types.TopEdge || Plasmoid.location === PlasmaCore.Types.BottomEdge) {
            return false;
        }
        if (Plasmoid.formFactor === PlasmaCore.Types.Vertical) {
            return true;
        }
        if (Plasmoid.formFactor === PlasmaCore.Types.Horizontal) {
            return false;
        }
        if (parent && parent.height > 0 && parent.width > 0) {
            return parent.height > parent.width;
        }
        return false;
    }

    readonly property int effectiveLocation: {
        if (isStandaloneView) {
            return PlasmaCore.Types.BottomEdge;
        }
        if (Plasmoid.location === PlasmaCore.Types.LeftEdge || Plasmoid.location === PlasmaCore.Types.RightEdge
            || Plasmoid.location === PlasmaCore.Types.TopEdge || Plasmoid.location === PlasmaCore.Types.BottomEdge) {
            return Plasmoid.location;
        }
        if (vertical) {
            if (tasks.window && tasks.window.screen) {
                const panelCenterX = tasks.window.x + tasks.window.width / 2;
                const screenCenterX = (tasks.window.screen.virtualX || 0) + tasks.window.screen.width / 2;
                return panelCenterX < screenCenterX ? PlasmaCore.Types.LeftEdge : PlasmaCore.Types.RightEdge;
            }
            return PlasmaCore.Types.LeftEdge;
        }
        if (tasks.window && tasks.window.screen) {
            const panelCenterY = tasks.window.y + tasks.window.height / 2;
            const screenCenterY = (tasks.window.screen.virtualY || 0) + tasks.window.screen.height / 2;
            return panelCenterY < screenCenterY ? PlasmaCore.Types.TopEdge : PlasmaCore.Types.BottomEdge;
        }
        return PlasmaCore.Types.BottomEdge;
    }

    // For making a bottom to top layout since qml flow can't do that.
    // We just hang the task manager upside down to achieve that.
    // This mirrors the tasks and group dialog as well, so we un-rotate them
    // to fix that (see Task.qml and GroupDialog.qml).
    rotation: Plasmoid.configuration.reverseMode && vertical ? 180 : 0

    readonly property bool shouldShrinkToZero: tasksModel.count === 0
    readonly property bool iconsOnly: true

    property Task toolTipOpenedByClick
    property Task toolTipAreaItem

    readonly property Component contextMenuComponent: Qt.createComponent("ContextMenu.qml")
    readonly property Component pulseAudioComponent: Qt.createComponent("PulseAudio.qml")

    property alias taskList: taskList

    property bool isStandaloneView: false

    readonly property real dockCapsuleWidth: tmf ? tmf.width : tasks.width
    readonly property real dockCapsuleX: tmf ? tmf.x : 0
    readonly property real dockCapsuleHeight: tmf ? tmf.height : tasks.height
    readonly property real dockCapsuleY: tmf ? tmf.y : 0

    preferredRepresentation: fullRepresentation

    readonly property int preferredIconSize: Plasmoid.configuration.iconSize || 48
    readonly property int configuredIconSpacing: (Plasmoid.configuration.iconSpacing !== undefined && Plasmoid.configuration.iconSpacing >= 0)
        ? Plasmoid.configuration.iconSpacing
        : 4
    readonly property int horizontalPadding: Math.max(10, (Plasmoid.configuration.horizontalPadding !== undefined ? Plasmoid.configuration.horizontalPadding : 10))
    readonly property int verticalPadding: Math.max(6, (Plasmoid.configuration.verticalPadding !== undefined ? Plasmoid.configuration.verticalPadding : 6))
    readonly property int elevation: Plasmoid.configuration.elevation !== undefined
        ? Plasmoid.configuration.elevation
        : 8
    readonly property bool autoAdjustPanelThickness: Plasmoid.configuration.autoAdjustPanelThickness !== undefined
        ? Plasmoid.configuration.autoAdjustPanelThickness
        : true
    readonly property int containerBackgroundType: Plasmoid.configuration.containerBackgroundType !== undefined
        ? Plasmoid.configuration.containerBackgroundType
        : 0
    readonly property color containerBackgroundColor: Plasmoid.configuration.containerBackgroundColor || "#202024"
    readonly property int containerBorderWidth: Plasmoid.configuration.containerBorderWidth !== undefined
        ? Plasmoid.configuration.containerBorderWidth
        : 1
    readonly property color containerBorderColor: Plasmoid.configuration.containerBorderColor || "#38ffffff"
    readonly property real blurOpacity: (Plasmoid.configuration.blurOpacity !== undefined && Plasmoid.configuration.blurOpacity > 0)
        ? Plasmoid.configuration.blurOpacity
        : 0.35
    readonly property real blurSaturation: (Plasmoid.configuration.blurSaturation !== undefined)
        ? Plasmoid.configuration.blurSaturation
        : 1.3
    readonly property real blurContrast: (Plasmoid.configuration.blurContrast !== undefined)
        ? Plasmoid.configuration.blurContrast
        : 1.0
    readonly property real blurBrightness: (Plasmoid.configuration.blurBrightness !== undefined)
        ? Plasmoid.configuration.blurBrightness
        : 1.0
    readonly property bool zoomEnabled: Plasmoid.configuration.zoomEnabled !== undefined
        ? Plasmoid.configuration.zoomEnabled
        : true
    readonly property real configuredZoomMultiplier: Plasmoid.configuration.zoomMultiplier !== undefined
        ? Plasmoid.configuration.zoomMultiplier
        : 1.5
    readonly property int zoomBlastRadius: Plasmoid.configuration.zoomBlastRadius !== undefined
        ? Plasmoid.configuration.zoomBlastRadius
        : 2
    readonly property int hoverElevation: Plasmoid.configuration.hoverElevation !== undefined
        ? Plasmoid.configuration.hoverElevation
        : 12
    readonly property int zoomAnimationType: Plasmoid.configuration.zoomAnimationType !== undefined
        ? Plasmoid.configuration.zoomAnimationType
        : 0

    property int hoveredTaskIndex: -1
    property real continuousHoverPosition: -1.0
    property real dockHoverProgress: 0.0

    SpringAnimation {
        id: dockSpringAnim
        target: tasks
        property: "dockHoverProgress"
        spring: 7.5
        damping: 0.55
        epsilon: 0.002
    }

    NumberAnimation {
        id: dockSmoothAnim
        target: tasks
        property: "dockHoverProgress"
        duration: 260
        easing.type: Easing.OutCubic
    }

    Behavior on dockHoverProgress {
        animation: tasks.zoomAnimationType === 1 ? dockSmoothAnim : dockSpringAnim
    }

    onDockHoverProgressChanged: {
        if (dockHoverProgress <= 0.0) {
            continuousHoverPosition = -1.0;
            hoveredTaskIndex = -1;
        }
    }

    function magnificationFactorForIndex(index: int): real {
        if (!zoomEnabled || dockHoverProgress <= 0.0 || continuousHoverPosition < -0.5) {
            return 0.0;
        }
        const dist = Math.abs(index - continuousHoverPosition);
        const maxReach = zoomBlastRadius + 0.5;
        if (dist >= maxReach) {
            return 0.0;
        }
        const u = dist / maxReach;
        const linearFalloff = 1.0 - u;
        const smoothTail = 0.5 * (1.0 + Math.cos(Math.PI * u));
        const waveFactor = (0.6 * linearFalloff + 0.4 * smoothTail) * linearFalloff;
        return dockHoverProgress * waveFactor;
    }

    Timer {
        id: resetHoverTimer
        interval: 140
        onTriggered: {
            tasks.dockHoverProgress = 0.0;
        }
    }

    function setHoverPosition(index: int, offsetRatio: real): void {
        resetHoverTimer.stop();
        tasks.dockHoverProgress = 1.0;
        hoveredTaskIndex = index;
        const clampedOffset = Math.max(-0.5, Math.min(0.5, offsetRatio));
        continuousHoverPosition = index + clampedOffset;
    }

    function setHoveredTask(index: int): void {
        setHoverPosition(index, 0.0);
    }

    function clearHoveredTask(index: int): void {
        if (hoveredTaskIndex === index) {
            resetHoverTimer.restart();
        }
    }

    readonly property int targetThickness: vertical
        ? (iconSize + horizontalPadding * 2 + elevation)
        : (iconSize + verticalPadding * 2 + elevation)

    readonly property int dividerSpan: 16

    readonly property int firstUnpinnedIndex: {
        for (let i = 0; i < taskRepeater.count; ++i) {
            const item = taskRepeater.itemAt(i) as Task;
            if (item && item.model && !item.isPinned) {
                return i;
            }
        }
        return -1;
    }

    readonly property bool hasDivider: firstUnpinnedIndex > 0

    readonly property real screenAvailableLength: {
        let fullLength = 0;
        if (tasks.window && tasks.window.screen) {
            fullLength = vertical ? tasks.window.screen.height : tasks.window.screen.width;
        } else if (Plasmoid.containment && Plasmoid.containment.screenGeometry) {
            fullLength = vertical ? Plasmoid.containment.screenGeometry.height : Plasmoid.containment.screenGeometry.width;
        }
        if (fullLength <= 0) {
            fullLength = vertical ? (parent ? parent.height : 1080) : (parent ? parent.width : 1920);
        }
        // Reserve a 48px safety margin so the dock never touches the screen corners
        return Math.max(300, fullLength - 48);
    }

    readonly property real zoomFactorSum: {
        let sum = 1.0;
        const maxReach = zoomBlastRadius + 0.5;
        for (let d = 1; d <= zoomBlastRadius; ++d) {
            const u = d / maxReach;
            const linearFalloff = 1.0 - u;
            const smoothTail = 0.5 * (1.0 + Math.cos(Math.PI * u));
            sum += 2.0 * ((0.6 * linearFalloff + 0.4 * smoothTail) * linearFalloff);
        }
        return sum;
    }

    readonly property real configuredZoomSpanFactor: zoomEnabled
        ? ((configuredZoomMultiplier - 1.0) * 1.0 * zoomFactorSum)
        : 0.0

    readonly property real fixedOverhead: {
        const pad = vertical ? (verticalPadding * 2) : (horizontalPadding * 2);
        const div = hasDivider ? dividerSpan : 0;
        const sp = tasksCount > 0 ? (Math.max(0, tasksCount - 1) * configuredIconSpacing) : 0;
        const extraConst = zoomEnabled ? 24 : 0;
        return pad + div + sp + extraConst;
    }

    readonly property int effectiveIconSize: {
        if (tasksCount <= 0) {
            return preferredIconSize;
        }
        const availableForIcons = screenAvailableLength - fixedOverhead;
        const divisor = tasksCount + (zoomEnabled ? configuredZoomSpanFactor : 0);
        if (divisor <= 0) {
            return preferredIconSize;
        }
        const maxFittingSize = Math.floor(availableForIcons / divisor);
        return Math.max(16, Math.min(preferredIconSize, maxFittingSize));
    }

    readonly property int iconSize: effectiveIconSize

    readonly property real zoomMultiplier: {
        if (!zoomEnabled) {
            return 1.0;
        }
        if (iconSize >= preferredIconSize || preferredIconSize <= 16) {
            return configuredZoomMultiplier;
        }
        const shrinkRatio = preferredIconSize / Math.max(1, iconSize);
        return configuredZoomMultiplier * Math.pow(shrinkRatio, 0.75);
    }

    readonly property real zoomSpanFactor: zoomEnabled
        ? ((zoomMultiplier - 1.0) * 1.0 * zoomFactorSum)
        : 0.0

    readonly property int effectiveIconSpacing: (iconSize < 28)
        ? Math.max(1, Math.min(configuredIconSpacing, Math.round(iconSize / 8)))
        : configuredIconSpacing

    readonly property int iconSpacing: effectiveIconSpacing

    readonly property int tasksCount: tasksModel.count
    readonly property real tasksLength: tasksCount > 0
        ? (tasksCount * iconSize + Math.max(0, tasksCount - 1) * effectiveIconSpacing + (hasDivider ? dividerSpan : 0))
        : 0

    readonly property real maxExtraSpan: {
        if (!zoomEnabled) {
            return 0;
        }
        return Math.ceil(iconSize * zoomSpanFactor) + 24;
    }

    readonly property real dockWidth: {
        if (shouldShrinkToZero) {
            return Kirigami.Units.gridUnit;
        }
        return vertical ? targetThickness : Math.min(screenAvailableLength, tasksLength + horizontalPadding * 2 + maxExtraSpan);
    }
    readonly property real dockHeight: {
        if (shouldShrinkToZero) {
            return Kirigami.Units.gridUnit;
        }
        return vertical ? Math.min(screenAvailableLength, tasksLength + verticalPadding * 2 + maxExtraSpan) : targetThickness;
    }

    width: isStandaloneView ? (parent ? parent.width : dockWidth) : ((vertical && parent) ? parent.width : dockWidth)
    height: isStandaloneView ? (parent ? parent.height : dockHeight) : ((!vertical && parent) ? parent.height : dockHeight)
    implicitWidth: dockWidth
    implicitHeight: dockHeight

    Layout.fillWidth: vertical
    Layout.fillHeight: !vertical

    Layout.alignment: {
        if (!vertical) {
            return effectiveLocation === PlasmaCore.Types.TopEdge ? Qt.AlignTop : Qt.AlignBottom;
        } else {
            return effectiveLocation === PlasmaCore.Types.LeftEdge ? Qt.AlignLeft : Qt.AlignRight;
        }
    }

    Layout.minimumWidth: vertical ? -1 : dockWidth
    Layout.maximumWidth: vertical ? -1 : dockWidth
    Layout.preferredWidth: dockWidth
    Layout.minimumHeight: vertical ? dockHeight : -1
    Layout.maximumHeight: vertical ? dockHeight : -1
    Layout.preferredHeight: dockHeight

    // Walk up visual parent hierarchy to disable the native panel background
    readonly property var containmentItem: {
        let candidate = tasks.parent;
        while (candidate) {
            if (candidate.toString().indexOf("ContainmentItem_QML") > -1) {
                return candidate;
            }
            candidate = candidate.parent;
        }
        return null;
    }

    readonly property real panelBottomInset: {
        if (!containmentItem) {
            return 0;
        }
        try {
            const p = containmentItem.mapFromItem(tasks, 0, tasks.height);
            return Math.max(0, containmentItem.height - p.y);
        } catch (e) {
            return 0;
        }
    }

    readonly property real panelTopInset: {
        if (!containmentItem) {
            return 0;
        }
        try {
            const p = containmentItem.mapFromItem(tasks, 0, 0);
            return Math.max(0, p.y);
        } catch (e) {
            return 0;
        }
    }

    readonly property real panelLeftInset: {
        if (!containmentItem) {
            return 0;
        }
        try {
            const p = containmentItem.mapFromItem(tasks, 0, 0);
            return Math.max(0, p.x);
        } catch (e) {
            return 0;
        }
    }

    readonly property real panelRightInset: {
        if (!containmentItem) {
            return 0;
        }
        try {
            const p = containmentItem.mapFromItem(tasks, tasks.width, 0);
            return Math.max(0, containmentItem.width - p.x);
        } catch (e) {
            return 0;
        }
    }

    function applyPanelTransparency() {
        if (containerBackgroundType !== 1 && containmentItem && containmentItem.Plasmoid) {
            try {
                containmentItem.Plasmoid.backgroundHints = PlasmaCore.Types.NoBackground;
            } catch (e) {
                // Safeguard against containment manipulation errors
            }
        }
    }

    onContainmentItemChanged: applyPanelTransparency()

    Plasmoid.onUserConfiguringChanged: {
        if (Plasmoid.userConfiguring && groupDialog !== null) {
            groupDialog.visible = false;
        }
    }

    property Item dragSource

    signal requestLayout

    onDragSourceChanged: {
        if (dragSource === null) {
            tasksModel.syncLaunchers();
        }
    }

    function windowsHovered(winIds: var, hovered: bool): DBus.DBusPendingReply {
        if (!Plasmoid.configuration.highlightWindows) {
            return;
        }
        return DBus.SessionBus.asyncCall({service: "org.kde.KWin.HighlightWindow", path: "/org/kde/KWin/HighlightWindow", iface: "org.kde.KWin.HighlightWindow", member: "highlightWindows", arguments: [hovered ? winIds : []], signature: "(as)"});
    }

    function cancelHighlightWindows(): DBus.DBusPendingReply {
        return DBus.SessionBus.asyncCall({service: "org.kde.KWin.HighlightWindow", path: "/org/kde/KWin/HighlightWindow", iface: "org.kde.KWin.HighlightWindow", member: "highlightWindows", arguments: [[]], signature: "(as)"});
    }

    function activateWindowView(winIds: var): DBus.DBusPendingReply {
        if (!effectWatcher.registered) {
            return;
        }
        cancelHighlightWindows();
        return DBus.SessionBus.asyncCall({service: "org.kde.KWin.Effect.WindowView1", path: "/org/kde/KWin/Effect/WindowView1", iface: "org.kde.KWin.Effect.WindowView1", member: "activate", arguments: [winIds.map(s => String(s))], signature: "(as)"});
    }

    function publishIconGeometries(taskItems: /*list<Item>*/var): void {
        if (TaskTools.taskManagerInstanceCount >= 2) {
            return;
        }
        for (let i = 0; i < taskItems.length - 1; ++i) {
            const task = taskItems[i];

            if (!task.model.IsLauncher && !task.model.IsStartup) {
                tasksModel.requestPublishDelegateGeometry(tasksModel.makeModelIndex(task.index),
                    backend.globalRect(task), task);
            }
        }
    }

    readonly property TaskManager.TasksModel tasksModel: TaskManager.TasksModel {
        id: tasksModel

        readonly property int logicalLauncherCount: {
            if (Plasmoid.configuration.separateLaunchers) {
                return launcherCount;
            }

            let startupsWithLaunchers = 0;

            for (let i = 0; i < taskRepeater.count; ++i) {
                const item = taskRepeater.itemAt(i) as Task;

                // During destruction required properties such as item.model can go null for a while,
                // so in paths that can trigger on those moments, they need to be guarded
                if (item?.model?.IsStartup && item.model.HasLauncher) {
                    ++startupsWithLaunchers;
                }
            }

            return launcherCount + startupsWithLaunchers;
        }

        virtualDesktop: virtualDesktopInfo.currentDesktop
        screenGeometry: Plasmoid.containment.screenGeometry
        activity: activityInfo.currentActivity

        filterByVirtualDesktop: Plasmoid.configuration.showOnlyCurrentDesktop
        filterByScreen: Plasmoid.configuration.showOnlyCurrentScreen
        filterByActivity: Plasmoid.configuration.showOnlyCurrentActivity
        filterNotMinimized: Plasmoid.configuration.showOnlyMinimized

        hideActivatedLaunchers: tasks.iconsOnly || Plasmoid.configuration.hideLauncherOnStart
        sortMode: sortModeEnumValue(Plasmoid.configuration.sortingStrategy)
        launchInPlace: tasks.iconsOnly && Plasmoid.configuration.sortingStrategy === 1
        separateLaunchers: {
            if (!tasks.iconsOnly && !Plasmoid.configuration.separateLaunchers
                && Plasmoid.configuration.sortingStrategy === 1) {
                return false;
            }

            return true;
        }

        groupMode: groupModeEnumValue(Plasmoid.configuration.groupingStrategy)
        groupInline: !Plasmoid.configuration.groupPopups && !tasks.iconsOnly
        groupingWindowTasksThreshold: (Plasmoid.configuration.onlyGroupWhenFull && !tasks.iconsOnly
            ? LayoutMetrics.optimumCapacity(tasks.width, tasks.height) + 1 : -1)

        onLauncherListChanged: {
            Plasmoid.configuration.launchers = launcherList;
        }

        onGroupingAppIdBlacklistChanged: {
            Plasmoid.configuration.groupingAppIdBlacklist = groupingAppIdBlacklist;
        }

        onGroupingLauncherUrlBlacklistChanged: {
            Plasmoid.configuration.groupingLauncherUrlBlacklist = groupingLauncherUrlBlacklist;
        }

        function sortModeEnumValue(index: int): /*TaskManager.TasksModel.SortMode*/ int {
            switch (index) {
            case 0:
                return TaskManager.TasksModel.SortDisabled;
            case 1:
                return TaskManager.TasksModel.SortManual;
            case 2:
                return TaskManager.TasksModel.SortAlpha;
            case 3:
                return TaskManager.TasksModel.SortVirtualDesktop;
            case 4:
                return TaskManager.TasksModel.SortActivity;
            // 5 is SortLastActivated, skipped
            case 6:
                return TaskManager.TasksModel.SortWindowPositionHorizontal;
            default:
                return TaskManager.TasksModel.SortDisabled;
            }
        }

        function groupModeEnumValue(index: int): /*TaskManager.TasksModel.GroupMode*/ int {
            switch (index) {
            case 0:
                return TaskManager.TasksModel.GroupDisabled;
            case 1:
                return TaskManager.TasksModel.GroupApplications;
            }
        }

        Component.onCompleted: {
            launcherList = Plasmoid.configuration.launchers;
            groupingAppIdBlacklist = Plasmoid.configuration.groupingAppIdBlacklist;
            groupingLauncherUrlBlacklist = Plasmoid.configuration.groupingLauncherUrlBlacklist;

            // Only hook up view only after the above churn is done.
            taskRepeater.model = tasksModel;
        }
    }

    readonly property QtObject backend: QtObject {
        id: backend

        signal addLauncher(url url)

        readonly property int none: 0
        readonly property int close: 1
        readonly property int newInstance: 2
        readonly property int toggleMinimized: 3
        readonly property int toggleGrouping: 4
        readonly property int bringToCurrentDesktop: 5

        function globalRect(item) {
            if (!item || !item.window) {
                return Qt.rect(0, 0, 0, 0);
            }
            const pt = item.mapToItem(null, 0, 0);
            return Qt.rect(pt.x, pt.y, item.width, item.height);
        }

        function isApplication(url) {
            return String(url).endsWith(".desktop");
        }

        function tryDecodeApplicationsUrl(url) {
            return url;
        }

        function parentPid(pid) {
            return 0;
        }

        function jumpListActions(launcherUrl, parent) {
            return [];
        }

        function placesActions(launcherUrl, showAllPlaces, parent) {
            return [];
        }

        function recentDocumentActions(launcherUrl, parent) {
            return [];
        }

        function setActionGroup(action) {}

        onAddLauncher: url => {
            tasks.addLauncher(url);
        }
    }

    DBus.DBusServiceWatcher {
        id: effectWatcher
        busType: DBus.BusType.Session
        watchedService: "org.kde.KWin.Effect.WindowView1"
    }

    readonly property Component taskInitComponent: Component {
        Timer {
            interval: 200
            running: true

            onTriggered: {
                const task = parent as Task;
                if (task) {
                    tasks.tasksModel.requestPublishDelegateGeometry(task.modelIndex(), tasks.backend.globalRect(task), task);
                }
                destroy();
            }
        }
    }

    Connections {
        target: Plasmoid

        function onLocationChanged(): void {
            if (TaskTools.taskManagerInstanceCount >= 2) {
                return;
            }
            // This is on a timer because the panel may not have
            // settled into position yet when the location prop-
            // erty updates.
            iconGeometryTimer.start();
        }
    }

    Connections {
        target: Plasmoid.containment

        function onScreenGeometryChanged(): void {
            iconGeometryTimer.start();
        }
    }

    Mpris.Mpris2Model {
        id: mpris2Source
    }

    Item {
        anchors.fill: parent

        TaskManager.VirtualDesktopInfo {
            id: virtualDesktopInfo
        }

        TaskManager.ActivityInfo {
            id: activityInfo
            readonly property string nullUuid: "00000000-0000-0000-0000-000000000000"
        }

        Loader {
            id: pulseAudio
            sourceComponent: tasks.pulseAudioComponent
            active: tasks.pulseAudioComponent.status === Component.Ready
        }

        Timer {
            id: iconGeometryTimer

            interval: 500
            repeat: false

            onTriggered: {
                tasks.publishIconGeometries(taskList.children, tasks);
            }
        }

        Binding {
            target: Plasmoid
            property: "status"
            value: (tasksModel.anyTaskDemandsAttention && Plasmoid.configuration.unhideOnAttention
                ? PlasmaCore.Types.NeedsAttentionStatus : PlasmaCore.Types.PassiveStatus)
            restoreMode: Binding.RestoreBinding
        }

        Connections {
            target: Plasmoid.configuration

            function onLaunchersChanged(): void {
                tasksModel.launcherList = Plasmoid.configuration.launchers
            }
            function onGroupingAppIdBlacklistChanged(): void {
                tasksModel.groupingAppIdBlacklist = Plasmoid.configuration.groupingAppIdBlacklist;
            }
            function onGroupingLauncherUrlBlacklistChanged(): void {
                tasksModel.groupingLauncherUrlBlacklist = Plasmoid.configuration.groupingLauncherUrlBlacklist;
            }
        }

        Component {
            id: busyIndicator
            PlasmaComponents3.BusyIndicator {}
        }

        // Save drag data
        Item {
            id: dragHelper

            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction | Qt.MoveAction | Qt.LinkAction
            Drag.onDragFinished: dropAction => {
                tasks.dragSource = null;
            }
        }

        KSvg.FrameSvgItem {
            id: taskFrame

            visible: false

            imagePath: "widgets/tasks"
            prefix: TaskTools.taskPrefix("normal", Plasmoid.location)
        }

        MouseHandler {
            id: mouseHandler

            anchors.fill: parent

            target: taskList

            onUrlsDropped: urls => {
                // If all dropped URLs point to application desktop files, we'll add a launcher for each of them.
                const createLaunchers = urls.every(item => tasks.backend.isApplication(item));

                if (createLaunchers) {
                    urls.forEach(item => addLauncher(item));
                    return;
                }

                if (!hoveredItem) {
                    return;
                }

                // Otherwise we'll just start a new instance of the application with the URLs as argument,
                // as you probably don't expect some of your files to open in the app and others to spawn launchers.
                tasksModel.requestOpenUrls((hoveredItem as Task).modelIndex(), urls);
            }
        }

        ToolTipDelegate {
            id: openWindowToolTipDelegate
            visible: false
        }

        ToolTipDelegate {
            id: pinnedAppToolTipDelegate
            visible: false
        }

        TriangleMouseFilter {
            id: tmf
            filterTimeOut: 300
            active: tasks.toolTipAreaItem && tasks.toolTipAreaItem.toolTipOpen
            blockFirstEnter: false

            edge: {
                switch (tasks.effectiveLocation) {
                case PlasmaCore.Types.BottomEdge:
                    return Qt.TopEdge;
                case PlasmaCore.Types.TopEdge:
                    return Qt.BottomEdge;
                case PlasmaCore.Types.LeftEdge:
                    return Qt.RightEdge;
                case PlasmaCore.Types.RightEdge:
                    return Qt.LeftEdge;
                default:
                    return Qt.TopEdge;
                }
            }

            LayoutMirroring.enabled: tasks.shouldBeMirrored(Plasmoid.configuration.reverseMode, Application.layoutDirection, tasks.vertical)

            width: tasks.vertical ? (tasks.iconSize + tasks.horizontalPadding * 2) : (taskList.width + tasks.horizontalPadding * 2)
            height: tasks.vertical ? (taskList.height + tasks.verticalPadding * 2) : (tasks.iconSize + tasks.verticalPadding * 2)

            anchors {
                horizontalCenter: tasks.vertical ? undefined : parent.horizontalCenter
                verticalCenter: tasks.vertical ? parent.verticalCenter : undefined
                bottom: (!tasks.vertical && tasks.effectiveLocation !== PlasmaCore.Types.TopEdge) ? parent.bottom : undefined
                bottomMargin: (!tasks.vertical && tasks.effectiveLocation !== PlasmaCore.Types.TopEdge) ? (tasks.elevation - tasks.panelBottomInset) : 0
                top: (!tasks.vertical && tasks.effectiveLocation === PlasmaCore.Types.TopEdge) ? parent.top : undefined
                topMargin: (!tasks.vertical && tasks.effectiveLocation === PlasmaCore.Types.TopEdge) ? (tasks.elevation - tasks.panelTopInset) : 0
                left: (tasks.vertical && tasks.effectiveLocation === PlasmaCore.Types.LeftEdge) ? parent.left : undefined
                leftMargin: (tasks.vertical && tasks.effectiveLocation === PlasmaCore.Types.LeftEdge) ? (tasks.elevation - tasks.panelLeftInset) : 0
                right: (tasks.vertical && tasks.effectiveLocation === PlasmaCore.Types.RightEdge) ? parent.right : undefined
                rightMargin: (tasks.vertical && tasks.effectiveLocation === PlasmaCore.Types.RightEdge) ? (tasks.elevation - tasks.panelRightInset) : 0
            }

            // macOS dock capsule background (Solid, Transparent, Translucent, System Blur, or Liquid Glass)
            LiquidGlassBackground {
                id: dockBackground
                anchors.fill: parent
                radius: Math.min(width, height) / 3
                backgroundType: tasks.containerBackgroundType
                customBackgroundColor: tasks.containerBackgroundColor
                customBorderWidth: tasks.containerBorderWidth
                customBorderColor: tasks.containerBorderColor
                blurOpacity: tasks.blurOpacity
                blurSaturation: tasks.blurSaturation
                blurContrast: tasks.blurContrast
                blurBrightness: tasks.blurBrightness
                isVertical: tasks.vertical
                z: -1
            }

            TaskList {
                id: taskList

                vertical: tasks.vertical
                LayoutMirroring.enabled: tasks.shouldBeMirrored(Plasmoid.configuration.reverseMode, Application.layoutDirection, tasks.vertical)
                anchors.centerIn: parent

                count: tasksModel.count
                iconSpacing: tasks.iconSpacing

                width: tasks.shouldShrinkToZero ? 0 : (tasks.vertical ? tasks.iconSize : Math.max(tasks.tasksLength, implicitWidth))
                height: tasks.shouldShrinkToZero ? 0 : (tasks.vertical ? Math.max(tasks.tasksLength, implicitHeight) : tasks.iconSize)

                onAnimatingChanged: {
                    if (!animating) {
                        tasks.publishIconGeometries(children, tasks);
                    }
                }

                Repeater {
                    id: taskRepeater

                    delegate: Task {
                        tasksRoot: tasks
                    }
                }
            }
        }
    }

    readonly property Component groupDialogComponent: Qt.createComponent("GroupDialog.qml")
    property GroupDialog groupDialog

    readonly property bool supportsLaunchers: true

    function hasLauncher(url: url): bool {
        return tasksModel.launcherPosition(url) !== -1;
    }

    function addLauncher(url: url): void {
        if (Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable) {
            tasksModel.requestAddLauncher(url);
        }
    }

    function removeLauncher(url: url): void {
        if (Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable) {
            tasksModel.requestRemoveLauncher(url);
        }
    }

    // This is called by plasmashell in response to a Meta+number shortcut.
    // TODO: Change type to int
    function activateTaskAtIndex(index: var): void {
        if (typeof index !== "number") {
            return;
        }

        const task = taskRepeater.itemAt(index) as Task;
        if (task) {
            TaskTools.activateTask(task.modelIndex(), task.model, null, task, Plasmoid, this, effectWatcher.registered);
        }
    }

    function createContextMenu(rootTask, modelIndex, args = {}) {
        const initialArgs = Object.assign(args, {
            visualParent: rootTask,
            modelIndex,
            mpris2Source,
            backend,
        });
        return contextMenuComponent.createObject(rootTask, initialArgs);
    }

    function shouldBeMirrored(reverseMode, layoutDirection, vertical): bool {
        // LayoutMirroring is only horizontal
        if (vertical) {
            return layoutDirection === Qt.RightToLeft;
        }

        if (layoutDirection === Qt.LeftToRight) {
            return reverseMode;
        }
        return !reverseMode;
    }

    Component.onCompleted: {
        TaskTools.taskManagerInstanceCount += 1;
        requestLayout.connect(iconGeometryTimer.restart);
        applyPanelTransparency();
    }

    Component.onDestruction: {
        TaskTools.taskManagerInstanceCount -= 1;
    }
}
