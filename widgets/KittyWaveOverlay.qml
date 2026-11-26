import "../components"
import "../services"
import "../theme"
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Item {
    id: root

    property MediaController mediaController: null
    property AudioSyncService audioSync: null
    readonly property bool isPlaying: !!(root.mediaController && root.mediaController.isPlaying)
    property real waveEnergy: root.isPlaying ? 1 : 0
    property real phase: 0
    property real _animAccum: 0
    property var kittyRectsByScreen: ({
    })
    property bool hasAnyKitty: false

    function rectsOverlap(ax, ay, aw, ah, bx, by, bw, bh) {
        return ax < (bx + bw) && (ax + aw) > bx && ay < (by + bh) && (ay + ah) > by;
    }

    function refreshKittyWindows() {
        if (!root.isPlaying && root.waveEnergy <= 0.005)
            return ;

        if (!queryProc.running)
            queryProc.running = true;

    }

    function rectsForScreen(screenName) {
        if (!screenName || !root.kittyRectsByScreen)
            return [];

        return root.kittyRectsByScreen[screenName] || [];
    }

    width: 0
    height: 0
    onIsPlayingChanged: {
        if (root.isPlaying)
            root.refreshKittyWindows();

    }
    Component.onCompleted: {
        if (root.isPlaying)
            root.refreshKittyWindows();

    }

    Behavior on waveEnergy {
        NumberAnimation {
            duration: 420
            easing.type: Easing.OutCubic
        }

    }

    Timer {
        id: refreshDebounce

        interval: 45
        repeat: false
        onTriggered: root.refreshKittyWindows()
    }

    Connections {
        function onRawEvent(event) {
            if (!root.isPlaying || !event)
                return ;

            var n = event.name;
            if (n === "openwindow" || n === "closewindow" || n === "movewindowv2" || n === "workspacev2" || n === "focusedmonv2" || n === "activespecial" || n === "changefloatingmode" || n === "fullscreen" || n === "activewindowv2")
                refreshDebounce.restart();

        }

        target: Hyprland
    }

    Process {
        id: queryProc

        command: ["sh", "-c", "hyprctl -j monitors; printf '\\n---QS_SPLIT---\\n'; hyprctl -j clients"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                var raw = String(this.text || "");
                var parts = raw.split("---QS_SPLIT---");
                if (parts.length < 2)
                    return ;

                try {
                    var monitors = JSON.parse(parts[0].trim() || "[]");
                    var clients = JSON.parse(parts[1].trim() || "[]");
                    var monById = {
                    };
                    for (var m = 0; m < monitors.length; m++) {
                        var mon = monitors[m];
                        if (!mon)
                            continue;

                        monById[mon.id] = {
                            "name": mon.name || "",
                            "x": mon.x || 0,
                            "y": mon.y || 0,
                            "activeWs": mon.activeWorkspace ? mon.activeWorkspace.id : -999,
                            "specialWs": mon.specialWorkspace ? mon.specialWorkspace.id : -999
                        };
                    }
                    var fullscreensByWs = {
                    };
                    var floatersByWs = {
                    };
                    for (var k = 0; k < clients.length; k++) {
                        var kc = clients[k];
                        if (!kc || !kc.mapped || kc.hidden)
                            continue;

                        var kws = kc.workspace ? kc.workspace.id : -998;
                        if (kc.fullscreen && kc.fullscreen > 0)
                            fullscreensByWs[kws] = kc.address;

                        if (kc.floating) {
                            if (!floatersByWs[kws])
                                floatersByWs[kws] = [];

                            floatersByWs[kws].push(kc);
                        }
                    }
                    var nextMap = {
                    };
                    var foundAny = false;
                    for (var c = 0; c < clients.length; c++) {
                        var cl = clients[c];
                        if (!cl || !cl.mapped || cl.hidden)
                            continue;

                        var cls = String(cl["class"] || cl.initialClass || "").toLowerCase();
                        if (cls !== "kitty")
                            continue;

                        var mInfo = monById[cl.monitor];
                        if (!mInfo || !mInfo.name)
                            continue;

                        var wsId = cl.workspace ? cl.workspace.id : -998;
                        var onVisibleWs = (wsId === mInfo.activeWs) || (mInfo.specialWs > 0 && wsId === mInfo.specialWs) || !!cl.pinned;
                        if (!onVisibleWs)
                            continue;

                        if (fullscreensByWs[wsId] && fullscreensByWs[wsId] !== cl.address)
                            continue;

                        var at = cl.at || [0, 0];
                        var sz = cl.size || [0, 0];
                        if (sz[0] < 80 || sz[1] < 80)
                            continue;

                        // Skip if a higher-z floating window overlaps the bottom wave strip of this Kitty window
                        var waveBandH = Math.min(130, Math.max(72, Math.round(sz[1] * 0.14)));
                        var bandY = at[1] + sz[1] - waveBandH;
                        var occluded = false;
                        var fl = floatersByWs[wsId] || [];
                        for (var f = 0; f < fl.length; f++) {
                            var fc = fl[f];
                            if (fc.address === cl.address)
                                continue;

                            if (!cl.floating || fc.focusHistoryID < cl.focusHistoryID) {
                                var fat = fc.at || [0, 0];
                                var fsz = fc.size || [0, 0];
                                if (root.rectsOverlap(at[0], bandY, sz[0], waveBandH, fat[0], fat[1], fsz[0], fsz[1])) {
                                    occluded = true;
                                    break;
                                }
                            }
                        }
                        if (occluded)
                            continue;

                        if (!nextMap[mInfo.name])
                            nextMap[mInfo.name] = [];

                        nextMap[mInfo.name].push({
                            "x": Math.round(at[0] - mInfo.x),
                            "y": Math.round(at[1] - mInfo.y),
                            "w": Math.round(sz[0]),
                            "h": Math.round(sz[1]),
                            "focused": (cl.focusHistoryID === 0)
                        });
                        foundAny = true;
                    }
                    root.kittyRectsByScreen = nextMap;
                    root.hasAnyKitty = foundAny;
                } catch (e) {
                }
            }
        }

    }

    FrameAnimation {
        running: (root.isPlaying || root.waveEnergy > 0.01) && root.hasAnyKitty
        onTriggered: {
            root._animAccum += frameTime;
            if (root._animAccum < 0.020)
                return ;

            var dt = root._animAccum;
            root._animAccum = 0;
            var liveSig = !!(root.audioSync && root.audioSync.hasSignal);
            var spd = liveSig ? root.audioSync.speed : 0.75;
            var rate = liveSig ? (0.75 + spd * 1.95) : 1.6;
            root.phase = (root.phase + dt * rate) % (Math.PI * 200);
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: winOverlay

            required property var modelData
            readonly property string screenName: (modelData && modelData.name) ? modelData.name : ""
            readonly property var kittyRects: root.rectsForScreen(winOverlay.screenName)

            screen: modelData
            visible: root.waveEnergy > 0.005 && winOverlay.kittyRects.length > 0
            color: "transparent"
            WlrLayershell.namespace: "kitty-wave-bg"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // Strictly visual overlay: click-through
            mask: Region {
            }

            Repeater {
                model: winOverlay.visible ? winOverlay.kittyRects : []

                delegate: Item {
                    id: kittyBounds

                    required property var modelData
                    readonly property bool liveSig: !!(root.audioSync && root.audioSync.hasSignal)
                    readonly property real lv: liveSig ? root.audioSync.level : 0.28
                    readonly property real bs: liveSig ? root.audioSync.bass : 0.24
                    readonly property real bt: liveSig ? root.audioSync.beat : 0
                    readonly property real focusBoost: modelData.focused ? 1 : 0.78
                    readonly property real groove: liveSig ? (0.42 + 0.62 * lv + 0.52 * bs + 0.35 * bt) : (0.76 + 0.20 * Math.sin(root.phase * 1.9))
                    readonly property real ampScale: root.waveEnergy * groove * focusBoost
                    readonly property real glowPulse: 1 + 0.35 * bt

                    x: modelData.x
                    y: modelData.y
                    width: modelData.w
                    height: modelData.h
                    clip: true

                    Item {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: Math.min(130, Math.max(72, Math.round(kittyBounds.height * 0.14)))

                        // Back ambient swell (GPU CurveRenderer — static gradient + GPU opacity)
                        GlassWaveRibbon {
                            anchors.fill: parent
                            phase: -root.phase * 0.85 + 1.2
                            baseFraction: 0.56
                            frequency: 6.8
                            amplitudePx: 12 * kittyBounds.ampScale
                            edgeTaperBase: 0.35
                            strokeColor: Theme.withAlpha(Theme.accent, 0.25)
                            fillColor: Theme.accent
                            fillAlpha: 0.09
                            opacity: root.waveEnergy * kittyBounds.focusBoost * (0.72 + 0.28 * kittyBounds.glowPulse) * (0.7 + 0.3 * kittyBounds.lv)
                            lineWidth: 1.4
                        }

                        // Primary luminous wave synced to song tempo & bass (GPU CurveRenderer)
                        GlassWaveRibbon {
                            anchors.fill: parent
                            phase: root.phase
                            baseFraction: 0.65
                            frequency: 8.8
                            amplitudePx: 15 * kittyBounds.ampScale
                            edgeTaperBase: 0.35
                            strokeColor: Theme.withAlpha(Theme.accent, 0.54)
                            fillColor: Theme.accent
                            fillAlpha: 0.16
                            opacity: root.waveEnergy * kittyBounds.focusBoost * (0.72 + 0.28 * kittyBounds.glowPulse) * (0.65 + 0.35 * kittyBounds.bs)
                            lineWidth: 2
                        }

                        // Subtle bright crest highlight (GPU CurveRenderer)
                        GlassWaveRibbon {
                            anchors.fill: parent
                            phase: root.phase * 1.28 + 2.2
                            baseFraction: 0.75
                            frequency: 11.4
                            amplitudePx: 10 * kittyBounds.ampScale
                            edgeTaperBase: 0.35
                            strokeColor: Theme.withAlpha(Theme.bright_foreground, 0.30)
                            fillColor: Theme.bright_foreground
                            fillAlpha: 0.05
                            opacity: root.waveEnergy * kittyBounds.focusBoost * (0.75 + 0.25 * kittyBounds.glowPulse)
                            lineWidth: 1.25
                        }

                    }

                }

            }

        }

    }

}
