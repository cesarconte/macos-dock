/*
    SPDX-FileCopyrightText: 2012-2016 Eike Hein <hein@kde.org>
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.plasmoid

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras

import org.kde.taskmanager as TaskManager
import org.kde.plasma.private.mpris as Mpris
import org.cesar.dock 1.0
import "code/LayoutMetrics.js" as LayoutMetrics

PlasmaExtras.Menu {
    id: menu

    required property var backend
    required property Mpris.Mpris2Model mpris2Source
    required property /*QModelIndex*/var modelIndex

    readonly property bool isDolphin: {
        const appId = String(visualParent ? visualParent.appId : "").toLowerCase();
        const lUrl = String(get(TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon) || "").toLowerCase();
        return appId.includes("dolphin") || lUrl.includes("dolphin");
    }

    readonly property var atm: TaskManager.AbstractTasksModel

    property bool showAllPlaces: false

    placement: {
        const loc = (visualParent && visualParent.tasksRoot) ? visualParent.tasksRoot.effectiveLocation : Plasmoid.location;
        if (loc === PlasmaCore.Types.LeftEdge) {
            return PlasmaExtras.Menu.RightPosedTopAlignedPopup;
        } else if (loc === PlasmaCore.Types.TopEdge) {
            return PlasmaExtras.Menu.BottomPosedLeftAlignedPopup;
        } else if (loc === PlasmaCore.Types.RightEdge) {
            return PlasmaExtras.Menu.LeftPosedTopAlignedPopup;
        } else {
            return PlasmaExtras.Menu.TopPosedLeftAlignedPopup;
        }
    }

    minimumWidth: (visualParent as Item).width

    onStatusChanged: {
        if (visualParent && get(TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon).toString() !== "" && status === PlasmaExtras.Menu.Open) {
            activitiesDesktopsMenu.refresh();

        } else if (status === PlasmaExtras.Menu.Closed) {
            menu.destroy();
        }
    }

    Component.onCompleted: {
        // Cannot have "Connections" as child of PlasmaExtras.Menu.
        if (backend && backend.showAllPlaces) {
            backend.showAllPlaces.connect(showContextMenuWithAllPlaces);
        }
    }

    Component.onDestruction: {
        if (backend && backend.showAllPlaces) {
            backend.showAllPlaces.disconnect(showContextMenuWithAllPlaces);
        }
    }

    function showContextMenuWithAllPlaces(): void {
        (visualParent as Task).showContextMenu({showAllPlaces: true});
    }

    function get(modelProp: int): var {
        return tasksModel.data(modelIndex, modelProp)
    }

    function show(): void {
        Plasmoid.contextualActionsAboutToShow();

        loadDynamicLaunchActions(get(TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon));
        openRelative();
    }

    function newMenuItem(parent: QtObject): PlasmaExtras.MenuItem {
        return Qt.createQmlObject(`
            import org.kde.plasma.extras as PlasmaExtras

            PlasmaExtras.MenuItem {}
        `, parent) as PlasmaExtras.MenuItem;
    }

    function newSeparator(parent: QtObject): PlasmaExtras.MenuItem {
        return Qt.createQmlObject(`
            import org.kde.plasma.extras as PlasmaExtras

            PlasmaExtras.MenuItem { separator: true }
            `, parent) as PlasmaExtras.MenuItem;
    }

    function loadDynamicLaunchActions(launcherUrl: url): void {
        if (isDolphin) {
            // 1. Ventanas abiertas de Finder / Dolphin (si existen)
            let hasWindows = false;
            if (visualParent && visualParent.childCount > 0) {
                for (let i = 0; i < visualParent.childCount; ++i) {
                    const childIdx = tasksModel.makeModelIndex(visualParent.index, i);
                    const winTitle = tasksModel.data(childIdx, TaskManager.AbstractTasksModel.display);
                    const isActive = tasksModel.data(childIdx, TaskManager.AbstractTasksModel.IsActive);
                    let winItem = newMenuItem(menu);
                    winItem.text = winTitle;
                    winItem.icon = "window";
                    if (isActive) {
                        winItem.checkable = true;
                        winItem.checked = true;
                    }
                    winItem.clicked.connect(() => {
                        tasksModel.requestActivate(childIdx);
                    });
                    menu.addMenuItem(winItem, startNewInstanceItem);
                    hasWindows = true;
                }
            } else if (visualParent && menu.get(TaskManager.AbstractTasksModel.IsWindow)) {
                let winItem = newMenuItem(menu);
                winItem.text = menu.get(TaskManager.AbstractTasksModel.display);
                winItem.icon = "window";
                winItem.checkable = true;
                winItem.checked = menu.get(TaskManager.AbstractTasksModel.IsActive);
                winItem.clicked.connect(() => {
                    tasksModel.requestActivate(menu.modelIndex);
                });
                menu.addMenuItem(winItem, startNewInstanceItem);
                hasWindows = true;
            }

            if (hasWindows) {
                menu.addMenuItem(newSeparator(menu), startNewInstanceItem);
            }

            // 2. Nueva ventana del Finder
            let newWinItem = newMenuItem(menu);
            newWinItem.text = i18n("Nueva ventana del Finder");
            newWinItem.icon = "window-new";
            newWinItem.clicked.connect(() => {
                DockBackend.openNewDolphinWindow("");
            });
            menu.addMenuItem(newWinItem, startNewInstanceItem);
            menu.addMenuItem(newSeparator(menu), startNewInstanceItem);

            // 3. Ubicaciones
            let placesHeader = newMenuItem(menu);
            placesHeader.text = i18n("Ubicaciones");
            placesHeader.section = true;
            menu.addMenuItem(placesHeader, startNewInstanceItem);

            const places = DockBackend.finderPlaces();
            for (let i = 0; i < places.length; ++i) {
                const place = places[i];
                let placeItem = newMenuItem(menu);
                placeItem.text = place.title;
                placeItem.icon = place.icon;
                const placePath = place.path;
                placeItem.clicked.connect(() => {
                    DockBackend.openFolder(placePath);
                });
                menu.addMenuItem(placeItem, startNewInstanceItem);
            }
            menu.addMenuItem(newSeparator(menu), startNewInstanceItem);

            // 4. Forzar reinicio de Dolphin (Relaunch)
            let relaunchItem = newMenuItem(menu);
            relaunchItem.text = i18n("Forzar reinicio");
            relaunchItem.icon = "view-refresh";
            relaunchItem.clicked.connect(() => {
                DockBackend.relaunchDolphin();
            });
            menu.addMenuItem(relaunchItem, startNewInstanceItem);
            menu.addMenuItem(newSeparator(menu), startNewInstanceItem);

            return;
        }

        // Acciones dinámicas de Jump List para otras aplicaciones
        const launcherUrlStr = String(launcherUrl || "");
        const actions = DockBackend.jumpListActions(launcherUrlStr);
        if (actions.length > 0) {
            let actHeader = newMenuItem(menu);
            actHeader.text = i18n("Acciones");
            actHeader.section = true;
            menu.addMenuItem(actHeader, startNewInstanceItem);

            for (let i = 0; i < actions.length; ++i) {
                const act = actions[i];
                let actItem = newMenuItem(menu);
                actItem.text = act.text;
                actItem.icon = act.icon || "system-run";
                const actionName = act.name;
                actItem.clicked.connect(() => {
                    DockBackend.executeServiceAction(launcherUrlStr, actionName);
                });
                menu.addMenuItem(actItem, startNewInstanceItem);
            }
            menu.addMenuItem(newSeparator(menu), startNewInstanceItem);
        }

        let sections = [];

        const placesActions = backend.placesActions(launcherUrl, showAllPlaces, menu);

        if (placesActions.length > 0) {
            sections.push({
                title: i18nc("@title:group for section of menu items", "Places"),
                group: "places",
                actions: placesActions
            });
        } else {
            sections.push({
                title:  i18nc("@title:group for section of menu items", "Recent Files"),
                group:   "recents",
                actions: backend.recentDocumentActions(launcherUrl, menu)
            });
        }

        // We always have actions category.
        sections = sections.filter(section => section.actions.length > 0);

        sections.push({
            title: i18nc("@title:group for section of menu items", "Actions"),
            group: "actions",
            actions: backend.jumpListActions(launcherUrl, menu)
        });

        // C++ can override section heading by returning a QString as first action
        sections.forEach((section) => {
            if (typeof section.actions[0] === "string") {
                section.title = section.actions.shift(); // take first
            }
        });

        // QMenu does not limit its width automatically. Even if we set a maximumWidth
        // it would just cut off text rather than eliding. So we do this manually.
        const textMetrics = Qt.createQmlObject("import QtQuick; TextMetrics {}", menu);
        textMetrics.elide = Qt.ElideRight;
        textMetrics.elideWidth = LayoutMetrics.maximumContextMenuTextWidth();

        sections.forEach(section => {
            if (section["actions"].length > 0 || section["group"] === "actions") {
                // Don't add the "Actions" header if the menu has nothing but actions
                // in it, because then it's redundant (all menus have actions)
                if (section.group !== "actions" || sections.length > 1) {
                    var sectionHeader = newMenuItem(menu);
                    sectionHeader.text = section["title"];
                    sectionHeader.section = true;
                    menu.addMenuItem(sectionHeader, startNewInstanceItem);
                }
            }

            for (var i = 0; i < section["actions"].length; ++i) {
                var item = newMenuItem(menu);
                item.action = section["actions"][i];

                textMetrics.text = item.action.text.replace("&", "&&");
                item.action.text = textMetrics.elidedText;

                menu.addMenuItem(item, startNewInstanceItem);
            }
        });

        // Add Media Player control actions
        const playerData = mpris2Source.playerForLauncherUrl(launcherUrl, get(TaskManager.AbstractTasksModel.AppPid));

        if (playerData && playerData.canControl && !(get(TaskManager.AbstractTasksModel.WinIdList) !== undefined && get(TaskManager.AbstractTasksModel.WinIdList).length > 1)) {
            const playing = playerData.playbackStatus === Mpris.PlaybackStatus.Playing;
            let menuItem = menu.newMenuItem(menu);
            menuItem.text = i18nc("Play previous track", "Previous Track");
            menuItem.icon = "media-skip-backward";
            menuItem.enabled = Qt.binding(() => {
                return playerData.canGoPrevious;
            });
            menuItem.clicked.connect(() => {
                playerData.Previous();
            });
            menu.addMenuItem(menuItem, startNewInstanceItem);

            menuItem = menu.newMenuItem(menu);
            // PlasmaCore Menu doesn't actually handle icons or labels changing at runtime...
            menuItem.text = Qt.binding(() => {
                // if CanPause, toggle the menu entry between Play & Pause, otherwise always use Play
                return playing && playerData.canPause ? i18nc("Pause playback", "Pause") : i18nc("Start playback", "Play");
            });
            menuItem.icon = Qt.binding(() => {
                return playing && playerData.canPause ? "media-playback-pause" : "media-playback-start";
            });
            menuItem.enabled = Qt.binding(() => {
                return playing ? playerData.canPause : playerData.canPlay;
            });
            menuItem.clicked.connect(() => {
                if (playing) {
                    playerData.Pause();
                } else {
                    playerData.Play();
                }
            });
            menu.addMenuItem(menuItem, startNewInstanceItem);

            menuItem = menu.newMenuItem(menu);
            menuItem.text = i18nc("Play next track", "Next Track");
            menuItem.icon = "media-skip-forward";
            menuItem.enabled = Qt.binding(() => {
                return playerData.canGoNext;
            });
            menuItem.clicked.connect(() => {
                playerData.Next();
            });
            menu.addMenuItem(menuItem, startNewInstanceItem);

            menuItem = menu.newMenuItem(menu);
            menuItem.text = i18nc("Stop playback", "Stop");
            menuItem.icon = "media-playback-stop";
            menuItem.enabled = Qt.binding(() => {
                return playerData.canStop;
            });
            menuItem.clicked.connect(() => {
                playerData.Stop();
            });
            menu.addMenuItem(menuItem, startNewInstanceItem);

            // Technically media controls and audio streams are separate but for the user they're
            // semantically related, don't add a separator in between.
            if (!(menu.visualParent as Task).hasAudioStream) {
                menu.addMenuItem(newSeparator(menu), startNewInstanceItem);
            }

            // If we don't have a window associated with the player but we can quit
            // it through MPRIS we'll offer a "Quit" option instead of "Close"
            if (!closeWindowItem.visible && playerData.canQuit) {
                menuItem = menu.newMenuItem(menu);
                menuItem.text = i18nc("Quit media player app", "Quit");
                menuItem.icon = "application-exit";
                menuItem.visible = Qt.binding(() => {
                    return !closeWindowItem.visible;
                });
                menuItem.clicked.connect(() => {
                    playerData.Quit();
                });
                menu.addMenuItem(menuItem);
            }

            // If we don't have a window associated with the player but we can raise
            // it through MPRIS we'll offer a "Restore" option
            if (get(TaskManager.AbstractTasksModel.IsLauncher) && !startNewInstanceItem.visible && playerData.canRaise) {
                menuItem = menu.newMenuItem(menu);
                menuItem.text = i18nc("Open or bring to the front window of media player app", "Restore");
                menuItem.icon = playerData.iconName;
                menuItem.visible = Qt.binding(() => {
                    return !startNewInstanceItem.visible;
                });
                menuItem.clicked.connect(() => {
                    playerData.Raise();
                });
                menu.addMenuItem(menuItem, startNewInstanceItem);
            }
        }

        // We allow mute/unmute whenever an application has a stream, regardless of whether it
        // is actually playing sound.
        // This way you can unmute, e.g. a telephony app, even after the conversation has ended,
        // so you still have it ringing later on.
        if ((menu.visualParent as Task).hasAudioStream) {
            const muteItem = menu.newMenuItem(menu);
            muteItem.checkable = true;
            muteItem.checked = Qt.binding(() => {
                return menu.visualParent && menu.visualParent.muted;
            });
            muteItem.clicked.connect(() => {
                menu.visualParent.toggleMuted();
            });
            muteItem.text = i18nc("@option:check inmenu, no separate unmute action", "Mute");
            muteItem.icon = "audio-volume-muted" + (Application.layoutDirection === Qt.RightToLeft ? "-rtl" : "");
            menu.addMenuItem(muteItem, startNewInstanceItem);

            menu.addMenuItem(newSeparator(menu), startNewInstanceItem);
        }
    }

    PlasmaExtras.MenuItem {
        id: startNewInstanceItem
        visible: !isDolphin && menu.get(TaskManager.AbstractTasksModel.CanLaunchNewInstance)
        text: i18n("Abrir nueva ventana")
        icon: "window-new"

        onClicked: tasksModel.requestNewInstance(menu.modelIndex)
    }

    PlasmaExtras.MenuItem {
        id: virtualDesktopsMenuItem

        visible: virtualDesktopInfo.numberOfDesktops > 1
            && (menu.visualParent && !menu.get(TaskManager.AbstractTasksModel.IsLauncher)
            && !menu.get(TaskManager.AbstractTasksModel.IsStartup)
            && menu.get(TaskManager.AbstractTasksModel.IsVirtualDesktopsChangeable))

        enabled: visible

        text: i18nc("action:inmenu", "Move to &Desktop")
        icon: "virtual-desktops"

        readonly property Connections virtualDesktopsMenuConnections: Connections {
            target: virtualDesktopInfo

            function onNumberOfDesktopsChanged(): void {
                Qt.callLater(virtualDesktopsMenu.refresh);
            }
            function onDesktopIdsChanged(): void {
                Qt.callLater(virtualDesktopsMenu.refresh);
            }
            function onDesktopNamesChanged(): void {
                Qt.callLater(virtualDesktopsMenu.refresh);
            }
        }

        readonly property PlasmaExtras.Menu _virtualDesktopsMenu: PlasmaExtras.Menu {
            id: virtualDesktopsMenu

            visualParent: virtualDesktopsMenuItem.action

            function refresh(): void {
                clearMenuItems();

                if (virtualDesktopInfo.numberOfDesktops <= 1 || !virtualDesktopsMenuItem.enabled) {
                    return;
                }

                let menuItem = menu.newMenuItem(virtualDesktopsMenu);
                menuItem.text = i18nc("action:inmenu", "Move &To Current Desktop");
                menuItem.enabled = Qt.binding(() => {
                    return menu.visualParent && menu.get(TaskManager.AbstractTasksModel.VirtualDesktops).indexOf(virtualDesktopInfo.currentDesktop) === -1;
                });
                menuItem.clicked.connect(() => {
                    tasksModel.requestVirtualDesktops(menu.modelIndex, [virtualDesktopInfo.currentDesktop]);
                });

                menuItem = menu.newMenuItem(virtualDesktopsMenu);
                menuItem.text = i18nc("action:inmenu", "&All Desktops");
                menuItem.checkable = true;
                menuItem.checked = Qt.binding(() => {
                    return menu.visualParent && menu.get(TaskManager.AbstractTasksModel.IsOnAllVirtualDesktops);
                });
                menuItem.clicked.connect(() => {
                    tasksModel.requestVirtualDesktops(menu.modelIndex, []);
                });
                menu.backend.setActionGroup(menuItem.action);

                menu.newSeparator(virtualDesktopsMenu);

                for (let i = 0; i < virtualDesktopInfo.desktopNames.length; ++i) {
                    menuItem = menu.newMenuItem(virtualDesktopsMenu);
                    menuItem.text = virtualDesktopInfo.desktopNames[i];
                    menuItem.checkable = true;
                    menuItem.checked = Qt.binding((i => {
                        return () => menu.visualParent && menu.get(TaskManager.AbstractTasksModel.VirtualDesktops).indexOf(virtualDesktopInfo.desktopIds[i]) > -1;
                    })(i));
                    menuItem.clicked.connect((i => {
                        return () => tasksModel.requestVirtualDesktops(menu.modelIndex, [virtualDesktopInfo.desktopIds[i]]);
                    })(i));
                    menu.backend.setActionGroup(menuItem.action);
                }

                menu.newSeparator(virtualDesktopsMenu);

                menuItem = menu.newMenuItem(virtualDesktopsMenu);
                menuItem.text = i18nc("action:inmenu", "&New Desktop");
                menuItem.icon = "list-add";
                menuItem.clicked.connect(() => {
                    tasksModel.requestNewVirtualDesktop(menu.modelIndex);
                });
            }

            Component.onCompleted: refresh()
        }
    }

     PlasmaExtras.MenuItem {
        id: activitiesDesktopsMenuItem

        visible: activityInfo.numberOfRunningActivities > 1
            && (menu.visualParent && !menu.get(TaskManager.AbstractTasksModel.IsLauncher)
            && !menu.get(TaskManager.AbstractTasksModel.IsStartup))

        enabled: visible

        text: i18nc("action:inmenu", "Show in &Activities")
        icon: "activities"

        readonly property Connections activityInfoConnections: Connections {
            target: activityInfo

            function onNumberOfRunningActivitiesChanged(): void {
                activitiesDesktopsMenu.refresh()
            }
        }

        readonly property PlasmaExtras.Menu _activitiesDesktopsMenu: PlasmaExtras.Menu {
            id: activitiesDesktopsMenu

            visualParent: activitiesDesktopsMenuItem.action

            function refresh(): void {
                clearMenuItems();

                if (activityInfo.numberOfRunningActivities <= 1) {
                    return;
                }

                let menuItem = menu.newMenuItem(activitiesDesktopsMenu);
                menuItem.text = i18nc("action:inmenu", "Add To Current Activity");
                menuItem.enabled = Qt.binding(() => {
                    return menu.visualParent && menu.get(TaskManager.AbstractTasksModel.Activities).length > 0 &&
                           menu.get(TaskManager.AbstractTasksModel.Activities).indexOf(activityInfo.currentActivity) < 0;
                });
                menuItem.clicked.connect(() => {
                    tasksModel.requestActivities(menu.modelIndex, menu.get(TaskManager.AbstractTasksModel.Activities).concat(activityInfo.currentActivity));
                });

                menuItem = menu.newMenuItem(activitiesDesktopsMenu);
                menuItem.text = i18nc("action:inmenu", "All Activities");
                menuItem.checkable = true;
                menuItem.checked = Qt.binding(() => {
                    return menu.visualParent && menu.get(TaskManager.AbstractTasksModel.Activities).length === 0;
                });
                menuItem.toggled.connect(checked => {
                    let newActivities = []; // will cast to an empty QStringList i.e all activities
                    if (!checked) {
                        newActivities = [activityInfo.currentActivity];
                    }
                    tasksModel.requestActivities(menu.modelIndex, newActivities);
                });

                menu.newSeparator(activitiesDesktopsMenu);

                const runningActivities = activityInfo.runningActivities();
                for (let i = 0; i < runningActivities.length; ++i) {
                    const activityId = runningActivities[i];

                    menuItem = menu.newMenuItem(activitiesDesktopsMenu);
                    menuItem.text = activityInfo.activityName(runningActivities[i]);
                    menuItem.icon = activityInfo.activityIcon(runningActivities[i]);
                    menuItem.checkable = true;
                    menuItem.checked = Qt.binding((activityId => {
                        return () => menu.visualParent && menu.get(TaskManager.AbstractTasksModel.Activities).indexOf(activityId) >= 0;
                    })(activityId));
                    menuItem.toggled.connect((activityId => {
                        return checked => {
                            let newActivities = menu.get(TaskManager.AbstractTasksModel.Activities);
                            if (checked) {
                                newActivities = newActivities.concat(activityId);
                            } else {
                                const index = newActivities.indexOf(activityId);
                                if (index < 0) {
                                    return;
                                }

                                newActivities.splice(index, 1);
                            }
                            return tasksModel.requestActivities(menu.modelIndex, newActivities);
                        };
                    })(activityId));
                }

                menu.newSeparator(activitiesDesktopsMenu);

                for (let i = 0; i < runningActivities.length; ++i) {
                    const activityId = runningActivities[i];
                    const onActivities = menu.get(TaskManager.AbstractTasksModel.Activities);

                    // if the task is on a single activity, don't insert a "move to" item for that activity
                    if (onActivities.length === 1 && onActivities[0] === activityId) {
                        continue;
                    }

                    menuItem = menu.newMenuItem(activitiesDesktopsMenu);
                    menuItem.text = i18nc("action:inmenu", "Move to %1", activityInfo.activityName(activityId))
                    menuItem.icon = activityInfo.activityIcon(activityId)
                    menuItem.clicked.connect((activityId => {
                        return () => tasksModel.requestActivities(menu.modelIndex, [activityId]);
                    })(activityId));
                }

                menu.newSeparator(activitiesDesktopsMenu);
            }

            Component.onCompleted: refresh()
        }
    }

    PlasmaExtras.MenuItem {
        id: launcherToggleAction

        visible: menu.visualParent
            && !menu.get(TaskManager.AbstractTasksModel.IsLauncher)
            && !menu.get(TaskManager.AbstractTasksModel.IsStartup)
            && Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable
            && (activityInfo.numberOfRunningActivities < 2)
            && !doesBelongToCurrentActivity()

        enabled: menu.visualParent && menu.get(TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon).toString() !== ""

        text: i18n("Fijar en el Dock")
        icon: "window-pin"

        function doesBelongToCurrentActivity(): bool {
            return tasksModel.launcherActivities(menu.get(TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon))
                .some(activity => activity === activityInfo.currentActivity || activity === activityInfo.nullUuid);
        }

        onClicked: {
            tasksModel.requestAddLauncher(menu.get(TaskManager.AbstractTasksModel.LauncherUrl));
        }
    }

    PlasmaExtras.MenuItem {
        id: showLauncherInActivitiesItem

        text: i18n("Fijar en el Dock")
        icon: "window-pin"

        visible: menu.visualParent
            && !menu.get(TaskManager.AbstractTasksModel.IsStartup)
            && Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable
            && (activityInfo.numberOfRunningActivities >= 2)

        readonly property Connections activitiesLaunchersMenuConnections: Connections {
            target: activityInfo

            function onNumberOfRunningActivitiesChanged(): void {
                activitiesDesktopsMenu.refresh()
            }
        }

        readonly property PlasmaExtras.Menu _activitiesLaunchersMenu: PlasmaExtras.Menu {
            id: activitiesLaunchersMenu
            visualParent: showLauncherInActivitiesItem.action

            function refresh(): void {
                clearMenuItems();

                if (menu.visualParent === null) return;

                const createNewItem = (id, title, iconName, url, activities) => {
                    var result = menu.newMenuItem(activitiesLaunchersMenu);
                    result.text = title;
                    result.icon = iconName;

                    result.visible = true;
                    result.checkable = true;

                    result.checked = activities.some(activity => activity === id);

                    result.clicked.connect(() => {
                        if (result.checked) {
                            tasksModel.requestAddLauncherToActivity(url, id);
                        } else {
                            tasksModel.requestRemoveLauncherFromActivity(url, id);
                        }
                    });

                    return result;
                };

                if (menu.visualParent === null) return;

                const url = menu.get(TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon);

                const activities = tasksModel.launcherActivities(url);

                createNewItem(activityInfo.nullUuid, i18nc("action:inmenu", "On All Activities"), "", url, activities);

                if (activityInfo.numberOfRunningActivities <= 1) {
                    return;
                }

                createNewItem(activityInfo.currentActivity, i18nc("action:inmenu", "On The Current Activity"), activityInfo.activityIcon(activityInfo.currentActivity), url, activities);

                menu.newSeparator(activitiesLaunchersMenu);

                activityInfo.runningActivities()
                    .forEach(id => {
                        createNewItem(id, activityInfo.activityName(id), activityInfo.activityIcon(id), url, activities);
                    });
            }

            Component.onCompleted: {
                menu.visualParentChanged.connect(refresh);
                refresh();
            }
        }
    }

    PlasmaExtras.MenuItem {
        visible: (menu.visualParent
                && menu.get(TaskManager.AbstractTasksModel.IsStartup) !== true
                && Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable
                && !launcherToggleAction.visible
                && activityInfo.numberOfRunningActivities < 2)

        text: i18n("Desanclar del Dock")
        icon: "window-unpin"

        onClicked: {
            tasksModel.requestRemoveLauncher(menu.get(TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon));
        }
    }

    PlasmaExtras.MenuItem {
        id: moreActionsMenuItem

        visible: (menu.visualParent && !menu.get(TaskManager.AbstractTasksModel.IsLauncher) && !menu.get(TaskManager.AbstractTasksModel.IsStartup))

        enabled: visible

        text: i18nc("item:inmenu opens submenu", "More")
        icon: "view-more-symbolic"

        readonly property PlasmaExtras.Menu moreMenu: PlasmaExtras.Menu {
            visualParent: moreActionsMenuItem.action

            PlasmaExtras.MenuItem {
                enabled: menu.visualParent && menu.get(TaskManager.AbstractTasksModel.IsMovable)

                text: i18nc("action:inmenu", "&Move")
                icon: "transform-move"

                onClicked: tasksModel.requestMove(menu.modelIndex)
            }

            PlasmaExtras.MenuItem {
                enabled: menu.visualParent && menu.get(TaskManager.AbstractTasksModel.IsResizable)

                text: i18nc("action:inmenu", "Re&size")
                icon: "transform-scale"

                onClicked: tasksModel.requestResize(menu.modelIndex)
            }

            PlasmaExtras.MenuItem {
                visible: (menu.visualParent && !menu.get(TaskManager.AbstractTasksModel.IsLauncher) && !menu.get(TaskManager.AbstractTasksModel.IsStartup))

                enabled: menu.visualParent && menu.get(TaskManager.AbstractTasksModel.IsMaximizable)

                checkable: true
                checked: menu.visualParent && menu.get(TaskManager.AbstractTasksModel.IsMaximized)

                text: i18nc("action:inmenu", "Ma&ximize")
                icon: "window-maximize"

                onClicked: tasksModel.requestToggleMaximized(menu.modelIndex)
            }

            PlasmaExtras.MenuItem {
                visible: (menu.visualParent && !menu.get(TaskManager.AbstractTasksModel.IsLauncher) && !menu.get(TaskManager.AbstractTasksModel.IsStartup))

                enabled: menu.visualParent && menu.get(TaskManager.AbstractTasksModel.IsMinimizable)

                checkable: true
                checked: menu.visualParent && menu.get(TaskManager.AbstractTasksModel.IsMinimized)

                text: i18nc("action:inmenu", "Mi&nimize")
                icon: "window-minimize"

                onClicked: tasksModel.requestToggleMinimized(menu.modelIndex)
            }

            PlasmaExtras.MenuItem {
                checkable: true
                checked: menu.visualParent && menu.get(TaskManager.AbstractTasksModel.IsKeepAbove)

                text: i18nc("action:inmenu", "Keep &Above Others")
                icon: "window-keep-above"

                onClicked: tasksModel.requestToggleKeepAbove(menu.modelIndex)
            }

            PlasmaExtras.MenuItem {
                checkable: true
                checked: menu.visualParent && menu.get(TaskManager.AbstractTasksModel.IsKeepBelow)

                text: i18nc("action:inmenu", "Keep &Below Others")
                icon: "window-keep-below"

                onClicked: tasksModel.requestToggleKeepBelow(menu.modelIndex)
            }

            PlasmaExtras.MenuItem {
                enabled: menu.visualParent && menu.get(TaskManager.AbstractTasksModel.IsFullScreenable)

                checkable: true
                checked: menu.visualParent && menu.get(TaskManager.AbstractTasksModel.IsFullScreen)

                text: i18nc("action:inmenu", "&Fullscreen")
                icon: "view-fullscreen"

                onClicked: tasksModel.requestToggleFullScreen(menu.modelIndex)
            }

            PlasmaExtras.MenuItem {
                enabled: menu.visualParent && menu.get(TaskManager.AbstractTasksModel.IsShadeable)

                checkable: true
                checked: menu.visualParent && menu.get(TaskManager.AbstractTasksModel.IsShaded)
                visible: Qt.platform.pluginName !== "wayland"

                text: i18nc("action:inmenu", "&Shade")
                icon: "window-shade"

                onClicked: tasksModel.requestToggleShaded(menu.modelIndex)
            }

            PlasmaExtras.MenuItem {
                enabled: menu.visualParent && menu.get(TaskManager.AbstractTasksModel.CanSetNoBoder)

                checkable: true
                checked: menu.visualParent && menu.get(TaskManager.AbstractTasksModel.HasNoBorder)

                text: i18nc("@action:inmenu", "&No Titlebar and Frame")
                icon: "edit-none-border"

                onClicked: tasksModel.requestToggleNoBorder(menu.modelIndex)
            }

            PlasmaExtras.MenuItem {
                enabled: menu.visualParent

                checkable: true
                checked: menu.visualParent && menu.get(TaskManager.AbstractTasksModel.IsExcludedFromCapture)
                visible: Qt.platform.pluginName === "wayland"

                text: i18nc("@action:inmenu", "&Hide from Screencast")
                icon: "view-private"

                onClicked: tasksModel.requestToggleExcludeFromCapture(menu.modelIndex)
            }

            PlasmaExtras.MenuItem {
                separator: true
            }

            PlasmaExtras.MenuItem {
                visible: (Plasmoid.configuration.groupingStrategy !== 0) && menu.get(TaskManager.AbstractTasksModel.IsWindow)

                checkable: true
                checked: menu.visualParent && menu.get(TaskManager.AbstractTasksModel.IsGroupable)

                text: i18nc("@option:check inmenu", "Allow this program to be grouped")
                icon: "view-group"

                onClicked: tasksModel.requestToggleGrouping(menu.modelIndex)
            }
        }
    }

    PlasmaExtras.MenuItem { separator: true }

    PlasmaExtras.MenuItem {
        property PlasmaCore.Action configureAction: null

        enabled: configureAction && configureAction.enabled
        visible: configureAction && configureAction.visible

        text: configureAction ? configureAction.text : ""
        icon: configureAction ? configureAction.icon : ""

        onClicked: configureAction.trigger()

        Component.onCompleted: configureAction = Plasmoid.internalAction("configure")
    }

    PlasmaExtras.MenuItem { separator: true }

    PlasmaExtras.MenuItem {
        id: closeWindowItem
        visible: !isDolphin && (menu.visualParent && !menu.get(TaskManager.AbstractTasksModel.IsLauncher) && !menu.get(TaskManager.AbstractTasksModel.IsStartup))

        enabled: menu.visualParent && menu.get(TaskManager.AbstractTasksModel.IsClosable)

        text: menu.get(TaskManager.AbstractTasksModel.IsGroupParent) ? i18nc("@action:inmenu", "&Close All") : i18nc("@action:inmenu", "&Close")
        icon: "window-close"

        onClicked: {
            if (tasks.groupDialog !== null && tasks.groupDialog.visualParent === menu.visualParent) {
                tasks.groupDialog.visible = false;
            }

            tasksModel.requestClose(menu.modelIndex);
        }
    }
}
