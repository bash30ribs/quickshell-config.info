import "../services"
import "../theme"
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io

Item {
    id: root

    property MediaController controller

    controller: MediaController {
        id: defaultCtrl
    }

    property AudioService audioService: null
    property alias popup: mediaPopup
    readonly property bool hasMedia: controller ? controller.hasMedia : false
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

    implicitHeight: root.isVertical ? (hasMedia ? 54 : 0) : Appearance.mediaPillHeight
    implicitWidth: root.isVertical ? (hasMedia ? Math.max(Appearance.mediaPillHeight, Appearance.barThickness - 10) : 0) : (hasMedia ? Math.min(195, Math.max(110, titleMeasure.implicitWidth + 56)) : 0)
    height: implicitHeight
    width: implicitWidth
    visible: (width > 0 && height > 0) || opacity > 0
    opacity: hasMedia ? 1 : 0
    scale: hasMedia ? 1 : 0.85
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
        color: mediaPopup.open ? Theme.withAlpha(Theme.accent, 0.22) : (pillMouse.containsMouse ? Theme.withAlpha(Theme.glassCrest, 0.16) : Theme.withAlpha(Theme.glassCrest, 0.08))
        border.color: mediaPopup.open ? Theme.withAlpha(Theme.accent, 0.55) : (pillMouse.containsMouse ? Theme.withAlpha(Theme.glassCrest, 0.35) : Theme.withAlpha(Theme.glassBorderColor, 0.2))
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
                y: root.isVertical ? 5 : Math.round((parent.height - height) / 2)

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
                color: Theme.bright_foreground
                elide: Text.ElideRight
                maximumLineCount: 1
                horizontalAlignment: Text.AlignLeft
            }

            // ── 3. High-Fidelity 3-Bar Waveform Visualizer ─────────────────────
            Row {
                id: visualizerRow

                x: root.isVertical ? Math.round((parent.width - width) / 2) : Math.round(parent.width - width - 8)
                y: root.isVertical ? Math.round(parent.height - height - 6) : Math.round((parent.height - height) / 2)
                spacing: 2
                height: 14

                // Bar 0
                Rectangle {
                    width: 2.2
                    height: (root.controller && root.controller.isPlaying) ? 6 : 3.5
                    radius: width / 2
                    color: (root.controller && root.controller.isPlaying) ? Theme.accent : Theme.withAlpha(Theme.foreground, 0.4)
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on height {
                        enabled: !(root.controller && root.controller.isPlaying)

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

                    SequentialAnimation on height {
                        running: root.controller && root.controller.isPlaying
                        loops: Animation.Infinite

                        NumberAnimation {
                            to: 10
                            duration: 240
                            easing.type: Easing.InOutQuad
                        }

                        NumberAnimation {
                            to: 4
                            duration: 280
                            easing.type: Easing.InOutQuad
                        }

                        NumberAnimation {
                            to: 8
                            duration: 210
                            easing.type: Easing.InOutQuad
                        }

                        NumberAnimation {
                            to: 6
                            duration: 260
                            easing.type: Easing.InOutQuad
                        }

                    }

                }

                // Bar 1 (Center Peak)
                Rectangle {
                    width: 2.2
                    height: (root.controller && root.controller.isPlaying) ? 12 : 5
                    radius: width / 2
                    color: (root.controller && root.controller.isPlaying) ? Theme.accent : Theme.withAlpha(Theme.foreground, 0.4)
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on height {
                        enabled: !(root.controller && root.controller.isPlaying)

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

                    SequentialAnimation on height {
                        running: root.controller && root.controller.isPlaying
                        loops: Animation.Infinite

                        NumberAnimation {
                            to: 6
                            duration: 220
                            easing.type: Easing.InOutQuad
                        }

                        NumberAnimation {
                            to: 13
                            duration: 270
                            easing.type: Easing.InOutQuad
                        }

                        NumberAnimation {
                            to: 7
                            duration: 230
                            easing.type: Easing.InOutQuad
                        }

                        NumberAnimation {
                            to: 11
                            duration: 250
                            easing.type: Easing.InOutQuad
                        }

                    }

                }

                // Bar 2
                Rectangle {
                    width: 2.2
                    height: (root.controller && root.controller.isPlaying) ? 8 : 3.5
                    radius: width / 2
                    color: (root.controller && root.controller.isPlaying) ? Theme.accent : Theme.withAlpha(Theme.foreground, 0.4)
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on height {
                        enabled: !(root.controller && root.controller.isPlaying)

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

                    SequentialAnimation on height {
                        running: root.controller && root.controller.isPlaying
                        loops: Animation.Infinite

                        NumberAnimation {
                            to: 9
                            duration: 260
                            easing.type: Easing.InOutQuad
                        }

                        NumberAnimation {
                            to: 4
                            duration: 230
                            easing.type: Easing.InOutQuad
                        }

                        NumberAnimation {
                            to: 11
                            duration: 280
                            easing.type: Easing.InOutQuad
                        }

                        NumberAnimation {
                            to: 7
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

    Behavior on implicitWidth {
        enabled: !Appearance.barTransitioning

        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }

    }

    Behavior on implicitHeight {
        enabled: !Appearance.barTransitioning

        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }

    }

    Behavior on opacity {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }

    }

    Behavior on scale {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutBack
            easing.overshoot: 1.12
        }

    }

}
