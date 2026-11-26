import "../theme"
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Item {
    id: root

    property MediaController mediaController: null
    readonly property bool isPlaying: !!(root.mediaController && root.mediaController.isPlaying)
    property real waveEnergy: root.isPlaying ? 1 : 0
    property real phase: 0
    property var kittyRectsByScreen: ({
    })
    property bool hasAnyKitty: false

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

    function rectsOverlap(ax, ay, aw, ah, bx, by, bw, bh) {
        return ax < (bx + bw) && (ax + aw) > bx && ay < (by + bh) && (ay + ah) > by;
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
            root.phase = (root.phase + frameTime * 2.35) % (Math.PI * 200);
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

            // Strictly visual layer underneath Kitty's translucent glass: never intercepts clicks
            mask: Region {
            }

            Repeater {
                model: winOverlay.visible ? winOverlay.kittyRects : []

                delegate: Item {
                    id: kittyBounds

                    required property var modelData

                    x: modelData.x
                    y: modelData.y
                    width: modelData.w
                    height: modelData.h
                    clip: true

                    Canvas {
                        id: kittyWaveCanvas

                        readonly property real wavePhase: root.phase
                        readonly property real waveEnergy: root.waveEnergy
                        readonly property color accentCol: Theme.accent
                        readonly property color crestCol: Theme.bright_foreground

                        function rgbaStr(col, alphaMul) {
                            var c = Qt.color(col);
                            var a = Math.max(0, Math.min(1, c.a * alphaMul));
                            return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a.toFixed(3) + ")";
                        }

                        function drawLayer(ctx, w, h, baseFrac, ampPx, freq, phaseShift, col, fillAlpha, strokeAlpha, strokeWidth) {
                            var steps = 48;
                            var baseY = h * baseFrac;
                            ctx.beginPath();
                            for (var i = 0; i <= steps; i++) {
                                var u = i / steps;
                                var x = u * w;
                                var taper = 0.35 + 0.65 * Math.sin(u * Math.PI);
                                var s = Math.sin(u * freq + phaseShift) * 0.62 + Math.cos(u * (freq * 1.65) - phaseShift * 0.72) * 0.38;
                                var y = baseY - s * ampPx * taper;
                                if (i === 0)
                                    ctx.moveTo(x, y);
                                else
                                    ctx.lineTo(x, y);
                            }
                            if (fillAlpha > 0.005) {
                                ctx.save();
                                ctx.lineTo(w, h);
                                ctx.lineTo(0, h);
                                ctx.closePath();
                                var grad = ctx.createLinearGradient(0, Math.max(0, baseY - ampPx - 6), 0, h);
                                grad.addColorStop(0, rgbaStr(col, fillAlpha));
                                grad.addColorStop(0.55, rgbaStr(col, fillAlpha * 0.45));
                                grad.addColorStop(1, rgbaStr(col, 0));
                                ctx.fillStyle = grad;
                                ctx.fill();
                                ctx.restore();
                            }
                            ctx.strokeStyle = rgbaStr(col, strokeAlpha);
                            ctx.lineWidth = strokeWidth;
                            ctx.lineCap = "round";
                            ctx.lineJoin = "round";
                            ctx.stroke();
                        }

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: Math.min(130, Math.max(72, Math.round(kittyBounds.height * 0.14)))
                        onWavePhaseChanged: requestPaint()
                        onWaveEnergyChanged: requestPaint()
                        onAccentColChanged: requestPaint()
                        onCrestColChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        Component.onCompleted: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d");
                            var w = width;
                            var h = height;
                            if (w <= 0 || h <= 0)
                                return ;

                            ctx.clearRect(0, 0, w, h);
                            var e = waveEnergy;
                            if (e <= 0.005)
                                return ;

                            var ph = wavePhase;
                            var groove = 0.78 + 0.22 * Math.sin(ph * 1.9 + 0.4 * Math.sin(ph * 0.7));
                            var focusBoost = kittyBounds.modelData.focused ? 1 : 0.78;
                            var ampScale = e * groove * focusBoost;
                            // Subtle ambient translucent wave gliding calmly across the bottom of Kitty
                            drawLayer(ctx, w, h, 0.56, 12 * ampScale, 6.8, -ph * 0.85 + 1.2, accentCol, 0.08 * e * focusBoost, 0.20 * e * focusBoost, 1.4);
                            drawLayer(ctx, w, h, 0.65, 15 * ampScale, 8.8, ph, accentCol, 0.13 * e * focusBoost, 0.48 * e * focusBoost, 2.0);
                            drawLayer(ctx, w, h, 0.75, 10 * ampScale, 11.4, ph * 1.28 + 2.2, crestCol, 0.05 * e * focusBoost, 0.28 * e * focusBoost, 1.25);
                        }
                    }

                }

            }

        }

    }

}
