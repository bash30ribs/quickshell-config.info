import "../services"
import "../theme"
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io

Item {
    id: root

    property MediaController controller
    property AudioService audioService: null
    property alias popup: mediaPopup
    readonly property bool hasMedia: controller ? controller.hasMedia : false
    readonly property bool isPlaying: controller ? controller.isPlaying : false
    property bool graceActive: false
    readonly property bool pillActive: (root.controller && root.controller.hasMedia) && (root.isPlaying || root.graceActive || mediaPopup.open)
    readonly property string trackTitle: {
        if (!root.controller)
            return "";

        var t = (root.controller.title || "").trim();
        var a = (root.controller.artist || "").trim();
        if (t && a)
            return a + " • " + t;

        return t || a || "Music";
    }
    readonly property bool isVertical: Appearance.barIsVertical

    onIsPlayingChanged: {
        if (root.isPlaying) {
            pauseGraceTimer.stop();
            root.graceActive = false;
        } else if (root.controller && root.controller.hasMedia) {
            root.graceActive = true;
            pauseGraceTimer.restart();
        } else {
            pauseGraceTimer.stop();
            root.graceActive = false;
        }
    }
    implicitHeight: root.isVertical ? (pillActive ? Math.max(28, Appearance.barThickness - 10) : 0) : (pillActive ? Appearance.mediaPillHeight : 0)
    implicitWidth: root.isVertical ? (pillActive ? Math.max(28, Appearance.barThickness - 10) : 0) : (pillActive ? Math.min(205, Math.max(115, titleMeasure.implicitWidth + 58)) : 0)
    height: implicitHeight
    width: implicitWidth
    visible: (width > 0 && height > 0) || opacity > 0
    opacity: pillActive ? 1 : 0
    scale: pillActive ? 1 : 0.88

    Timer {
        id: pauseGraceTimer

        interval: 6000
        repeat: false
        onTriggered: {
            if (!root.isPlaying && !mediaPopup.open)
                root.graceActive = false;

        }
    }

    Connections {
        function onOpenChanged() {
            if (!mediaPopup.open && !root.isPlaying)
                root.graceActive = false;

        }

        target: mediaPopup
    }

    // Hidden text measuring component for fluid pill expansion
    Text {
        id: titleMeasure

        text: root.trackTitle
        font.family: Fonts.uiFont
        font.pixelSize: Fonts.scale(10.5)
        font.weight: Fonts.weightDemiBold
        visible: false
    }

    // Outer Frosted Glass Container
    Rectangle {
        id: pillBg

        anchors.fill: parent
        radius: Math.min(width, height) / 2
        clip: true
        antialiasing: true
        color: mediaPopup.open ? Theme.withAlpha(Theme.accent, 0.25) : (pillMouse.containsMouse ? Theme.withAlpha(Theme.glassCrest, 0.18) : (root.isPlaying ? Qt.rgba(0.08, 0.11, 0.15, 0.7) : Qt.rgba(0.05, 0.07, 0.09, 0.5)))
        border.color: mediaPopup.open ? Theme.withAlpha(Theme.accent, 0.6) : (pillMouse.containsMouse ? Theme.withAlpha(Theme.accent, 0.45) : (root.isPlaying ? Theme.withAlpha(Theme.accent, 0.3) : Theme.withAlpha(Theme.glassBorderColor, 0.2)))
        border.width: 1
        scale: pillMouse.pressed ? 0.965 : (pillMouse.containsMouse ? 1.025 : 1)
        transformOrigin: Item.Center

        // Content wrapper with dynamic opacity during pill width collapse
        Item {
            anchors.fill: parent
            opacity: root.isVertical ? (root.height > 20 ? 1 : 0) : Math.max(0, Math.min(1, (root.width - 45) / 35))

            // ── 1. Mini Rounded Album Art on Left Side ────────────────────────
            Item {
                id: miniArtBox

                width: 20
                height: 20
                x: root.isVertical ? Math.round((parent.width - width) / 2) : 5
                y: Math.round((parent.height - height) / 2)

                Rectangle {
                    id: miniArtBg

                    anchors.fill: parent
                    radius: Appearance.radiusSmall
                    color: Theme.dark_background

                    Text {
                        anchors.centerIn: parent
                        text: "󰝚"
                        font.family: Icons.effectiveFont("󰝚")
                        font.pixelSize: Fonts.scale(11)
                        color: Theme.accent
                        visible: !miniArt.visible
                    }

                    Rectangle {
                        id: miniArtMask

                        anchors.fill: parent
                        radius: Appearance.radiusSmall
                        color: "black"
                        layer.enabled: true
                        visible: false
                    }

                    Image {
                        id: miniArt

                        anchors.fill: parent
                        source: root.controller ? root.controller.artUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                        sourceSize.width: 40
                        sourceSize.height: 40
                        mipmap: true
                        smooth: true
                        layer.enabled: true

                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: miniArtMask
                        }

                    }

                }

            }

            // ── 2. Track & Artist Title in Middle (Left-Aligned, Rock-Solid) ──
            Text {
                id: titleText

                visible: !root.isVertical
                x: miniArtBox.x + miniArtBox.width + 7
                width: Math.max(0, visualizerRow.x - x - 6)
                anchors.verticalCenter: parent.verticalCenter
                text: root.trackTitle
                font.family: Fonts.uiFont
                font.pixelSize: Fonts.scale(10.5)
                font.weight: Fonts.weightDemiBold
                color: root.isPlaying ? Theme.bright_foreground : Theme.muted
                elide: Text.ElideRight
                maximumLineCount: 1
                horizontalAlignment: Text.AlignLeft
            }

            // ── 3. High-Fidelity 3-Bar Waveform Visualizer ─────────────────────
            Row {
                id: visualizerRow

                visible: !root.isVertical
                x: Math.round(parent.width - width - 8)
                y: Math.round((parent.height - height) / 2)
                spacing: 2.5
                height: 14

                // Bar 0
                Rectangle {
                    id: bar0

                    property real eqScale: root.isPlaying ? 0.6 : 0.22

                    width: 2.4
                    height: 12
                    radius: width / 2
                    color: root.isPlaying ? Theme.accent : Theme.withAlpha(Theme.foreground, 0.35)
                    anchors.verticalCenter: parent.verticalCenter

                    transform: Scale {
                        origin.x: 1.2
                        origin.y: 6
                        yScale: bar0.eqScale
                    }

                    Behavior on eqScale {
                        enabled: !root.isPlaying

                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }

                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 180
                        }

                    }

                    SequentialAnimation on eqScale {
                        running: root.isPlaying
                        loops: Animation.Infinite

                        NumberAnimation {
                            to: 0.85
                            duration: 240
                            easing.type: Easing.InOutQuad
                        }

                        NumberAnimation {
                            to: 0.35
                            duration: 280
                            easing.type: Easing.InOutQuad
                        }

                        NumberAnimation {
                            to: 0.7
                            duration: 210
                            easing.type: Easing.InOutQuad
                        }

                        NumberAnimation {
                            to: 0.5
                            duration: 260
                            easing.type: Easing.InOutQuad
                        }

                    }

                }

                // Bar 1 (Center Peak)
                Rectangle {
                    id: bar1

                    property real eqScale: root.isPlaying ? 1 : 0.22

                    width: 2.4
                    height: 12
                    radius: width / 2
                    color: root.isPlaying ? Theme.accent : Theme.withAlpha(Theme.foreground, 0.35)
                    anchors.verticalCenter: parent.verticalCenter

                    transform: Scale {
                        origin.x: 1.2
                        origin.y: 6
                        yScale: bar1.eqScale
                    }

                    Behavior on eqScale {
                        enabled: !root.isPlaying

                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }

                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 180
                        }

                    }

                    SequentialAnimation on eqScale {
                        running: root.isPlaying
                        loops: Animation.Infinite

                        NumberAnimation {
                            to: 0.5
                            duration: 220
                            easing.type: Easing.InOutQuad
                        }

                        NumberAnimation {
                            to: 1
                            duration: 270
                            easing.type: Easing.InOutQuad
                        }

                        NumberAnimation {
                            to: 0.58
                            duration: 230
                            easing.type: Easing.InOutQuad
                        }

                        NumberAnimation {
                            to: 0.92
                            duration: 250
                            easing.type: Easing.InOutQuad
                        }

                    }

                }

                // Bar 2
                Rectangle {
                    id: bar2

                    property real eqScale: root.isPlaying ? 0.75 : 0.22

                    width: 2.4
                    height: 12
                    radius: width / 2
                    color: root.isPlaying ? Theme.accent : Theme.withAlpha(Theme.foreground, 0.35)
                    anchors.verticalCenter: parent.verticalCenter

                    transform: Scale {
                        origin.x: 1.2
                        origin.y: 6
                        yScale: bar2.eqScale
                    }

                    Behavior on eqScale {
                        enabled: !root.isPlaying

                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }

                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 180
                        }

                    }

                    SequentialAnimation on eqScale {
                        running: root.isPlaying
                        loops: Animation.Infinite

                        NumberAnimation {
                            to: 0.75
                            duration: 260
                            easing.type: Easing.InOutQuad
                        }

                        NumberAnimation {
                            to: 0.35
                            duration: 230
                            easing.type: Easing.InOutQuad
                        }

                        NumberAnimation {
                            to: 0.9
                            duration: 280
                            easing.type: Easing.InOutQuad
                        }

                        NumberAnimation {
                            to: 0.6
                            duration: 240
                            easing.type: Easing.InOutQuad
                        }

                    }

                }

            }

        }

        MouseArea {
            id: pillMouse

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: function(mouse) {
                if (mouse.button === Qt.LeftButton) {
                    mediaPopup.toggle();
                } else if (mouse.button === Qt.MiddleButton) {
                    if (root.controller)
                        root.controller.togglePlay();

                } else if (mouse.button === Qt.RightButton) {
                    if (root.controller)
                        root.controller.next();

                }
            }
            onWheel: function(event) {
                if (!root.controller)
                    return ;

                if (event.angleDelta.y > 0)
                    root.controller.next();
                else if (event.angleDelta.y < 0)
                    root.controller.previous();
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Appearance.animDurationNormal
            }

        }

        Behavior on border.color {
            ColorAnimation {
                duration: Appearance.animDurationNormal
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: pillMouse.pressed ? 70 : 180
                easing.type: pillMouse.pressed ? Easing.OutQuad : Easing.OutBack
                easing.overshoot: pillMouse.pressed ? 1 : 1.25
            }

        }

    }

    // IPC Interface for toggling media island popup
    IpcHandler {
        function toggle() : string {
            mediaPopup.toggle();
            return "ok";
        }

        function open() : string {
            mediaPopup.open = true;
            return "ok";
        }

        function close() : string {
            mediaPopup.open = false;
            return "ok";
        }

        target: "media"
    }

    // Expanded Aqua Dynamics / Dynamic Island Media Card
    MediaIslandPopup {
        id: mediaPopup

        anchorItem: root
        anchorWindow: root.QsWindow ? root.QsWindow.window : null
        controller: root.controller
        audioService: root.audioService
    }

    controller: MediaController {
        id: defaultCtrl
    }

    Behavior on implicitWidth {
        enabled: !Appearance.barTransitioning

        NumberAnimation {
            duration: 320
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
        }

    }

    Behavior on implicitHeight {
        enabled: !Appearance.barTransitioning

        NumberAnimation {
            duration: 320
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
        }

    }

    Behavior on opacity {
        NumberAnimation {
            duration: 240
            easing.type: Easing.OutCubic
        }

    }

    Behavior on scale {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutBack
            easing.overshoot: 1.14
        }

    }

}
