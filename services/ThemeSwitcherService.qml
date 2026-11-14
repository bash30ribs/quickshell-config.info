import "../theme"
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property var themes: []
    property string currentTheme: ""
    property bool isSwitching: false
    property string switchingTo: ""
    property bool isOpen: false
    property var thumbMap: ({
    })
    property var pendingList: []
    readonly property string listScriptPath: "qdeck-theme-switch"
    readonly property string thumbScriptPath: Quickshell.env("HOME") + "/.config/quickshell/src/qdeck-wallpaper-thumbs.py"
    readonly property string currentThemeLink: Quickshell.env("HOME") + "/.config/themes/current"
    property Timer switchResetTimer
    readonly property int middleIndex: root.themes ? Math.floor(root.themes.length / 2) : 0
    property Process thumbProc
    property Process listProc
    // Automatically refresh themes when colors change in Theme.qml
    property Connections themeWatcher

    function refresh() {
        if (!listProc.running)
            listProc.running = true;

    }

    function switchTheme(themeId) {
        if (!themeId)
            return ;

        root.isSwitching = true;
        root.switchingTo = themeId;
        // Execute theme switch script (theme-switch will also reload quickshell)
        Quickshell.execDetached([root.listScriptPath, "switch", themeId]);
        switchResetTimer.restart();
    }

    function runSetup() {
        Quickshell.execDetached([root.listScriptPath, "setup"]);
    }

    function centerActiveTheme(list) {
        if (!list || list.length <= 1)
            return list || [];

        var activeIdx = -1;
        for (var i = 0; i < list.length; i++) {
            if (list[i].isCurrent) {
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
        var centered = root.centerActiveTheme(parsed);
        var missing = [];
        for (var i = 0; i < centered.length; i++) {
            var p = centered[i].wallpaper;
            if (p) {
                if (centered[i].thumbPath)
                    root.thumbMap[p] = centered[i].thumbPath;
                else if (root.thumbMap[p])
                    centered[i].thumbPath = root.thumbMap[p];
                else
                    missing.push(p);
            }
        }
        var changed = !root.themes || root.themes.length !== centered.length;
        if (!changed) {
            for (var k = 0; k < centered.length; k++) {
                if (root.themes[k].id !== centered[k].id || root.themes[k].isCurrent !== centered[k].isCurrent || root.themes[k].thumbPath !== centered[k].thumbPath) {
                    changed = true;
                    break;
                }
            }
        }
        if (changed)
            root.themes = centered;

        if (missing.length > 0 && !thumbProc.running) {
            root.pendingList = parsed;
            thumbProc.command = ["python3", root.thumbScriptPath].concat(missing);
            thumbProc.running = true;
        }
    }

    Component.onCompleted: {
        root.refresh();
    }

    switchResetTimer: Timer {
        interval: 3500
        repeat: false
        onTriggered: {
            root.isSwitching = false;
            root.switchingTo = "";
            root.refresh();
            Theme.reloadTheme();
        }
    }

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
                    console.warn("[ThemeSwitcherService] Failed to parse thumb map:", e);
                }
            }
        }

    }

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
                            if (parsed[i].isCurrent) {
                                root.currentTheme = parsed[i].id;
                                break;
                            }
                        }
                        root.applyWithThumbs(parsed);
                    }
                } catch (e) {
                    console.warn("[ThemeSwitcherService] Failed to parse themes JSON:", e);
                }
            }
        }

    }

    themeWatcher: Connections {
        function on_CChanged() {
            root.refresh();
        }

        target: Theme
    }

}
