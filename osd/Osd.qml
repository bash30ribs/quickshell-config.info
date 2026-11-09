import "../components"
import "../theme"
import "OsdModel.js" as OsdModel
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Item {
    id: root

    property var bluetoothService: null
    property var brightnessService: null
    // Display state
    property bool opened: false
    property string icon: "󰕾"
    property string message: ""
    property int value: 0
    property int maxValue: 100
    property bool hasProgress: true
    property bool isMuted: false
    property bool isOverMax: false
    property int duration: 1500
    // ─────────────────────────────────────────────────────────────────────────
    // Animation Controllers (Fade + Slight Slide-in)
    // ─────────────────────────────────────────────────────────────────────────
    property real animProgress: 0

    // ─────────────────────────────────────────────────────────────────────────
    // Display Functions
    // ─────────────────────────────────────────────────────────────────────────
    function showOsd(iconStr, msgStr, val, maxVal, hasProg, isMute, isOver, dur) {
        root.icon = iconStr || "󰕾";
        root.message = msgStr || "";
        root.value = val !== undefined ? val : 0;
        root.maxValue = maxVal || 100;
        root.hasProgress = !!hasProg;
        root.isMuted = !!isMute;
        root.isOverMax = !!isOver;
        root.duration = dur || 1500;
        closeAnim.stop();
        if (!root.opened) {
            root.opened = true;
        } else {
            if (root.animProgress < 1)
                openAnim.restart();

        }
        hideTimer.interval = root.duration > 0 ? root.duration : 1500;
        hideTimer.restart();
    }

    function showToast(iconStr, msgStr, dur) {
        showOsd(iconStr, msgStr, 0, 100, false, false, false, dur || 1500);
    }

    function open(payloadJson) {
        try {
            var p = JSON.parse(payloadJson || "{}");
            var next = OsdModel.stateForShow(p.icon || "", p.message || "", p.value !== undefined ? String(p.value) : "", p.max !== undefined ? String(p.max) : "100", p.progressText || "", p.duration !== undefined ? String(p.duration) : "1500");
            var isMute = (next.iconKey.indexOf("mute") !== -1 || next.icon === "󰝟" || next.icon === "");
            showOsd(next.icon, next.message, next.value, next.maxValue, next.hasProgress, isMute, next.value > 100, next.duration);
        } catch (e) {
            console.warn("[OSD] Failed to parse payload:", e);
        }
    }

    function close() {
        root.opened = false;
    }

    onOpenedChanged: {
        if (root.opened) {
            closeAnim.stop();
            openAnim.restart();
        } else {
            openAnim.stop();
            closeAnim.restart();
        }
    }

    Connections {
        function onRefreshRateChanged(hz, mode, monName) {
            var msg = hz + "Hz";
            if (mode && mode !== "")
                msg = mode + " @ " + hz + "Hz";

            root.showToast("󰍹", msg, 2000);
        }

        target: root.brightnessService
        ignoreUnknownSignals: true
    }

    // Single hide timer: restarts on every trigger to eliminate interval stacking
    Timer {
        id: hideTimer

        interval: root.duration > 0 ? root.duration : 1500
        repeat: false
        onTriggered: root.opened = false
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Bluetooth & Lock-State Toasts (Non-reactive to Audio / Backlight)
    // ─────────────────────────────────────────────────────────────────────────
    Connections {
        function onDeviceConnected(name, mac) {
            root.showToast("󰂱", (name || "Bluetooth Device") + " Connected", 2000);
        }

        function onDeviceDisconnected(name, mac) {
            root.showToast("󰂲", (name || "Bluetooth Device") + " Disconnected", 2000);
        }

        target: root.bluetoothService
        ignoreUnknownSignals: true
    }

    Process {
        id: lockStateProc

        command: ["qdeck-lockstate-monitor"]
        running: true

        stdout: SplitParser {
            onRead: function(line) {
                var l = String(line || "").trim();
                if (l === "NUMLOCK:ON")
                    root.showToast("󰎠", "Num Lock: ON", 1600);
                else if (l === "NUMLOCK:OFF")
                    root.showToast("󰎠", "Num Lock: OFF", 1600);
                else if (l === "CAPSLOCK:ON")
                    root.showToast("󰌌", "Caps Lock: ON", 1600);
                else if (l === "CAPSLOCK:OFF")
                    root.showToast("󰌌", "Caps Lock: OFF", 1600);
                else if (l === "TRACKPAD:ON" || l === "TOUCHPAD:ON")
                    root.showToast("󰟸", "Trackpad: ON", 1600);
                else if (l === "TRACKPAD:OFF" || l === "TOUCHPAD:OFF")
                    root.showToast("󰤳", "Trackpad: OFF", 1600);
            }
        }

    }

    NumberAnimation {
        id: openAnim

        target: root
        property: "animProgress"
        to: 1
        duration: 180
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: closeAnim

        target: root
        property: "animProgress"
        to: 0
        duration: 150
        easing.type: Easing.InQuad
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Resident Wayland Layer Shell Surface
    // ─────────────────────────────────────────────────────────────────────────
    PanelWindow {
        id: panel

        // Focused monitor binding
        screen: {
            if (!Quickshell.screens || Quickshell.screens.length === 0)
                return null;

            var foc = Hyprland.focusedMonitor;
            if (foc && foc.name) {
                for (var i = 0; i < Quickshell.screens.length; i++) {
                    if (Quickshell.screens[i].name === foc.name)
                        return Quickshell.screens[i];

                }
            }
            return Quickshell.screens[0];
        }
        // Fully unmapped when hidden; stays mapped during close animation fade-out
        visible: root.opened || closeAnim.running
        implicitHeight: 140
        color: "transparent"
        WlrLayershell.namespace: "quickshell-osd"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        anchors {
            bottom: true
            left: true
            right: true
        }

        GlassPanel {
            id: card

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Appearance.osdBottomMargin
            radius: Appearance.osdRadius > 0 ? Appearance.osdRadius : 16
            width: Math.max(120, contentRow.implicitWidth + 38)
            height: Appearance.osdHeight
            transformOrigin: Item.Center
            opacity: root.animProgress
            scale: 0.92 + 0.08 * root.animProgress

            Row {
                id: contentRow

                anchors.centerIn: parent
                spacing: Appearance.osdSpacing

                // OSD Icon
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.icon
                    font.family: Icons.effectiveFont(root.icon)
                    font.pixelSize: Fonts.sizeTitle
                    color: {
                        if (root.isMuted)
                            return Theme.red;

                        if (root.isOverMax)
                            return Theme.yellow;

                        return Theme.bright_foreground;
                    }
                }

                // Progress Bar (Volume & Brightness)
                Rectangle {
                    visible: root.hasProgress
                    anchors.verticalCenter: parent.verticalCenter
                    width: Appearance.osdTrackWidth
                    height: Appearance.osdTrackHeight
                    radius: Appearance.osdTrackRadius
                    color: Qt.rgba(1, 1, 1, 0.12)

                    Rectangle {
                        height: parent.height
                        radius: Appearance.osdTrackRadius
                        color: {
                            if (root.isMuted)
                                return Theme.red;

                            if (root.isOverMax)
                                return Theme.yellow;

                            return Theme.accent;
                        }
                        width: parent.width * Math.min(1, Math.max(0, root.value / root.maxValue))

                        Behavior on width {
                            enabled: root.opened

                            NumberAnimation {
                                duration: 60
                                easing.type: Easing.OutQuad
                            }

                        }

                    }

                }

                // Value or Message label
                Text {
                    visible: root.message !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.message
                    font.family: Fonts.uiFont
                    font.pixelSize: Fonts.sizeRegular
                    font.weight: Fonts.weightDemiBold
                    color: {
                        if (root.isMuted)
                            return Theme.red;

                        if (root.isOverMax)
                            return Theme.yellow;

                        return Theme.bright_foreground;
                    }
                }

            }

            transform: Translate {
                y: (1 - root.animProgress) * 20
            }

        }

        // Visual-only click-through: empty input mask passes all clicks straight through
        mask: Region {
        }

    }

}
