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
    readonly property string trackTitle: root.controller ? (root.controller.title || root.controller.artist || "Music") : ""
    readonly property bool isVertical: Appearance.barIsVertical

    implicitHeight: root.isVertical ? (hasMedia ? 54 : 0) : Appearance.mediaPillHeight
    implicitWidth: root.isVertical ? (hasMedia ? Math.max(Appearance.mediaPillHeight, Appearance.barThickness - 10) : 0) : (hasMedia ? Math.min(220, Math.max(130, titleMeasure.implicitWidth + 82)) : 0)
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
        font.pixelSize: Fonts.scale(11)
        font.weight: Fonts.weightBold
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

        // ── 1. Mini Rounded Album Art on Left Side ────────────────────────
        Item {
            id: miniArtBox

            width: 18
            height: 18
            x: root.isVertical ? Math.round((parent.width - width) / 2) : 6
            y: root.isVertical ? 6 : Math.round((parent.height - height) / 2)

            Rectangle {
                id: miniArtBg

                anchors.fill: parent
                radius: Appearance.radiusSmall
                color: Theme.dark_background

                Text {
                    anchors.centerIn: parent
                    text: "󰝚"
                    font.family: Icons.effectiveFont("󰝚")
                    font.pixelSize: Fonts.scale(10)
                    color: Theme.muted
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
                    sourceSize.width: 36
                    sourceSize.height: 36
                    mipmap: true
                    smooth: true
                    layer.enabled: true

                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: miniArtMask
                    }

                }

            }

            Rectangle {
                anchors.fill: parent
                radius: Appearance.radiusSmall
                color: "transparent"
                border.color: "transparent"
                border.width: 0
                z: 2
            }

        }

        // ── 3. Audio Visualizer on Right Side (Matching Image 1) ──────────
        // 6 vertical white capsule bars, vertically centered along the midline
        Row {
            id: visualizerRow

            x: root.isVertical ? Math.round((parent.width - width) / 2) : Math.round(parent.width - width - 8)
            y: root.isVertical ? Math.round(parent.height - height - 6) : Math.round((parent.height - height) / 2)
            spacing: root.isVertical ? 2 : 2.5
            height: 16

            // Bar 0: Short (Base 6px)
            Rectangle {
                width: 2.5
                height: (root.controller && root.controller.isPlaying) ? 6 : 3.5
                radius: width / 2
                color: (root.controller && root.controller.isPlaying) ? Theme.accent : Theme.withAlpha(Theme.foreground, 0.35)
                anchors.verticalCenter: parent.verticalCenter

                Behavior on height {
                    enabled: !(root.controller && root.controller.isPlaying)

                    NumberAnimation {
                        duration: 240
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on color {
                    ColorAnimation {
                        duration: 200
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

            // Bar 1: Medium-High (Base 11px)
            Rectangle {
                width: 2.5
                height: (root.controller && root.controller.isPlaying) ? 11 : 4.5
                radius: width / 2
                color: (root.controller && root.controller.isPlaying) ? Theme.accent : Theme.withAlpha(Theme.foreground, 0.35)
                anchors.verticalCenter: parent.verticalCenter

                Behavior on height {
                    enabled: !(root.controller && root.controller.isPlaying)

                    NumberAnimation {
                        duration: 240
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on color {
                    ColorAnimation {
                        duration: 200
                    }

                }

                SequentialAnimation on height {
                    running: root.controller && root.controller.isPlaying
                    loops: Animation.Infinite

                    NumberAnimation {
                        to: 5
                        duration: 220
                        easing.type: Easing.InOutQuad
                    }

                    NumberAnimation {
                        to: 13
                        duration: 260
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

            // Bar 2: Highest Peak (Base 14px)
            Rectangle {
                width: 2.5
                height: (root.controller && root.controller.isPlaying) ? 14 : 5.5
                radius: width / 2
                color: (root.controller && root.controller.isPlaying) ? Theme.accent : Theme.withAlpha(Theme.foreground, 0.35)
                anchors.verticalCenter: parent.verticalCenter

                Behavior on height {
                    enabled: !(root.controller && root.controller.isPlaying)

                    NumberAnimation {
                        duration: 240
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on color {
                    ColorAnimation {
                        duration: 200
                    }

                }

                SequentialAnimation on height {
                    running: root.controller && root.controller.isPlaying
                    loops: Animation.Infinite

                    NumberAnimation {
                        to: 7
                        duration: 260
                        easing.type: Easing.InOutQuad
                    }

                    NumberAnimation {
                        to: 15
                        duration: 230
                        easing.type: Easing.InOutQuad
                    }

                    NumberAnimation {
                        to: 9
                        duration: 270
                        easing.type: Easing.InOutQuad
                    }

                    NumberAnimation {
                        to: 14
                        duration: 220
                        easing.type: Easing.InOutQuad
                    }

                }

            }

            // Bar 3: Medium-Short (Base 8px)
            Rectangle {
                width: 2.5
                height: (root.controller && root.controller.isPlaying) ? 8 : 4.5
                radius: width / 2
                color: (root.controller && root.controller.isPlaying) ? Theme.accent : Theme.withAlpha(Theme.foreground, 0.35)
                anchors.verticalCenter: parent.verticalCenter

                Behavior on height {
                    enabled: !(root.controller && root.controller.isPlaying)

                    NumberAnimation {
                        duration: 240
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on color {
                    ColorAnimation {
                        duration: 200
                    }

                }

                SequentialAnimation on height {
                    running: root.controller && root.controller.isPlaying
                    loops: Animation.Infinite

                    NumberAnimation {
                        to: 12
                        duration: 230
                        easing.type: Easing.InOutQuad
                    }

                    NumberAnimation {
                        to: 5
                        duration: 270
                        easing.type: Easing.InOutQuad
                    }

                    NumberAnimation {
                        to: 10
                        duration: 210
                        easing.type: Easing.InOutQuad
                    }

                    NumberAnimation {
                        to: 8
                        duration: 250
                        easing.type: Easing.InOutQuad
                    }

                }

            }

            // Bar 4: High (Base 12px)
            Rectangle {
                width: 2.5
                height: (root.controller && root.controller.isPlaying) ? 12 : 3.5
                radius: width / 2
                color: (root.controller && root.controller.isPlaying) ? Theme.accent : Theme.withAlpha(Theme.foreground, 0.35)
                anchors.verticalCenter: parent.verticalCenter

                Behavior on height {
                    enabled: !(root.controller && root.controller.isPlaying)

                    NumberAnimation {
                        duration: 240
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on color {
                    ColorAnimation {
                        duration: 200
                    }

                }

                SequentialAnimation on height {
                    running: root.controller && root.controller.isPlaying
                    loops: Animation.Infinite

                    NumberAnimation {
                        to: 5
                        duration: 250
                        easing.type: Easing.InOutQuad
                    }

                    NumberAnimation {
                        to: 14
                        duration: 220
                        easing.type: Easing.InOutQuad
                    }

                    NumberAnimation {
                        to: 8
                        duration: 260
                        easing.type: Easing.InOutQuad
                    }

                    NumberAnimation {
                        to: 12
                        duration: 240
                        easing.type: Easing.InOutQuad
                    }

                }

            }

            // Bar 5: High (Base 12px)
            Rectangle {
                width: 2.5
                height: (root.controller && root.controller.isPlaying) ? 12 : 3.5
                radius: width / 2
                color: (root.controller && root.controller.isPlaying) ? Theme.accent : Theme.withAlpha(Theme.foreground, 0.35)
                anchors.verticalCenter: parent.verticalCenter

                Behavior on height {
                    enabled: !(root.controller && root.controller.isPlaying)

                    NumberAnimation {
                        duration: 240
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on color {
                    ColorAnimation {
                        duration: 200
                    }

                }

                SequentialAnimation on height {
                    running: root.controller && root.controller.isPlaying
                    loops: Animation.Infinite

                    NumberAnimation {
                        to: 14
                        duration: 220
                        easing.type: Easing.InOutQuad
                    }

                    NumberAnimation {
                        to: 7
                        duration: 270
                        easing.type: Easing.InOutQuad
                    }

                    NumberAnimation {
                        to: 13
                        duration: 240
                        easing.type: Easing.InOutQuad
                    }

                    NumberAnimation {
                        to: 12
                        duration: 250
                        easing.type: Easing.InOutQuad
                    }

                }

            }

        }

        // ── 2. Album / Media Name in Middle ───────────────────────────────
        Text {
            id: titleText

            visible: !root.isVertical
            x: miniArtBox.x + miniArtBox.width + 7
            width: Math.max(0, visualizerRow.x - x - 7)
            anchors.verticalCenter: parent.verticalCenter
            text: root.trackTitle
            font.family: Fonts.uiFont
            font.pixelSize: Fonts.scale(11)
            font.weight: Fonts.weightBold
            color: Theme.foreground
            elide: Text.ElideRight
            maximumLineCount: 1
            horizontalAlignment: Text.AlignHCenter
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
