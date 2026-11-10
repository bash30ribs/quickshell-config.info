import "../components"
import "../services"
import "../theme"
import "../widgets"
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    required property WorkspacesService workspacesService
    required property AudioService audioService
    required property BrightnessService brightnessService
    required property BatteryService batteryService
    required property NetworkService networkService
    required property BluetoothService bluetoothService
    required property PowerService powerService
    property var clipboardDrawer: null
    property real glideAccum: 0
    property real glideCooldownUntil: 0
    // Bar layout mode configuration (floating, islands, wide, compact)
    property string barMode: "floating"
    // Configuration file watcher for dynamic mode changes
    property FileView barStyleFile
    // Configuration file watcher for bar visibility
    property FileView barVisibilityFile
    readonly property bool isCompact: barMode === "compact"
    readonly property bool isWide: barMode === "wide"
    readonly property bool isIslands: barMode === "islands"
    readonly property bool isFloating: barMode === "floating"
    readonly property bool hasSideAnchors: isFloating || isIslands
    readonly property real totalContentWidth: leftSection.width + clockWidget.width + rightSection.width + (Appearance.barSectionSpacing * 4)

    function handleBarWheel(event) {
        if (!root.clipboardDrawer) {
            event.accepted = false;
            return ;
        }
        var dy = Theme.wheelDeltaY(event);
        var dx = Theme.wheelDeltaX(event);
        console.debug("[BarWheel] adY=", event.angleDelta ? event.angleDelta.y : 0, "pdY=", event.pixelDelta ? event.pixelDelta.y : 0, "inv=", Boolean(event.inverted), "dy=", dy, "dx=", dx, "open=", root.clipboardDrawer.isOpen);
        if (dy === 0 || Math.abs(dy) < Math.abs(dx) * 0.6) {
            event.accepted = false;
            return ;
        }
        if (!root.clipboardDrawer.isOpen && dy < 0) {
            event.accepted = false;
            return ;
        }
        if (Date.now() < root.glideCooldownUntil) {
            event.accepted = true;
            return ;
        }
        if ((dy > 0 && root.glideAccum < 0) || (dy < 0 && root.glideAccum > 0))
            root.glideAccum = 0;

        root.glideAccum += dy;
        glideResetTimer.restart();
        // Natural scroll: gliding 2 fingers DOWN produces positive delta.y;
        // gliding 2 fingers UP produces negative delta.y
        if (!root.clipboardDrawer.isOpen && root.glideAccum >= 4) {
            root.glideAccum = 0;
            root.glideCooldownUntil = Date.now() + 220;
            root.clipboardDrawer.open();
        } else if (root.clipboardDrawer.isOpen && root.glideAccum <= -4) {
            root.glideAccum = 0;
            root.glideCooldownUntil = Date.now() + 220;
            root.clipboardDrawer.close();
        }
    }

    visible: Appearance.barVisible
    implicitHeight: Appearance.barHeight
    implicitWidth: root.isCompact ? Math.round(root.totalContentWidth + (Appearance.barMarginHorizontal * 2)) : (root.isWide ? Math.round((root.screen ? root.screen.width : 1920) * 0.72) : (root.screen ? root.screen.width - (Appearance.barMarginHorizontal * 2) : 1896))
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-bar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Auto

    // Panel anchors: top attached, sides attached only in full-width modes
    anchors {
        top: true
        left: root.hasSideAnchors
        right: root.hasSideAnchors
    }

    // Outer screen margins for floating appearance
    margins {
        left: Appearance.barMarginHorizontal
        right: Appearance.barMarginHorizontal
        top: 0
        bottom: 0
    }

    // Unified background surface with Mornye Liquid Glass material (floating, wide, compact modes)
    GlassPanel {
        id: barBackground

        visible: !root.isIslands
        anchors.fill: parent
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: Appearance.barRadius > 0 ? Appearance.barRadius : 16
        bottomRightRadius: Appearance.barRadius > 0 ? Appearance.barRadius : 16
        baseColor: Theme.barBackground
        accentTint: Theme.accent
    }

    // Left island capsule (islands mode)
    GlassPanel {
        id: leftIslandBg

        visible: root.isIslands
        x: leftSection.x - 6
        y: Math.round((parent.height - height) / 2)
        width: leftSection.width + 12
        height: Appearance.barButtonHeight + 4
        radius: Appearance.barRadius > 0 ? Appearance.barRadius : 14
        baseColor: Theme.barBackground
        accentTint: Theme.accent
    }

    // Center island capsule (islands mode)
    GlassPanel {
        id: centerIslandBg

        visible: root.isIslands
        x: clockWidget.x - 8
        y: Math.round((parent.height - height) / 2)
        width: clockWidget.width + 16
        height: Appearance.barButtonHeight + 4
        radius: Appearance.barRadius > 0 ? Appearance.barRadius : 14
        baseColor: Theme.barBackground
        accentTint: Theme.accent
    }

    // Right island capsule (islands mode)
    GlassPanel {
        id: rightIslandBg

        visible: root.isIslands
        x: rightSection.x - 6
        y: Math.round((parent.height - height) / 2)
        width: rightSection.width + 12
        height: Appearance.barButtonHeight + 4
        radius: Appearance.barRadius > 0 ? Appearance.barRadius : 14
        baseColor: Theme.barBackground
        accentTint: Theme.accent
    }

    Timer {
        id: glideResetTimer

        interval: 320
        repeat: false
        onTriggered: {
            root.glideAccum = 0;
        }
    }

    // Widget content container
    Item {
        id: barContainer

        anchors.fill: parent

        HoverHandler {
            id: barHover
        }

        // Topmost wheel, touchpad scroll-gesture, and touchscreen overlay across the whole bar
        Item {
            anchors.fill: parent
            z: 100

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                hoverEnabled: false
                scrollGestureEnabled: true
                onWheel: function(event) {
                    event.accepted = true;
                    root.handleBarWheel(event);
                }
            }

            DragHandler {
                id: twoFingerBarDrag

                acceptedDevices: PointerDevice.TouchScreen
                minimumPointCount: 2
                maximumPointCount: 2
                target: null
                xAxis.enabled: false
                onTranslationChanged: {
                    if (!root.clipboardDrawer || Date.now() < root.glideCooldownUntil)
                        return ;

                    if (!root.clipboardDrawer.isOpen && translation.y >= 16) {
                        root.glideCooldownUntil = Date.now() + 280;
                        root.clipboardDrawer.open();
                    } else if (root.clipboardDrawer.isOpen && translation.y <= -16) {
                        root.glideCooldownUntil = Date.now() + 280;
                        root.clipboardDrawer.close();
                    }
                }
            }

        }

        // Subtle pull-down indicator along bottom center of bar
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            height: 2
            radius: 1
            width: (root.clipboardDrawer && root.clipboardDrawer.isOpen) ? 32 : (barHover.hovered ? 24 : 12)
            color: (root.clipboardDrawer && root.clipboardDrawer.isOpen) ? Theme.accent : Theme.withAlpha(Theme.bright_foreground, 0.55)
            opacity: (root.clipboardDrawer && root.clipboardDrawer.isOpen) ? 0.8 : (barHover.hovered ? 0.5 : 0)
            visible: !root.isIslands
            z: 20

            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }

            }

            Behavior on width {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }

            }

            Behavior on color {
                ColorAnimation {
                    duration: 160
                }

            }

        }

        // Left section: workspace switcher and media pill
        Row {
            id: leftSection

            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.barSectionSpacing
            width: implicitWidth
            height: implicitHeight
            x: root.isCompact ? Math.round((barContainer.width - root.totalContentWidth) / 2) : Appearance.barMarginHorizontal

            WorkspacesWidget {
                service: root.workspacesService
            }

            NowBarPill {
                audioService: root.audioService
            }

        }

        // Center section: date and clock
        ClockWidget {
            id: clockWidget

            anchors.verticalCenter: parent.verticalCenter
            x: root.isCompact ? (leftSection.x + leftSection.width + (Appearance.barSectionSpacing * 2)) : Math.round((barContainer.width - width) / 2)
            powerService: root.powerService
        }

        // Right section: hardware and status controls
        Row {
            id: rightSection

            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.barSpacing
            width: implicitWidth
            height: implicitHeight
            x: root.isCompact ? (clockWidget.x + clockWidget.width + (Appearance.barSectionSpacing * 2)) : Math.round(barContainer.width - width - Appearance.barMarginHorizontal)

            BluetoothWidget {
                id: bluetoothWidget

                service: root.bluetoothService
            }

            NetworkWidget {
                id: networkWidget

                service: root.networkService
            }

            AudioWidget {
                id: audioWidget

                service: root.audioService
            }

            MonitorWidget {
                id: monitorWidget

                service: root.brightnessService
            }

            BatteryWidget {
                id: batteryWidget

                batteryService: root.batteryService
                powerService: root.powerService
            }

        }

    }

    // IPC handler for external popup toggles and bar mode control
    IpcHandler {
        function toggle(name: string) : string {
            if (name === "clock")
                clockWidget.toggle();
            else if (name === "monitor")
                monitorWidget.toggle();
            else if (name === "battery")
                batteryWidget.toggle();
            else if (name === "network")
                networkWidget.toggle();
            else if (name === "audio")
                audioWidget.toggle();
            else if (name === "bluetooth")
                bluetoothWidget.toggle();
            else if (name === "clipboard" && root.clipboardDrawer)
                root.clipboardDrawer.toggle();
            return "ok";
        }

        function setMode(newMode: string) : string {
            if (newMode === "compact" || newMode === "floating" || newMode === "islands" || newMode === "wide") {
                root.barMode = newMode;
                return "ok: " + newMode;
            }
            return "error: unknown mode";
        }

        function getMode() : string {
            return root.barMode;
        }

        function toggleBar() : string {
            Appearance.barVisible = !Appearance.barVisible;
            return Appearance.barVisible ? "visible" : "hidden";
        }

        function hideBar() : string {
            Appearance.barVisible = false;
            return "hidden";
        }

        function showBar() : string {
            Appearance.barVisible = true;
            return "visible";
        }

        function isBarVisible() : string {
            return Appearance.barVisible ? "true" : "false";
        }

        target: "barpopups"
    }

    barStyleFile: FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/bar-style"
        watchChanges: true
        printErrors: false
        onLoaded: {
            var raw = String(text() || "").trim().toLowerCase();
            if (raw === "compact" || raw === "floating" || raw === "islands" || raw === "wide")
                root.barMode = raw;
            else
                root.barMode = "floating";
        }
    }

    barVisibilityFile: FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/bar-visibility"
        watchChanges: true
        printErrors: false
        onLoaded: {
            var raw = String(text() || "").trim().toLowerCase();
            if (raw === "hidden" || raw === "false" || raw === "hide" || raw === "off")
                Appearance.barVisible = false;
            else if (raw === "visible" || raw === "true" || raw === "show" || raw === "on")
                Appearance.barVisible = true;
        }
    }

}
