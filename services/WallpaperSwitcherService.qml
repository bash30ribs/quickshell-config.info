import "../theme"
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property var wallpapers: []
    property string activeWallpaper: ""
    property bool isSwitching: false
    property string switchingTo: ""
    property bool isOpen: false
    property var thumbMap: ({
    })
    property var pendingList: []
    readonly property string listScriptPath: "qdeck-wallpaper"
    readonly property string thumbScriptPath: Quickshell.env("HOME") + "/.config/quickshell/src/qdeck-wallpaper-thumbs.py"
    readonly property int middleIndex: root.wallpapers ? Math.floor(root.wallpapers.length / 2) : 0
    property Timer switchResetTimer

    switchResetTimer: Timer {
        interval: 1500
        repeat: false
        onTriggered: {
            root.isSwitching = false;
            root.switchingTo = "";
            root.refresh();
            Theme.reloadWallpaperPalette();
        }
    }

    property Process thumbProc

    thumbProc: Process {
        id: thumbProc

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var raw = text.trim();
                if (!raw)
                    return ;

                try {
                    var map = JSON.parse(raw);
                    var updated = root.thumbMap || {
                    };
                    for (var k in map) {
                        updated[k] = map[k];
                    }
                    root.thumbMap = updated;
                    if (root.pendingList && root.pendingList.length > 0)
                        root.applyWithThumbs(root.pendingList);

                } catch (e) {
                    console.warn("[WallpaperSwitcherService] Failed to parse thumb map:", e);
                }
            }
        }

    }

    property Process listProc

    listProc: Process {
        id: listProc

        command: [root.listScriptPath, "list"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var raw = text.trim();
                if (!raw)
                    return ;

                try {
                    var parsed = JSON.parse(raw);
                    if (Array.isArray(parsed)) {
                        for (var i = 0; i < parsed.length; i++) {
                            if (parsed[i].isActive) {
                                root.activeWallpaper = parsed[i].path;
                                break;
                            }
                        }
                        root.applyWithThumbs(parsed);
                    }
                } catch (e) {
                    console.warn("[WallpaperSwitcherService] Failed to parse wallpapers JSON:", e);
                }
            }
        }

    }

    // Refresh wallpapers when theme changes
    property Connections themeWatcher

    themeWatcher: Connections {
        function on_CChanged() {
            root.refresh();
        }

        target: Theme
    }

    function refresh() {
        if (!listProc.running)
            listProc.running = true;

    }

    function switchWallpaper(wallpaperPath) {
        if (!wallpaperPath)
            return ;

        root.isSwitching = true;
        root.switchingTo = wallpaperPath;
        // Execute wallpaper-switch script via helper
        Quickshell.execDetached([root.listScriptPath, "switch", wallpaperPath]);
        switchResetTimer.restart();
        Theme.reloadWallpaperPalette();
    }

    function centerActiveWallpaper(list) {
        if (!list || list.length <= 1)
            return list || [];

        var activeIdx = -1;
        for (var i = 0; i < list.length; i++) {
            if (list[i].isActive) {
                activeIdx = i;
                break;
            }
        }
        if (activeIdx === -1)
            return list;

        var n = list.length;
        var targetMid = Math.floor(n / 2);
        var shift = (activeIdx - targetMid + n) % n;
        if (shift === 0)
            return list;

        var rotated = [];
        for (var j = 0; j < n; j++) {
            rotated.push(list[(j + shift) % n]);
        }
        return rotated;
    }

    function applyWithThumbs(parsed) {
        var centered = root.centerActiveWallpaper(parsed);
        var missing = [];
        for (var i = 0; i < centered.length; i++) {
            var p = centered[i].path;
            if (p) {
                if (root.thumbMap[p])
                    centered[i].thumbPath = root.thumbMap[p];
                else
                    missing.push(p);
            }
        }
        // Check if list actually changed to avoid unnecessary ListView delegate rebuilds
        var changed = !root.wallpapers || root.wallpapers.length !== centered.length;
        if (!changed) {
            for (var k = 0; k < centered.length; k++) {
                if (root.wallpapers[k].path !== centered[k].path || root.wallpapers[k].isActive !== centered[k].isActive || root.wallpapers[k].thumbPath !== centered[k].thumbPath) {
                    changed = true;
                    break;
                }
            }
        }
        if (changed)
            root.wallpapers = centered;

        if (missing.length > 0 && !thumbProc.running) {
            root.pendingList = parsed;
            thumbProc.command = ["python3", root.thumbScriptPath].concat(missing);
            thumbProc.running = true;
        }
    }

    Component.onCompleted: {
        root.refresh();
    }
}
