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
    property QtObject clipboardDrawer: null
    property real glideAccum: 0
    property real glideCooldownUntil: 0
    // Bar layout mode configuration (floating, islands, wide, compact)
    property string barMode: "floating"
    // Configuration file watcher for dynamic mode changes
    property FileView barStyleFile
    // Configuration file watcher for bar visibility
    property FileView barVisibilityFile
    // Configuration file watcher for bar screen edge (top, bottom, left, right)
    property FileView barEdgeFile
    readonly property bool isCompact: barMode === "compact"
    readonly property bool isWide: barMode === "wide"
    readonly property bool isIslands: barMode === "islands"
    readonly property bool isFloating: barMode === "floating"
    readonly property bool hasSideAnchors: isFloating || isIslands
    readonly property bool isVertical: Appearance.barIsVertical
    readonly property bool isHorizontal: !root.isVertical
    readonly property real screenWidth: root.screen ? root.screen.width : 1920
    readonly property real screenHeight: root.screen ? root.screen.height : 1200
    readonly property real totalContentWidth: root.isVertical ? (leftSection.height + clockWidget.height + rightSection.height + (Appearance.barSectionSpacing * 4)) : (leftSection.width + clockWidget.width + rightSection.width + (Appearance.barSectionSpacing * 4))
    // Synchronized 2-phase edge-drop & show/hide choreography state
    property string pendingEdge: Appearance.barEdge
    property real edgeProgress: 1
    property real showProgress: Appearance.barVisible ? 1 : 0
    property bool isVisibleSurface: Appearance.barVisible
    property bool _edgeInitialized: false
    readonly property bool isEdgeTransitioning: edgeRetractAnim.running || edgeSwapTimer.running || edgeAppearDelayTimer.running || edgeDropAnim.running || Appearance.barTransitioning
    readonly property string barLightEdge: Appearance.barIsLeft ? "right" : (Appearance.barIsRight ? "left" : "top")

    function normalizeEdge(rawEdge) {
        var e = String(rawEdge || "").trim().toLowerCase();
        if (e === "up" || e === "top")
            return "top";

        if (e === "down" || e === "bottom")
            return "bottom";

        if (e === "left")
            return "left";

        if (e === "right")
            return "right";

        return "";
    }

    function applyEdge(rawEdge, persist) {
        var normalized = root.normalizeEdge(rawEdge);
        if (!normalized)
            return "";

        if (persist) {
            var cmd = "mkdir -p \"$HOME/.config/quickshell\" && printf '%s\\n' \"" + normalized + "\" > \"$HOME/.config/quickshell/bar-edge\"";
            Quickshell.execDetached(["sh", "-c", cmd]);
        }
        if (!root._edgeInitialized) {
            root._edgeInitialized = true;
            root.pendingEdge = normalized;
            if (Appearance.barEdge !== normalized) {
                Appearance.barTransitioning = true;
                Appearance.barEdge = normalized;
            }
            if (Appearance.barVisible) {
                root.edgeProgress = 0;
                edgeAppearDelayTimer.restart();
            } else {
                Appearance.barTransitioning = false;
            }
            return normalized;
        }
        var activeTarget = (edgeRetractAnim.running || edgeSwapTimer.running || edgeAppearDelayTimer.running) ? root.pendingEdge : Appearance.barEdge;
        if (normalized === activeTarget)
            return normalized;

        if (root.clipboardDrawer && root.clipboardDrawer.isOpen)
            root.clipboardDrawer.close();

        Appearance.closeBarPopups();
        root.pendingEdge = normalized;
        if (!Appearance.barVisible) {
            Appearance.barTransitioning = true;
            Appearance.barEdge = normalized;
            Appearance.barTransitioning = false;
            return normalized;
        }
        if (edgeRetractAnim.running || edgeSwapTimer.running || edgeAppearDelayTimer.running)
            return normalized;

        edgeDropAnim.stop();
        Appearance.barTransitioning = true;
        edgeRetractAnim.restart();
        return normalized;
    }

    function handleBarWheel(event) {
        if (!root.clipboardDrawer) {
            event.accepted = false;
            return ;
        }
        var dy = Theme.wheelDeltaY(event);
        var dx = Theme.wheelDeltaX(event);
        // Natural scroll inward axis relative to docked edge:
        // top: dy > 0, bottom: dy < 0, left: dx > 0, right: dx < 0
        var inwardDelta = Appearance.barIsTop ? dy : (Appearance.barIsBottom ? -dy : (Appearance.barIsLeft ? dx : -dx));
        var crossDelta = root.isVertical ? dy : dx;
        if (inwardDelta === 0 || Math.abs(inwardDelta) < Math.abs(crossDelta) * 0.5) {
            event.accepted = false;
            return ;
        }
        if (!root.clipboardDrawer.isOpen && inwardDelta < 0) {
            // Eat tiny initial contact jitter over WorkspacesWidget; allow deliberate scroll-through
            event.accepted = Math.abs(inwardDelta) < 12;
            return ;
        }
        if (Date.now() < root.glideCooldownUntil) {
            event.accepted = true;
            return ;
        }
        if (root.clipboardDrawer.isOpen && inwardDelta < 0 && (Date.now() - root.clipboardDrawer.openedAtMs) < 320) {
            event.accepted = true;
            return ;
        }
        if ((inwardDelta > 0 && root.glideAccum < 0) || (inwardDelta < 0 && root.glideAccum > 0))
            root.glideAccum = 0;

        root.glideAccum += inwardDelta;
        glideResetTimer.restart();
        if (!root.clipboardDrawer.isOpen && root.glideAccum >= 4) {
            root.glideAccum = 0;
            root.glideCooldownUntil = Date.now() + 380;
            root.clipboardDrawer.open();
        } else if (root.clipboardDrawer.isOpen && root.clipboardDrawer.stage === 1 && root.glideAccum >= 8) {
            if ((Date.now() - root.clipboardDrawer.stageChangedAtMs) >= 340) {
                root.glideAccum = 0;
                root.glideCooldownUntil = Date.now() + 380;
                root.clipboardDrawer.showTextStage();
            }
        } else if (root.clipboardDrawer.isOpen && root.glideAccum <= -4) {
            root.glideAccum = 0;
            root.glideCooldownUntil = Date.now() + 380;
            root.clipboardDrawer.close();
        }
        event.accepted = true;
    }

    visible: root.isVisibleSurface
    implicitHeight: root.isHorizontal ? Appearance.barHeight : (root.isCompact ? Math.round(root.totalContentWidth + (Appearance.barMarginHorizontal * 2)) : (root.isWide ? Math.round(root.screenHeight * 0.72) : Math.round(root.screenHeight - (Appearance.barMarginHorizontal * 2))))
    implicitWidth: root.isVertical ? Appearance.barThickness : (root.isCompact ? Math.round(root.totalContentWidth + (Appearance.barMarginHorizontal * 2)) : (root.isWide ? Math.round(root.screenWidth * 0.72) : Math.round(root.screenWidth - (Appearance.barMarginHorizontal * 2))))
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-bar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Auto

    // Panel anchors adapt cleanly across top, bottom, left, and right screen edges
    anchors {
        top: root.isHorizontal ? Appearance.barIsTop : root.hasSideAnchors
        bottom: root.isHorizontal ? Appearance.barIsBottom : root.hasSideAnchors
        left: root.isVertical ? Appearance.barIsLeft : root.hasSideAnchors
        right: root.isVertical ? Appearance.barIsRight : root.hasSideAnchors
    }

    // Outer screen margins for floating appearance (docked edge sits flush at 0)
    margins {
        left: (root.isVertical && Appearance.barIsLeft) ? 0 : Appearance.barMarginHorizontal
        right: (root.isVertical && Appearance.barIsRight) ? 0 : Appearance.barMarginHorizontal
        top: (root.isHorizontal && Appearance.barIsTop) ? 0 : Appearance.barMarginHorizontal
        bottom: (root.isHorizontal && Appearance.barIsBottom) ? 0 : Appearance.barMarginHorizontal
    }

    Connections {
        function onBarVisibleChanged() {
            if (Appearance.barVisible) {
                root.isVisibleSurface = true;
                hideAnim.stop();
                showAnim.restart();
            } else {
                if (root.clipboardDrawer && root.clipboardDrawer.isOpen)
                    root.clipboardDrawer.close();

                Appearance.closeBarPopups();
                showAnim.stop();
                hideAnim.restart();
            }
        }

        target: Appearance
    }

    NumberAnimation {
        id: edgeRetractAnim

        target: root
        property: "edgeProgress"
        from: root.edgeProgress
        to: 0
        duration: Math.max(35, Math.round(75 * root.edgeProgress))
        easing.type: Easing.InCubic
        onFinished: {
            if (root.edgeProgress <= 0.001)
                edgeSwapTimer.restart();

        }
    }

    Timer {
        id: edgeSwapTimer

        interval: 16
        repeat: false
        onTriggered: {
            Appearance.barEdge = root.pendingEdge;
            edgeAppearDelayTimer.restart();
        }
    }

    Timer {
        id: edgeAppearDelayTimer

        interval: 22
        repeat: false
        onTriggered: {
            Appearance.barTransitioning = false;
            if (Appearance.barVisible)
                edgeDropAnim.restart();
            else
                root.edgeProgress = 1;
        }
    }

    NumberAnimation {
        id: edgeDropAnim

        target: root
        property: "edgeProgress"
        from: root.edgeProgress
        to: 1
        duration: 185
        easing.type: Easing.OutQuart
    }

    NumberAnimation {
        id: showAnim

        target: root
        property: "showProgress"
        from: root.showProgress
        to: 1
        duration: 175
        easing.type: Easing.OutQuart
    }

    NumberAnimation {
        id: hideAnim

        target: root
        property: "showProgress"
        from: root.showProgress
        to: 0
        duration: 115
        easing.type: Easing.InCubic
        onFinished: {
            if (!Appearance.barVisible && root.showProgress <= 0.001)
                root.isVisibleSurface = false;

        }
    }

    Timer {
        id: glideResetTimer

        interval: 320
        repeat: false
        onTriggered: {
            root.glideAccum = 0;
        }
    }

    // Animated edge-drop container carrying glass backgrounds and widgets at 120fps
    Item {
        id: edgeSurface

        readonly property real reveal: root.edgeProgress * root.showProgress
        readonly property real travelX: Appearance.barIsLeft ? -root.width : (Appearance.barIsRight ? root.width : 0)
        readonly property real travelY: Appearance.barIsTop ? -root.height : (Appearance.barIsBottom ? root.height : 0)

        anchors.fill: parent
        opacity: Math.max(0, Math.min(1, reveal * 2.25))
        scale: 0.96 + (0.04 * reveal)
        transformOrigin: Appearance.barIsBottom ? Item.Bottom : (Appearance.barIsLeft ? Item.Left : (Appearance.barIsRight ? Item.Right : Item.Top))

        // Unified background surface with Mornye Liquid Glass material (floating, wide, compact modes)
        GlassPanel {
            id: barBackground

            readonly property int cornerRadius: Appearance.barRadius > 0 ? Appearance.barRadius : 16

            visible: !root.isIslands
            anchors.fill: parent
            topLeftRadius: (Appearance.barIsTop || Appearance.barIsLeft) ? 0 : cornerRadius
            topRightRadius: (Appearance.barIsTop || Appearance.barIsRight) ? 0 : cornerRadius
            bottomLeftRadius: (Appearance.barIsBottom || Appearance.barIsLeft) ? 0 : cornerRadius
            bottomRightRadius: (Appearance.barIsBottom || Appearance.barIsRight) ? 0 : cornerRadius
            lightEdge: root.barLightEdge
            baseColor: Theme.barBackground
            accentTint: Theme.accent
        }

        // Left/Top island capsule (islands mode)
        GlassPanel {
            id: leftIslandBg

            visible: root.isIslands
            x: root.isVertical ? 0 : (leftSection.x - 6)
            y: root.isVertical ? (leftSection.y - 6) : Math.round((parent.height - height) / 2)
            width: root.isVertical ? barContainer.width : (leftSection.width + 12)
            height: root.isVertical ? (leftSection.height + 12) : (Appearance.barButtonHeight + 4)
            radius: Appearance.barRadius > 0 ? Appearance.barRadius : 14
            lightEdge: root.barLightEdge
            baseColor: Theme.barBackground
            accentTint: Theme.accent
        }

        // Center island capsule (islands mode)
        GlassPanel {
            id: centerIslandBg

            visible: root.isIslands
            x: root.isVertical ? 0 : (clockWidget.x - 8)
            y: root.isVertical ? (clockWidget.y - 8) : Math.round((parent.height - height) / 2)
            width: root.isVertical ? barContainer.width : (clockWidget.width + 16)
            height: root.isVertical ? (clockWidget.height + 16) : (Appearance.barButtonHeight + 4)
            radius: Appearance.barRadius > 0 ? Appearance.barRadius : 14
            lightEdge: root.barLightEdge
            baseColor: Theme.barBackground
            accentTint: Theme.accent
        }

        // Right/Bottom island capsule (islands mode)
        GlassPanel {
            id: rightIslandBg

            visible: root.isIslands
            x: root.isVertical ? 0 : (rightSection.x - 6)
            y: root.isVertical ? (rightSection.y - 6) : Math.round((parent.height - height) / 2)
            width: root.isVertical ? barContainer.width : (rightSection.width + 12)
            height: root.isVertical ? (rightSection.height + 12) : (Appearance.barButtonHeight + 4)
            radius: Appearance.barRadius > 0 ? Appearance.barRadius : 14
            lightEdge: root.barLightEdge
            baseColor: Theme.barBackground
            accentTint: Theme.accent
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
                    xAxis.enabled: root.isVertical
                    yAxis.enabled: root.isHorizontal
                    onTranslationChanged: {
                        if (!root.clipboardDrawer || Date.now() < root.glideCooldownUntil)
                            return ;

                        var inward = Appearance.barIsTop ? translation.y : (Appearance.barIsBottom ? -translation.y : (Appearance.barIsLeft ? translation.x : -translation.x));
                        if (!root.clipboardDrawer.isOpen && inward >= 16) {
                            root.glideCooldownUntil = Date.now() + 280;
                            root.clipboardDrawer.open();
                        } else if (root.clipboardDrawer.isOpen && inward <= -16) {
                            root.glideCooldownUntil = Date.now() + 280;
                            root.clipboardDrawer.close();
                        }
                    }
                }

            }

            // Subtle pull-inward indicator along inner edge of bar (fixed geometry + centered Scale)
            Rectangle {
                id: pullHint

                readonly property real activeScale: (root.clipboardDrawer && root.clipboardDrawer.isOpen) ? 1 : (barHover.hovered ? 0.75 : 0.375)

                x: root.isVertical ? (Appearance.barIsLeft ? (parent.width - 3) : 1) : Math.round((parent.width - width) / 2)
                y: root.isHorizontal ? (Appearance.barIsTop ? (parent.height - 3) : 1) : Math.round((parent.height - height) / 2)
                width: root.isVertical ? 2 : 32
                height: root.isVertical ? 32 : 2
                radius: 1
                color: (root.clipboardDrawer && root.clipboardDrawer.isOpen) ? Theme.accent : Theme.withAlpha(Theme.bright_foreground, 0.55)
                opacity: (root.clipboardDrawer && root.clipboardDrawer.isOpen) ? 0.8 : (barHover.hovered ? 0.5 : 0)
                visible: !root.isIslands
                z: 20

                transform: Scale {
                    origin.x: root.isVertical ? 1 : 16
                    origin.y: root.isVertical ? 16 : 1
                    xScale: root.isHorizontal ? pullHint.activeScale : 1
                    yScale: root.isVertical ? pullHint.activeScale : 1

                    Behavior on xScale {
                        enabled: !root.isEdgeTransitioning

                        NumberAnimation {
                            duration: 160
                            easing.type: Easing.OutCubic
                        }

                    }

                    Behavior on yScale {
                        enabled: !root.isEdgeTransitioning

                        NumberAnimation {
                            duration: 160
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }

                }

                Behavior on color {
                    ColorAnimation {
                        duration: 160
                    }

                }

            }

            // Left / Top section: workspace switcher and media pill
            Grid {
                id: leftSection

                columns: root.isVertical ? 1 : 4
                columnSpacing: Appearance.barSectionSpacing
                rowSpacing: Appearance.barSectionSpacing
                horizontalItemAlignment: Grid.AlignHCenter
                verticalItemAlignment: Grid.AlignVCenter
                width: implicitWidth
                height: implicitHeight
                x: root.isVertical ? Math.round((barContainer.width - width) / 2) : (root.isCompact ? Math.round((barContainer.width - root.totalContentWidth) / 2) : Appearance.barMarginHorizontal)
                y: root.isVertical ? (root.isCompact ? Math.round((barContainer.height - root.totalContentWidth) / 2) : Appearance.barMarginHorizontal) : Math.round((barContainer.height - height) / 2)

                WorkspacesWidget {
                    service: root.workspacesService
                }

                NowBarPill {
                    audioService: root.audioService
                }

                Behavior on x {
                    enabled: !root.isEdgeTransitioning && !root.isCompact && !root.isWide

                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on y {
                    enabled: !root.isEdgeTransitioning && !root.isCompact && !root.isWide

                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }

                }

            }

            // Center section: date and clock
            ClockWidget {
                id: clockWidget

                x: root.isVertical ? Math.round((barContainer.width - width) / 2) : (root.isCompact ? (leftSection.x + leftSection.width + (Appearance.barSectionSpacing * 2)) : Math.round((barContainer.width - width) / 2))
                y: root.isVertical ? (root.isCompact ? (leftSection.y + leftSection.height + (Appearance.barSectionSpacing * 2)) : Math.round((barContainer.height - height) / 2)) : Math.round((barContainer.height - height) / 2)
                powerService: root.powerService

                Behavior on x {
                    enabled: !root.isEdgeTransitioning && !root.isCompact && !root.isWide

                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on y {
                    enabled: !root.isEdgeTransitioning && !root.isCompact && !root.isWide

                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }

                }

            }

            // Right / Bottom section: hardware and status controls
            Grid {
                id: rightSection

                columns: root.isVertical ? 1 : 8
                columnSpacing: Appearance.barSpacing
                rowSpacing: Appearance.barSpacing
                horizontalItemAlignment: Grid.AlignHCenter
                verticalItemAlignment: Grid.AlignVCenter
                width: implicitWidth
                height: implicitHeight
                x: root.isVertical ? Math.round((barContainer.width - width) / 2) : (root.isCompact ? (clockWidget.x + clockWidget.width + (Appearance.barSectionSpacing * 2)) : Math.round(barContainer.width - width - Appearance.barMarginHorizontal))
                y: root.isVertical ? (root.isCompact ? (clockWidget.y + clockWidget.height + (Appearance.barSectionSpacing * 2)) : Math.round(barContainer.height - height - Appearance.barMarginHorizontal)) : Math.round((barContainer.height - height) / 2)

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

                Behavior on x {
                    enabled: !root.isEdgeTransitioning && !root.isCompact && !root.isWide

                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on y {
                    enabled: !root.isEdgeTransitioning && !root.isCompact && !root.isWide

                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }

                }

            }

        }

        transform: Translate {
            x: edgeSurface.travelX * (1 - edgeSurface.reveal)
            y: edgeSurface.travelY * (1 - edgeSurface.reveal)
        }

    }

    // IPC handler for external popup toggles and bar mode/edge control
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
            else if ((name === "clipbar" || name === "clipboard") && root.clipboardDrawer)
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

        function setEdge(newEdge: string) : string {
            var applied = root.applyEdge(newEdge, true);
            if (applied)
                return "ok: " + applied;

            return "error: unknown edge";
        }

        function getEdge() : string {
            return Appearance.barEdge;
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
        onFileChanged: reload()
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
        onFileChanged: reload()
        onLoaded: {
            var raw = String(text() || "").trim().toLowerCase();
            if (raw === "hidden" || raw === "false" || raw === "hide" || raw === "off")
                Appearance.barVisible = false;
            else if (raw === "visible" || raw === "true" || raw === "show" || raw === "on")
                Appearance.barVisible = true;
        }
    }

    barEdgeFile: FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/bar-edge"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoadFailed: {
            root._edgeInitialized = true;
        }
        onLoaded: {
            var normalized = root.normalizeEdge(text());
            if (normalized)
                root.applyEdge(normalized, false);
            else
                root.applyEdge("top", false);
        }
    }

}
