/*
    SPDX-FileCopyrightText: 2012-2013 Eike Hein <hein@kde.org>
    SPDX-FileCopyrightText: 2024 Nate Graham <nate@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.core as PlasmaCore
import org.kde.ksvg as KSvg
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import "code/LayoutMetrics.js" as LayoutMetrics
import "code/TaskTools.js" as TaskTools
import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager
import org.cesar.dock 1.0

PlasmaCore.ToolTipArea {
    id: task

    activeFocusOnTab: true

    // To achieve a bottom-to-top layout on vertical panels, the task manager
    // is rotated by 180 degrees(see main.qml). This makes the tasks rotated,
    // so un-rotate them here to fix that.
    rotation: Plasmoid.configuration.reverseMode && (tasksRoot ? tasksRoot.vertical : false) ? 180 : 0

    readonly property real targetZoomFactor: (!inPopup && tasksRoot) ? tasksRoot.magnificationFactorForIndex(index) : 0.0
    readonly property real zoomFactor: targetZoomFactor

    readonly property real maxElevatedReach: {
        if (!tasksRoot) return 60;
        const extraIconHeight = Math.ceil(tasksRoot.iconSize * ((tasksRoot.zoomMultiplier || 1.5) - 1.0));
        const lift = tasksRoot.hoverElevation !== undefined ? tasksRoot.hoverElevation : 12;
        return extraIconHeight + lift + 16;
    }

    readonly property bool isTaskHovered: (!inPopup && (containsMouse || (taskHoverHandler && taskHoverHandler.hovered)))

    readonly property real effectiveZoom: Math.max(0.0, zoomFactor)
    readonly property real currentScale: 1.0 + ((tasksRoot ? tasksRoot.zoomMultiplier : 1.5) - 1.0) * effectiveZoom
    readonly property real currentHoverLift: (tasksRoot ? tasksRoot.hoverElevation : 12) * effectiveZoom
    readonly property real extraSpan: (tasksRoot && !inPopup)
        ? (tasksRoot.iconSize * (currentScale - 1.0) + (tasksRoot.iconSpacing * 0.5) * effectiveZoom)
        : 0.0

    readonly property bool isPinned: Boolean(model.IsLauncher || (model.LauncherUrlWithoutIcon && tasksRoot && tasksRoot.hasLauncher(model.LauncherUrlWithoutIcon)))
    readonly property bool isDividerTask: Boolean(tasksRoot && tasksRoot.hasDivider && tasksRoot.firstUnpinnedIndex === index)
    readonly property int dividerOffset: isDividerTask ? (tasksRoot ? tasksRoot.dividerSpan : 12) : 0
    readonly property bool isLaunchpad: Boolean((model.LauncherUrlWithoutIcon && String(model.LauncherUrlWithoutIcon).indexOf("launchpad") !== -1)
        || (model.AppId && String(model.AppId).indexOf("launchpad") !== -1))

    z: inPopup ? 0 : Math.round(effectiveZoom * 100)

    implicitHeight: inPopup
                    ? LayoutMetrics.preferredHeightInPopup()
                    : tasksRoot.iconSize
    implicitWidth: inPopup
                    ? LayoutMetrics.preferredMaxWidth()
                    : tasksRoot.iconSize

    width: Layout.preferredWidth
    height: Layout.preferredHeight

    Layout.fillWidth: false
    Layout.fillHeight: false
    Layout.preferredWidth: implicitWidth + (!tasksRoot.vertical ? (extraSpan + dividerOffset) : 0)
    Layout.preferredHeight: implicitHeight + (tasksRoot.vertical ? (extraSpan + dividerOffset) : 0)
    Layout.minimumWidth: Layout.preferredWidth
    Layout.minimumHeight: Layout.preferredHeight
    Layout.maximumWidth: Layout.preferredWidth
    Layout.maximumHeight: Layout.preferredHeight

    required property var model
    required property int index
    required property /*main.qml*/ Item tasksRoot

    readonly property TaskManager.TasksModel tasksModel: tasksRoot.tasksModel
    readonly property var backend: tasksRoot.backend

    readonly property int pid: model.AppPid
    readonly property string appName: model.AppName
    readonly property string appId: (model.AppId || "").replace(/\.desktop/, '')
    readonly property bool isIcon: tasksRoot.iconsOnly || model.IsLauncher
    property bool toolTipOpen: false
    property bool inPopup: false
    property bool isWindow: model.IsWindow
    property int childCount: model.ChildCount
    property int previousChildCount: 0
    property alias labelText: label.text
    property QtObject contextMenu: null
    readonly property bool smartLauncherEnabled: !inPopup
    property QtObject smartLauncherItem: null

    readonly property int badgeCount: {
        const _ = (typeof dockBackend !== "undefined" && dockBackend) ? dockBackend.indicatorsVersion : 0;
        return (typeof dockBackend !== "undefined" && dockBackend) ? dockBackend.badgeCount(task.appId, String(model.LauncherUrlWithoutIcon || ""), task.model ? task.model.display : "") : 0;
    }
    readonly property bool badgeVisible: {
        const _ = (typeof dockBackend !== "undefined" && dockBackend) ? dockBackend.indicatorsVersion : 0;
        return (typeof dockBackend !== "undefined" && dockBackend) ? dockBackend.badgeVisible(task.appId, String(model.LauncherUrlWithoutIcon || ""), task.model ? task.model.display : "") : false;
    }
    readonly property real taskProgress: {
        const _ = (typeof dockBackend !== "undefined" && dockBackend) ? dockBackend.indicatorsVersion : 0;
        return (typeof dockBackend !== "undefined" && dockBackend) ? dockBackend.progress(task.appId, String(model.LauncherUrlWithoutIcon || "")) : 0.0;
    }
    readonly property bool progressVisible: {
        const _ = (typeof dockBackend !== "undefined" && dockBackend) ? dockBackend.indicatorsVersion : 0;
        return (typeof dockBackend !== "undefined" && dockBackend) ? dockBackend.progressVisible(task.appId, String(model.LauncherUrlWithoutIcon || "")) : false;
    }

    property Item audioStreamIcon: null
    property var audioStreams: []
    property bool delayAudioStreamIndicator: false
    property bool completed: false
    readonly property bool audioIndicatorsEnabled: Plasmoid.configuration.indicateAudioStreams
    readonly property bool tooltipControlsEnabled: Plasmoid.configuration.tooltipControls
    readonly property bool hasAudioStream: audioStreams.length > 0
    readonly property bool playingAudio: hasAudioStream && audioStreams.some(item => !item.corked)
    readonly property bool muted: hasAudioStream && audioStreams.every(item => item.muted)

    readonly property bool highlighted: (inPopup && activeFocus) || (!inPopup && isTaskHovered)
        || (task.contextMenu && task.contextMenu.status === PlasmaExtras.Menu.Open)
        || (!!tasksRoot.groupDialog && tasksRoot.groupDialog.visualParent === task)

    property bool hasAttention: false

    function updateAttention(): void {
        if (!tasksModel) {
            return;
        }

        let att = false;
        try {
            // 1. Direct property check on model
            if (task.model && task.model.IsDemandingAttention) {
                att = true;
            }

            // 2. Query model role on task's own index
            const mIdx = task.modelIndex();
            if (!att && mIdx) {
                att = Boolean(tasksModel.data(mIdx, TaskManager.AbstractTasksModel.IsDemandingAttention));
            }

            // 3. Urgent indicators (Unity / DBus)
            if (!att && typeof dockBackend !== "undefined" && dockBackend && dockBackend.demandsAttention(task.appId, task.launcherUrl)) {
                att = true;
            }

            // 4. Query child tasks if grouped
            if (!att && mIdx) {
                const count = tasksModel.rowCount(mIdx);
                for (let i = 0; i < count; ++i) {
                    const childIdx = tasksModel.makeModelIndex(task.index, i);
                    if (tasksModel.data(childIdx, TaskManager.AbstractTasksModel.IsDemandingAttention)) {
                        att = true;
                        break;
                    }
                }
            }
        } catch (e) {
            // Guard against unready indexes
        }

        hasAttention = att;
    }

    readonly property bool isRunning: Boolean(task.model.IsWindow || (task.childCount > 0))
    readonly property bool isTaskActive: {
        if (Boolean(task.model.IsActive)) {
            return true;
        }
        if (task.childCount > 0) {
            try {
                for (let i = 0; i < task.childCount; ++i) {
                    const childIdx = tasksModel.makeModelIndex(task.index, i);
                    if (tasksModel.data(childIdx, TaskManager.AbstractTasksModel.IsActive)) {
                        return true;
                    }
                }
            } catch (e) {
                // Guard against unready indexes
            }
        }
        return false;
    }
    readonly property bool demandsAttention: hasAttention || Boolean(task.model.IsDemandingAttention || (typeof dockBackend !== "undefined" && dockBackend && dockBackend.demandsAttention(task.appId, model.LauncherUrlWithoutIcon)) || task.model.IsStartup)

    active: !inPopup && !tasksRoot.groupDialog && task.contextMenu?.status !== PlasmaExtras.Menu.Open
    interactive: model.IsWindow || mainItem.playerData
    location: tasksRoot ? tasksRoot.effectiveLocation : Plasmoid.location
    mainItem: !Plasmoid.configuration.showToolTips || !model.IsWindow ? pinnedAppToolTipDelegate : openWindowToolTipDelegate

    onXChanged: {
        if (!completed) {
            return;
        }
        if (tasksRoot && tasksRoot.zoomEnabled && (tasksRoot.hoveredTaskIndex >= 0 || tasksRoot.dockHoverProgress > 0 || zoomFactor > 0)) {
            if (moveAnim.running) {
                moveAnim.stop();
                translateTransform.x = 0;
            }
            oldX = x;
            return;
        }
        if (oldX < 0) {
            oldX = x;
            return;
        }
        moveAnim.x = oldX - x + translateTransform.x;
        moveAnim.y = translateTransform.y;
        oldX = x;
        moveAnim.restart();
    }
    onYChanged: {
        if (!completed) {
            return;
        }
        if (tasksRoot && tasksRoot.zoomEnabled && (tasksRoot.hoveredTaskIndex >= 0 || tasksRoot.dockHoverProgress > 0 || zoomFactor > 0)) {
            if (moveAnim.running) {
                moveAnim.stop();
                translateTransform.y = 0;
            }
            oldY = y;
            return;
        }
        if (oldY < 0) {
            oldY = y;
            return;
        }
        moveAnim.y = oldY - y + translateTransform.y;
        moveAnim.x = translateTransform.x;
        oldY = y;
        moveAnim.restart();
    }

    property real oldX: -1
    property real oldY: -1
    SequentialAnimation {
        id: moveAnim
        property real x
        property real y
        onRunningChanged: {
            if (running) {
                ++task.parent.animationsRunning;
            } else {
                --task.parent.animationsRunning;
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: translateTransform
                properties: "x"
                from: moveAnim.x
                to: 0
                easing.type: Easing.OutQuad
                duration: Kirigami.Units.longDuration
            }
            NumberAnimation {
                target: translateTransform
                properties: "y"
                from: moveAnim.y
                to: 0
                easing.type: Easing.OutQuad
                duration: Kirigami.Units.longDuration
            }
        }
    }
    transform: Translate {
        id: translateTransform
    }

    Accessible.name: model.display
    Accessible.description: {
        if (!model.display) {
            return "";
        }

        if (model.IsLauncher) {
            return i18nc("@info:usagetip %1 application name", "Launch %1", model.display)
        }

        let smartLauncherDescription = "";
        if (task.badgeVisible && task.badgeCount > 0) {
            smartLauncherDescription += i18ncp("@info:tooltip", "There is %1 new message.", "There are %1 new messages.", task.badgeCount);
        }

        if (model.IsGroupParent) {
            switch (Plasmoid.configuration.groupedTaskVisualization) {
            case 0:
                break; // Use the default description
            case 1: {
                return `${i18nc("@info:usagetip %1 task name", "Show Task tooltip for %1", model.display)}; ${smartLauncherDescription}`;
            }
            case 2: {
                if (effectWatcher.registered) {
                    return `${i18nc("@info:usagetip %1 task name", "Show windows side by side for %1", model.display)}; ${smartLauncherDescription}`;
                }
                // fallthrough
            }
            default:
                return `${i18nc("@info:usagetip %1 task name", "Open textual list of windows for %1", model.display)}; ${smartLauncherDescription}`;
            }
        }

        return `${i18nc("@info:usagetip %1 task name", "Activate %1", model.display)}; ${smartLauncherDescription}`;
    }
    Accessible.role: Accessible.Button
    Accessible.onPressAction: leftTapHandler.leftClick()

    onToolTipVisibleChanged: toolTipVisible => {
        task.toolTipOpen = toolTipVisible;
        if (!toolTipVisible) {
            tasksRoot.toolTipOpenedByClick = null;
        } else {
            tasksRoot.toolTipAreaItem = task;
        }
    }

    Timer {
        id: hoverToolTipTimer
        interval: (tasksRoot && tasksRoot.toolTipAreaItem && tasksRoot.toolTipAreaItem.toolTipOpen)
            ? 0
            : Kirigami.Units.toolTipDelay
        onTriggered: {
            if (task.isTaskHovered && task.active && !task.toolTipOpen) {
                task.updateMainItemBindings();
                task.showToolTip();
            }
        }
    }

    readonly property int halfSpacing: Math.ceil((tasksRoot ? tasksRoot.iconSpacing : 4) / 2)

    function reportContinuousHover(pos: point): void {
        if (!tasksRoot || !tasksRoot.zoomEnabled) {
            return;
        }
        const isVert = tasksRoot.vertical;
        const totalSpan = isVert ? task.height : task.width;
        const divOffset = task.dividerOffset || 0;
        const iconSpan = Math.max(1, totalSpan - divOffset);
        const rawCoord = (isVert ? pos.y : pos.x) - halfSpacing;
        const iconCoord = rawCoord - divOffset;
        let ratio = (iconCoord - (iconSpan / 2)) / iconSpan;

        const mirrored = tasksRoot.shouldBeMirrored(Plasmoid.configuration.reverseMode, Application.layoutDirection, isVert);
        if (mirrored) {
            ratio = -ratio;
        }

        tasksRoot.setHoverPosition(index, ratio);
    }

    onIsTaskHoveredChanged: {
        if (isTaskHovered) {
            hoverToolTipTimer.restart();
            if (taskHoverHandler && taskHoverHandler.hovered) {
                reportContinuousHover(taskHoverHandler.point.position);
            } else if (tasksRoot) {
                tasksRoot.setHoveredTask(index);
            }
        } else {
            hoverToolTipTimer.stop();
            task.hideToolTip();
            tasksRoot.toolTipOpenedByClick = null;
            if (tasksRoot) {
                tasksRoot.clearHoveredTask(index);
            }
        }
    }

    onHighlightedChanged: {
        // ensure it doesn't get stuck with a window highlighted
        tasksRoot.cancelHighlightWindows();
    }

    onPidChanged: updateAudioStreams({delay: false})
    onAppNameChanged: updateAudioStreams({delay: false})

    onIsWindowChanged: {
        if (model.IsWindow) {
            taskInitComponent.createObject(task);
            updateAudioStreams({delay: false});
        }
    }

    onChildCountChanged: {
        if (TaskTools.taskManagerInstanceCount < 2 && childCount > previousChildCount) {
            tasksModel.requestPublishDelegateGeometry(modelIndex(), backend.globalRect(task), task);
        }

        previousChildCount = childCount;
        updateAttention();
    }

    Connections {
        target: tasksModel
        ignoreUnknownSignals: true
        function onDataChanged(): void {
            task.updateAttention();
        }
        function onAnyTaskDemandsAttentionChanged(): void {
            task.updateAttention();
        }
    }

    onIndexChanged: {
        hideToolTip();

        if (!inPopup && !tasksRoot.vertical
                && !Plasmoid.configuration.separateLaunchers) {
            tasksRoot.requestLayout();
        }

        task.updateAttention();
    }

    onSmartLauncherEnabledChanged: {
        if (smartLauncherEnabled && !smartLauncherItem) {
            try {
                const component = Qt.createComponent("plasma.applet.org.kde.plasma.taskmanager", "SmartLauncherItem");
                if (component && component.status === Component.Ready) {
                    const smartLauncher = component.createObject(task);
                    smartLauncher.launcherUrl = Qt.binding(() => model.LauncherUrlWithoutIcon);
                    smartLauncherItem = smartLauncher;
                }
            } catch (e) {
                smartLauncherItem = null;
            }
        }
    }

    onHasAudioStreamChanged: {
        const audioStreamIconActive = hasAudioStream && audioIndicatorsEnabled;
        if (!audioStreamIconActive) {
            if (audioStreamIcon !== null) {
                audioStreamIcon.destroy();
                audioStreamIcon = null;
            }
            return;
        }
        // Create item on demand instead of using Loader to reduce memory consumption,
        // because only a few applications have audio streams.
        const component = Qt.createComponent("AudioStream.qml");
        audioStreamIcon = component.createObject(task);
        component.destroy();
    }
    onAudioIndicatorsEnabledChanged: task.hasAudioStreamChanged()

    Keys.onMenuPressed: event => contextMenuTimer.start()
    Keys.onReturnPressed: event => TaskTools.activateTask(modelIndex(), model, event.modifiers, task, Plasmoid, tasksRoot, effectWatcher.registered)
    Keys.onEnterPressed: event => Keys.returnPressed(event);
    Keys.onSpacePressed: event => Keys.returnPressed(event);
    Keys.onUpPressed: event => Keys.leftPressed(event)
    Keys.onDownPressed: event => Keys.rightPressed(event)
    Keys.onLeftPressed: event => {
        if (!inPopup && (event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier)) {
            tasksModel.move(task.index, task.index - 1);
        } else {
            event.accepted = false;
        }
    }
    Keys.onRightPressed: event => {
        if (!inPopup && (event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier)) {
            tasksModel.move(task.index, task.index + 1);
        } else {
            event.accepted = false;
        }
    }

    function modelIndex(): /*QModelIndex*/ var {
        return inPopup
            ? tasksModel.makeModelIndex(groupDialog.visualParent.index, index)
            : tasksModel.makeModelIndex(index);
    }

    function showContextMenu(args: var): void {
        task.hideImmediately();
        contextMenu = tasksRoot.createContextMenu(task, modelIndex(), args) as ContextMenu;
        contextMenu.show();
    }

    function updateAudioStreams(args: var): void {
        if (args) {
            // When the task just appeared (e.g. virtual desktop switch), show the audio indicator
            // right away. Only when audio streams change during the lifetime of this task, delay
            // showing that to avoid distraction.
            delayAudioStreamIndicator = !!args.delay;
        }

        var pa = pulseAudio.item;
        if (!pa || !task.isWindow) {
            task.audioStreams = [];
            return;
        }

        // Check appid first for app using portal
        // https://docs.pipewire.org/page_portal.html
        var streams = pa.streamsForAppId(task.appId);
        if (!streams.length) {
            streams = pa.streamsForPid(model.AppPid);
            if (streams.length) {
                pa.registerPidMatch(model.AppName);
            } else {
                // We only want to fall back to appName matching if we never managed to map
                // a PID to an audio stream window. Otherwise if you have two instances of
                // an application, one playing and the other not, it will look up appName
                // for the non-playing instance and erroneously show an indicator on both.
                if (!pa.hasPidMatch(model.AppName)) {
                    streams = pa.streamsForAppName(model.AppName);
                }
            }
        }

        task.audioStreams = streams;
    }

    function toggleMuted(): void {
        if (muted) {
            task.audioStreams.forEach(item => item.unmute());
        } else {
            task.audioStreams.forEach(item => item.mute());
        }
    }

    // Will also be called in activateTaskAtIndex(index)
    function updateMainItemBindings(): void {
        if ((mainItem.parentTask === this && mainItem.rootIndex.row === index)
            || (tasksRoot.toolTipOpenedByClick === null && !active)
            || (tasksRoot.toolTipOpenedByClick !== null && tasksRoot.toolTipOpenedByClick !== this)) {
            return;
        }

        mainItem.blockingUpdates = (mainItem.isGroup !== model.IsGroupParent); // BUG 464597 Force unload the previous component

        mainItem.parentTask = this;
        mainItem.rootIndex = tasksModel.makeModelIndex(index, -1);

        mainItem.appName = Qt.binding(() => model.AppName);
        mainItem.pidParent = Qt.binding(() => model.AppPid);
        mainItem.windows = Qt.binding(() => model.WinIdList);
        mainItem.isGroup = Qt.binding(() => model.IsGroupParent);
        mainItem.icon = Qt.binding(() => model.decoration);
        mainItem.launcherUrl = Qt.binding(() => model.LauncherUrlWithoutIcon);
        mainItem.isLauncher = Qt.binding(() => model.IsLauncher);
        mainItem.isMinimized = Qt.binding(() => model.IsMinimized);
        mainItem.display = Qt.binding(() => model.display);
        mainItem.genericName = Qt.binding(() => model.GenericName);
        mainItem.virtualDesktops = Qt.binding(() => model.VirtualDesktops);
        mainItem.isOnAllVirtualDesktops = Qt.binding(() => model.IsOnAllVirtualDesktops);
        mainItem.activities = Qt.binding(() => model.Activities);

        mainItem.smartLauncherCountVisible = Qt.binding(() => task.badgeVisible);
        mainItem.smartLauncherCount = Qt.binding(() => task.badgeCount);

        mainItem.blockingUpdates = false;
        tasksRoot.toolTipAreaItem = this;
    }

    Connections {
        target: pulseAudio.item
        ignoreUnknownSignals: true // Plasma-PA might not be available
        function onStreamsChanged(): void {
            task.updateAudioStreams({delay: true})
        }
    }

    TapHandler {
        id: menuTapHandler
        acceptedButtons: Qt.LeftButton
        acceptedDevices: PointerDevice.TouchScreen | PointerDevice.Stylus
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onLongPressed: {
            // When we're a launcher, there's no window controls, so we can show all
            // places without the menu getting super huge.
            if (task.model.IsLauncher) {
                task.showContextMenu({showAllPlaces: true})
            } else {
                task.showContextMenu();
            }
        }
    }

    Item {
        id: hoverHitBox

        anchors {
            left: !tasksRoot.vertical ? parent.left : (tasksRoot.effectiveLocation === PlasmaCore.Types.LeftEdge ? parent.left : undefined)
            right: !tasksRoot.vertical ? parent.right : (tasksRoot.effectiveLocation === PlasmaCore.Types.RightEdge ? parent.right : undefined)
            top: tasksRoot.vertical ? parent.top : (tasksRoot.effectiveLocation === PlasmaCore.Types.TopEdge ? parent.top : undefined)
            bottom: tasksRoot.vertical ? parent.bottom : (tasksRoot.effectiveLocation !== PlasmaCore.Types.TopEdge ? parent.bottom : undefined)

            topMargin: tasksRoot.vertical
                ? -task.halfSpacing
                : ((tasksRoot.effectiveLocation === PlasmaCore.Types.TopEdge) ? -(tasksRoot ? tasksRoot.verticalPadding : 8) : 0)
            bottomMargin: tasksRoot.vertical
                ? -task.halfSpacing
                : ((tasksRoot.effectiveLocation !== PlasmaCore.Types.TopEdge) ? -(tasksRoot ? tasksRoot.verticalPadding : 8) : 0)
            leftMargin: !tasksRoot.vertical
                ? -task.halfSpacing
                : ((tasksRoot.effectiveLocation === PlasmaCore.Types.LeftEdge) ? -(tasksRoot ? tasksRoot.horizontalPadding : 8) : 0)
            rightMargin: !tasksRoot.vertical
                ? -task.halfSpacing
                : ((tasksRoot.effectiveLocation === PlasmaCore.Types.RightEdge) ? -(tasksRoot ? tasksRoot.horizontalPadding : 8) : 0)
        }

        width: tasksRoot.vertical ? (parent.width + (tasksRoot ? tasksRoot.horizontalPadding : 8) + task.maxElevatedReach) : (parent.width + task.halfSpacing * 2)
        height: !tasksRoot.vertical ? (parent.height + (tasksRoot ? tasksRoot.verticalPadding : 8) + task.maxElevatedReach) : (parent.height + task.halfSpacing * 2)

        HoverHandler {
            id: taskHoverHandler
            enabled: !task.inPopup
            onPointChanged: {
                if (hovered && tasksRoot && tasksRoot.zoomEnabled) {
                    task.reportContinuousHover(point.position);
                }
            }
        }

        TapHandler {
            acceptedButtons: Qt.LeftButton
            enabled: !task.inPopup
            onTapped: (eventPoint, button) => {
                if (task.isLaunchpad) {
                    DockBackend.toggleLaunchpad();
                    return;
                }
                leftTapHandler.leftClick();
            }
        }

        TapHandler {
            acceptedButtons: Qt.RightButton
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
            enabled: !task.inPopup
            gesturePolicy: TapHandler.WithinBounds
            onPressedChanged: if (pressed) contextMenuTimer.start()
        }
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
        enabled: task.inPopup
        gesturePolicy: TapHandler.WithinBounds // Release grab when menu appears
        onPressedChanged: if (pressed) contextMenuTimer.start()
    }

    Timer {
        id: contextMenuTimer
        interval: 0
        onTriggered: menuTapHandler.longPressed()
    }

    TapHandler {
        id: leftTapHandler
        acceptedButtons: Qt.LeftButton
        enabled: task.inPopup
        onTapped: (eventPoint, button) => leftClick()

        function leftClick(): void {
            task.testBounce = false;
            if (task.active) {
                task.hideToolTip();
            }
            if (task.isLaunchpad) {
                DockBackend.toggleLaunchpad();
                return;
            }
            TaskTools.activateTask(modelIndex(), model, point.modifiers, task, Plasmoid, tasksRoot, effectWatcher.registered);
        }
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton
        onTapped: (eventPoint, button) => {
            if (button === Qt.MiddleButton) {
                if (Plasmoid.configuration.middleClickAction === tasksRoot.backend.newInstance) {
                    tasksModel.requestNewInstance(modelIndex());
                } else if (Plasmoid.configuration.middleClickAction === tasksRoot.backend.close) {
                    tasksModel.requestClose(modelIndex());
                } else if (Plasmoid.configuration.middleClickAction === tasksRoot.backend.toggleMinimized) {
                    tasksModel.requestToggleMinimized(modelIndex());
                } else if (Plasmoid.configuration.middleClickAction === tasksRoot.backend.toggleGrouping) {
                    tasksModel.requestToggleGrouping(modelIndex());
                } else if (Plasmoid.configuration.middleClickAction === tasksRoot.backend.bringToCurrentDesktop) {
                    tasksModel.requestVirtualDesktops(modelIndex(), [virtualDesktopInfo.currentDesktop]);
                }
            } else if (button === Qt.BackButton || button === Qt.ForwardButton) {
                const playerData = mpris2Source.playerForLauncherUrl(task.model.LauncherUrlWithoutIcon, task.model.AppPid);
                if (playerData) {
                    if (button === Qt.BackButton) {
                        playerData.Previous();
                    } else {
                        playerData.Next();
                    }
                } else {
                    eventPoint.accepted = false;
                }
            }

            task.tasksRoot.cancelHighlightWindows();
        }
    }

    KSvg.FrameSvgItem {
        id: frame
        opacity: task.inPopup ? 1 : 0

        anchors {
            fill: parent

            topMargin: (!task.tasksRoot.vertical && taskList.rows > 1) ? LayoutMetrics.iconMargin : 0
            bottomMargin: (!task.tasksRoot.vertical && taskList.rows > 1) ? LayoutMetrics.iconMargin : 0
            leftMargin: ((task.inPopup || task.tasksRoot.vertical) && taskList.columns > 1) ? LayoutMetrics.iconMargin : 0
            rightMargin: ((task.inPopup || task.tasksRoot.vertical) && taskList.columns > 1) ? LayoutMetrics.iconMargin : 0
        }

        imagePath: "widgets/tasks"
        property bool isHovered: task.highlighted && Plasmoid.configuration.taskHoverEffect
        property string basePrefix: "normal"
        prefix: isHovered ? TaskTools.taskPrefixHovered(basePrefix, Plasmoid.location) : TaskTools.taskPrefix(basePrefix, Plasmoid.location)

        // Avoid repositioning delegate item after dragFinished
        DragHandler {
            id: dragHandler
            grabPermissions: PointerHandler.CanTakeOverFromHandlersOfDifferentType

            function setRequestedInhibitDnd(value: bool): void {
                // This is modifying the value in the panel containment that
                // inhibits accepting drag and drop, so that we don't accidentally
                // drop the task on this panel.
                let item = this;
                while (item.parent) {
                    item = item.parent;
                    if (item.appletRequestsInhibitDnD !== undefined) {
                        item.appletRequestsInhibitDnD = value
                    }
                }
            }

            onActiveChanged: {
                if (active) {
                    icon.grabToImage(result => {
                        if (!dragHandler.active) {
                            // BUG 466675 grabToImage is async, so avoid updating dragSource when active is false
                            return;
                        }
                        setRequestedInhibitDnd(true);
                        tasksRoot.dragSource = task;
                        dragHelper.Drag.imageSource = result.url;
                        dragHelper.Drag.mimeData = {
                            "text/x-orgkdeplasmataskmanager_taskurl": backend.tryDecodeApplicationsUrl(model.LauncherUrlWithoutIcon).toString(),
                            [model.MimeType]: model.MimeData,
                            "application/x-orgkdeplasmataskmanager_taskbuttonitem": model.MimeData,
                        };
                        dragHelper.Drag.active = dragHandler.active;
                    });
                } else {
                    setRequestedInhibitDnd(false);
                    dragHelper.Drag.active = false;
                    dragHelper.Drag.imageSource = "";
                    tasksRoot.dragSource = null;
                }
            }
        }
    }

    Loader {
        id: iconBox

        anchors {
            left: parent.left
            leftMargin: adjustMargin(true, parent.width, taskFrame.margins.left)
            top: parent.top
            topMargin: adjustMargin(false, parent.height, taskFrame.margins.top)
        }

        width: task.inPopup ? Math.max(Kirigami.Units.iconSizes.sizeForLabels, Kirigami.Units.iconSizes.medium) : tasksRoot.iconSize
        height: width

        asynchronous: true
        active: height >= Kirigami.Units.iconSizes.small
                && task.badgeVisible && task.badgeCount > 0
        source: "TaskBadgeOverlay.qml"

        function adjustMargin(isVertical: bool, size: real, margin: real): real {
            if (!size) {
                return margin;
            }

            var margins = isVertical ? LayoutMetrics.horizontalMargins() : LayoutMetrics.verticalMargins();

            if ((size - margins) < Kirigami.Units.iconSizes.small) {
                return Math.ceil((margin * (Kirigami.Units.iconSizes.small / size)) / 2);
            }

            return margin;
        }

        Kirigami.Icon {
            id: icon

            anchors.fill: parent

            active: task.highlighted
            enabled: true

            source: task.model.decoration
        }

        Loader {
            id: taskProgressOverlayLoader
            anchors.fill: parent
            asynchronous: false
            active: task.progressVisible
            source: "TaskProgressOverlay.qml"
            z: 10
        }

        states: [
            // Using a state transition avoids a binding loop between label.visible and
            // the text label margin, which derives from the icon width.
            State {
                name: "standalone"
                when: !label.visible && task.parent

                AnchorChanges {
                    target: iconBox
                    anchors.left: (tasksRoot.vertical && tasksRoot.effectiveLocation === PlasmaCore.Types.LeftEdge) ? parent.left : undefined
                    anchors.right: (tasksRoot.vertical && tasksRoot.effectiveLocation === PlasmaCore.Types.RightEdge) ? parent.right : undefined
                    anchors.top: (!tasksRoot.vertical && tasksRoot.effectiveLocation === PlasmaCore.Types.TopEdge) ? parent.top : undefined
                    anchors.bottom: (!tasksRoot.vertical && tasksRoot.effectiveLocation !== PlasmaCore.Types.TopEdge) ? parent.bottom : undefined
                    anchors.horizontalCenter: tasksRoot.vertical ? undefined : parent.horizontalCenter
                    anchors.verticalCenter: tasksRoot.vertical ? parent.verticalCenter : undefined
                }

                PropertyChanges {
                    iconBox.anchors.leftMargin: 0
                    iconBox.anchors.topMargin: 0
                    iconBox.anchors.horizontalCenterOffset: (!tasksRoot.vertical && isDividerTask) ? Math.round(dividerOffset / 2) : 0
                    iconBox.anchors.verticalCenterOffset: (tasksRoot.vertical && isDividerTask) ? Math.round(dividerOffset / 2) : 0
                    iconBox.width: Math.round(tasksRoot.iconSize * task.currentScale)
                    iconBox.height: Math.round(tasksRoot.iconSize * task.currentScale)
                }
            }
        ]

        transform: [
            Translate {
                id: bounceTranslate
                x: 0
                y: 0
            },
            Translate {
                id: hoverTranslate
                x: tasksRoot.vertical ? (tasksRoot.effectiveLocation === PlasmaCore.Types.LeftEdge ? task.currentHoverLift : -task.currentHoverLift) : 0
                y: !tasksRoot.vertical ? (tasksRoot.effectiveLocation === PlasmaCore.Types.TopEdge ? task.currentHoverLift : -task.currentHoverLift) : 0
            }
        ]
    }

    property bool testBounce: false

    onIsTaskActiveChanged: {
        if (isTaskActive) {
            testBounce = false;
        }
    }

    Connections {
        target: (typeof dockBackend !== "undefined" && dockBackend) ? dockBackend : null
        function onDownloadFinished(appKey: string): void {
            if (!task.isTaskActive) {
                const myKey = (task.appId || "").toLowerCase();
                const myLauncher = (String(model.LauncherUrlWithoutIcon || "")).toLowerCase();
                const normAppKey = (appKey || "").toLowerCase();
                if (normAppKey.length > 0 && (myKey.includes(normAppKey) || normAppKey.includes(myKey) || myLauncher.includes(normAppKey))) {
                    task.triggerTestBounce();
                }
            }
        }
    }

    Timer {
        id: testBounceTimer
        interval: 3500
        onTriggered: task.testBounce = false
    }

    function triggerTestBounce(): void {
        testBounce = true;
        testBounceTimer.restart();
    }

    readonly property real bounceJumpHeight: Math.max(16, Math.round((tasksRoot ? tasksRoot.iconSize : 48) * 0.52))
    readonly property real bounceReboundHeight: Math.max(5, Math.round(bounceJumpHeight * 0.32))

    readonly property real bounceOffset: {
        if (!tasksRoot.vertical) {
            return tasksRoot.effectiveLocation === PlasmaCore.Types.TopEdge ? bounceJumpHeight : -bounceJumpHeight;
        } else {
            return tasksRoot.effectiveLocation === PlasmaCore.Types.LeftEdge ? bounceJumpHeight : -bounceJumpHeight;
        }
    }

    readonly property real bounceReboundOffset: {
        if (!tasksRoot.vertical) {
            return tasksRoot.effectiveLocation === PlasmaCore.Types.TopEdge ? bounceReboundHeight : -bounceReboundHeight;
        } else {
            return tasksRoot.effectiveLocation === PlasmaCore.Types.LeftEdge ? bounceReboundHeight : -bounceReboundHeight;
        }
    }

    SequentialAnimation {
        id: bounceAnim
        running: (task.demandsAttention || task.testBounce) && !task.inPopup
        loops: Animation.Infinite

        // Ascend to peak
        NumberAnimation {
            target: bounceTranslate
            property: tasksRoot.vertical ? "x" : "y"
            to: task.bounceOffset
            duration: 220
            easing.type: Easing.OutCubic
        }
        // Descend to base
        NumberAnimation {
            target: bounceTranslate
            property: tasksRoot.vertical ? "x" : "y"
            to: 0
            duration: 200
            easing.type: Easing.InQuad
        }
        // Elastic rebound
        NumberAnimation {
            target: bounceTranslate
            property: tasksRoot.vertical ? "x" : "y"
            to: task.bounceReboundOffset
            duration: 110
            easing.type: Easing.OutQuad
        }
        // Settle back to base
        NumberAnimation {
            target: bounceTranslate
            property: tasksRoot.vertical ? "x" : "y"
            to: 0
            duration: 100
            easing.type: Easing.InQuad
        }
        // Rest pause before next bounce
        PauseAnimation {
            duration: 280
        }

        onRunningChanged: {
            if (!running) {
                bounceTranslate.x = 0;
                bounceTranslate.y = 0;
            }
        }
    }

    // macOS Golden Gate active application reflection / spotlight glow
    Rectangle {
        id: activeSpotlight
        visible: !task.inPopup && task.isTaskActive
        z: -1
        width: Math.round(tasksRoot.iconSize * 0.72)
        height: 5
        radius: 2.5
        opacity: task.isTaskActive ? 1.0 : 0.0

        anchors {
            horizontalCenter: tasksRoot.vertical ? undefined : parent.horizontalCenter
            horizontalCenterOffset: (!tasksRoot.vertical && isDividerTask) ? Math.round(dividerOffset / 2) : 0
            verticalCenter: tasksRoot.vertical ? parent.verticalCenter : undefined
            verticalCenterOffset: (tasksRoot.vertical && isDividerTask) ? Math.round(dividerOffset / 2) : 0
            bottom: (!tasksRoot.vertical && tasksRoot.effectiveLocation !== PlasmaCore.Types.TopEdge) ? parent.bottom : undefined
            bottomMargin: (!tasksRoot.vertical && tasksRoot.effectiveLocation !== PlasmaCore.Types.TopEdge) ? -1 : 0
            top: (!tasksRoot.vertical && tasksRoot.effectiveLocation === PlasmaCore.Types.TopEdge) ? parent.top : undefined
            topMargin: (!tasksRoot.vertical && tasksRoot.effectiveLocation === PlasmaCore.Types.TopEdge) ? -1 : 0
            left: (tasksRoot.vertical && tasksRoot.effectiveLocation === PlasmaCore.Types.LeftEdge) ? parent.left : undefined
            leftMargin: (tasksRoot.vertical && tasksRoot.effectiveLocation === PlasmaCore.Types.LeftEdge) ? -1 : 0
            right: (tasksRoot.vertical && tasksRoot.effectiveLocation === PlasmaCore.Types.RightEdge) ? parent.right : undefined
            rightMargin: (tasksRoot.vertical && tasksRoot.effectiveLocation === PlasmaCore.Types.RightEdge) ? -1 : 0
        }

        gradient: Gradient {
            orientation: tasksRoot.vertical ? Gradient.Vertical : Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop {
                position: 0.5
                color: Kirigami.Theme.backgroundColor.hslLightness < 0.5
                    ? Qt.rgba(1.0, 1.0, 1.0, 0.22)
                    : Qt.rgba(0.0, 0.0, 0.0, 0.12)
            }
            GradientStop { position: 1.0; color: "transparent" }
        }

        Behavior on opacity {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }
    }

    Rectangle {
        id: runningDot
        visible: task.isRunning && !task.inPopup
        width: task.isTaskActive ? 5 : 4
        height: task.isTaskActive ? 5 : 4
        radius: width / 2
        readonly property bool isDarkTheme: Kirigami.Theme.backgroundColor.hslLightness < 0.5
        color: {
            if (isDarkTheme) {
                return task.isTaskActive ? Qt.rgba(1.0, 1.0, 1.0, 1.0) : Qt.rgba(1.0, 1.0, 1.0, 0.50);
            } else {
                return task.isTaskActive ? Qt.rgba(0.08, 0.08, 0.08, 0.95) : Qt.rgba(0.18, 0.18, 0.18, 0.45);
            }
        }

        Behavior on width {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
        Behavior on color {
            ColorAnimation { duration: 200 }
        }

        // Soft bloom/glow halo for active frontmost app
        Rectangle {
            id: dotGlow
            visible: task.isTaskActive
            anchors.centerIn: parent
            width: parent.width + 5
            height: parent.height + 5
            radius: width / 2
            color: runningDot.isDarkTheme ? Qt.rgba(1.0, 1.0, 1.0, 0.35) : Qt.rgba(0.0, 0.0, 0.0, 0.18)
            z: -1
            opacity: task.isTaskActive ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation { duration: 200 }
            }
        }

        readonly property real padOffset: {
            const pad = tasksRoot ? (tasksRoot.vertical ? tasksRoot.horizontalPadding : tasksRoot.verticalPadding) : 6;
            return Math.max(1, Math.round((pad - height) / 2));
        }

        anchors {
            horizontalCenter: tasksRoot.vertical ? undefined : parent.horizontalCenter
            horizontalCenterOffset: (!tasksRoot.vertical && isDividerTask) ? Math.round(dividerOffset / 2) : 0
            verticalCenter: tasksRoot.vertical ? parent.verticalCenter : undefined
            verticalCenterOffset: (tasksRoot.vertical && isDividerTask) ? Math.round(dividerOffset / 2) : 0

            // Bottom panel: placed below the icon in the bottom padding
            top: (!tasksRoot.vertical && tasksRoot.effectiveLocation !== PlasmaCore.Types.TopEdge) ? parent.bottom : undefined
            topMargin: (!tasksRoot.vertical && tasksRoot.effectiveLocation !== PlasmaCore.Types.TopEdge) ? padOffset : 0

            // Top panel: placed above the icon in the top padding
            bottom: (!tasksRoot.vertical && tasksRoot.effectiveLocation === PlasmaCore.Types.TopEdge) ? parent.top : undefined
            bottomMargin: (!tasksRoot.vertical && tasksRoot.effectiveLocation === PlasmaCore.Types.TopEdge) ? padOffset : 0

            // Left panel: placed to the left of the icon in the left padding
            right: (tasksRoot.vertical && tasksRoot.effectiveLocation === PlasmaCore.Types.LeftEdge) ? parent.left : undefined
            rightMargin: (tasksRoot.vertical && tasksRoot.effectiveLocation === PlasmaCore.Types.LeftEdge) ? padOffset : 0

            // Right panel: placed to the right of the icon in the right padding
            left: (tasksRoot.vertical && tasksRoot.effectiveLocation === PlasmaCore.Types.RightEdge) ? parent.right : undefined
            leftMargin: (tasksRoot.vertical && tasksRoot.effectiveLocation === PlasmaCore.Types.RightEdge) ? padOffset : 0
        }
    }

    Rectangle {
        id: dockDivider
        visible: isDividerTask
        z: -1

        width: tasksRoot.vertical ? Math.round(tasksRoot.iconSize * 0.55) : 1
        height: !tasksRoot.vertical ? Math.round(tasksRoot.iconSize * 0.55) : 1
        radius: 0.5
        color: Kirigami.Theme.backgroundColor.hslLightness < 0.5 ? Qt.rgba(1.0, 1.0, 1.0, 0.28) : Qt.rgba(0.0, 0.0, 0.0, 0.22)

        anchors {
            // Horizontal dock: center vertically in capsule, position at left + dividerSpan/2
            verticalCenter: !tasksRoot.vertical ? parent.verticalCenter : undefined
            left: !tasksRoot.vertical ? parent.left : undefined
            leftMargin: !tasksRoot.vertical ? Math.round(tasksRoot.dividerSpan / 2) : 0

            // Vertical dock: center horizontally in capsule, position at top + dividerSpan/2
            horizontalCenter: tasksRoot.vertical ? parent.horizontalCenter : undefined
            top: tasksRoot.vertical ? parent.top : undefined
            topMargin: tasksRoot.vertical ? Math.round(tasksRoot.dividerSpan / 2) : 0
        }
    }

    PlasmaComponents3.Label {
        id: label

        visible: (task.inPopup || !task.tasksRoot.iconsOnly && !task.model.IsLauncher
            && (parent.width - iconBox.height - Kirigami.Units.smallSpacing) >= LayoutMetrics.spaceRequiredToShowText())

        anchors {
            fill: parent
            leftMargin: taskFrame.margins.left + iconBox.width + LayoutMetrics.labelMargin
            topMargin: taskFrame.margins.top
            rightMargin: taskFrame.margins.right + (task.audioStreamIcon !== null && task.audioStreamIcon.visible ? (task.audioStreamIcon.width + LayoutMetrics.labelMargin) : 0)
            bottomMargin: taskFrame.margins.bottom
        }

        wrapMode: (maximumLineCount === 1) ? Text.NoWrap : Text.Wrap
        elide: Text.ElideRight
        textFormat: Text.PlainText
        verticalAlignment: Text.AlignVCenter
        maximumLineCount: Plasmoid.configuration.maxTextLines || undefined

        // The accessible item of this element is only used for debugging
        // purposes, and it will never gain focus (thus it won't interfere
        // with screenreaders).
        Accessible.ignored: !visible
        Accessible.name: parent.Accessible.name + "-labelhint"

        // use State to avoid unnecessary re-evaluation when the label is invisible
        states: State {
            name: "labelVisible"
            when: label.visible

            PropertyChanges {
                label.text: task.model.display
            }
        }
    }

    states: [
        State {
            name: "launcher"
            when: task.model.IsLauncher

            PropertyChanges {
                frame.basePrefix: ""
            }
        },
        State {
            name: "attention"
            when: task.demandsAttention

            PropertyChanges {
                frame.basePrefix: "attention"
            }
        },
        State {
            name: "minimized"
            when: task.model.IsMinimized

            PropertyChanges {
                frame.basePrefix: "minimized"
            }
        },
        State {
            name: "active"
            when: task.isTaskActive

            PropertyChanges {
                frame.basePrefix: "focus"
            }
        }
    ]

    Component.onCompleted: {
        if (!inPopup && model.IsWindow) {
            updateAudioStreams({delay: false});
        }

        if (!inPopup && !model.IsWindow) {
            taskInitComponent.createObject(task);
        }
        updateAttention();
        completed = true;
    }
    Component.onDestruction: {
        if (moveAnim.running) {
            (task.parent as TaskList).animationsRunning -= 1;
        }
    }
}
