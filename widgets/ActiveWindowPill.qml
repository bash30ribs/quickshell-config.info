import "../components"
import "../theme"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

Item {
    id: root

    readonly property bool isVertical: Appearance.barIsVertical
    readonly property var activeTop: Hyprland.activeToplevel
    readonly property string rawTitle: activeTop ? (activeTop.title || "") : ""
    readonly property string rawAppId: activeTop ? (activeTop.appId || "") : ""
    readonly property bool hasWindow: rawTitle.length > 0 || rawAppId.length > 0
    // Display title formatted cleanly
    readonly property string displayTitle: {
        if (!hasWindow)
            return "";

        var t = rawTitle.trim();
        // Remove common redundant prefixes/suffixes if present
        return t;
    }
    // App glyph
    readonly property string glyph: Icons.appGlyph(rawAppId, rawTitle)
    readonly property string glyphFont: Icons.effectiveFont(glyph)

    implicitHeight: isVertical ? (hasWindow ? Appearance.barButtonHeight : 0) : Appearance.barButtonHeight
    implicitWidth: isVertical ? (hasWindow ? Appearance.barButtonHeight : 0) : (hasWindow ? Math.min(320, Math.max(42, titleMeasure.implicitWidth + 48)) : 0)
    width: implicitWidth
    height: implicitHeight
    visible: width > 0 && opacity > 0
    opacity: hasWindow ? 1 : 0

    // Hidden text measuring component for dynamic fluid pill expansion
    Text {
        id: titleMeasure

        text: root.displayTitle
        font.family: Fonts.uiFont
        font.pixelSize: Fonts.scale(11)
        font.weight: Fonts.weightMedium
        visible: false
    }

    // Mornye Glass Capsule
    Rectangle {
        id: pillBg

        anchors.fill: parent
        radius: Math.min(width, height) / 2
        antialiasing: true
        color: pillMouse.containsMouse ? Theme.withAlpha(Theme.glassCrest, 0.16) : Theme.withAlpha(Theme.glassCrest, 0.08)
        border.color: pillMouse.containsMouse ? Theme.withAlpha(Theme.accent, 0.5) : Theme.withAlpha(Theme.glassBorderColor, 0.22)
        border.width: 1
        scale: pillMouse.pressed ? 0.96 : (pillMouse.containsMouse ? 1.025 : 1)

        // Optical Rim Specular Highlight (Mornye signature)
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 1
            height: 1
            radius: parent.radius
            color: Theme.withAlpha(Theme.glassRim, 0.35)
            opacity: pillMouse.containsMouse ? 0.8 : 0.4
        }

        Row {
            anchors.centerIn: parent
            spacing: 8
            visible: !root.isVertical

            // App Icon Glyph
            Text {
                id: iconText

                text: root.glyph
                font.family: root.glyphFont
                font.pixelSize: Fonts.scale(13)
                color: pillMouse.containsMouse ? Theme.accent : Theme.bright_foreground
                anchors.verticalCenter: parent.verticalCenter

                Behavior on color {
                    ColorAnimation {
                        duration: 140
                    }

                }

            }

            // Window Title
            Text {
                id: labelText

                text: root.displayTitle
                font.family: Fonts.uiFont
                font.pixelSize: Fonts.scale(11)
                font.weight: Fonts.weightMedium
                color: Theme.foreground
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                maximumLineCount: 1
                width: Math.min(230, implicitWidth)
                clip: true
            }

        }

        // Vertical Bar Presentation (Compact 38x38 Icon)
        Text {
            anchors.centerIn: parent
            visible: root.isVertical
            text: root.glyph
            font.family: root.glyphFont
            font.pixelSize: Fonts.scale(14)
            color: pillMouse.containsMouse ? Theme.accent : Theme.bright_foreground

            Behavior on color {
                ColorAnimation {
                    duration: 140
                }

            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutQuad
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: 160
            }

        }

        Behavior on border.color {
            ColorAnimation {
                duration: 160
            }

        }

    }

    MouseArea {
        id: pillMouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                // Focus / activate active window or toggle floating
                if (root.activeTop && typeof root.activeTop.activate === "function")
                    root.activeTop.activate();
                else
                    Hyprland.dispatch("togglefloating active");
            } else if (mouse.button === Qt.RightButton) {
                // Right-click: toggle fullscreen
                Hyprland.dispatch("fullscreen 1");
            } else if (mouse.button === Qt.MiddleButton) {
                // Middle-click: close active window
                if (root.activeTop && typeof root.activeTop.close === "function")
                    root.activeTop.close();
                else
                    Hyprland.dispatch("killactive");
            }
        }
    }

    // Hyprland rawEvent listener to refresh instantly upon window changes
    Connections {
        function onRawEvent(event) {
            if (event.name === "activewindow" || event.name === "activewindowv2" || event.name === "closewindow" || event.name === "movewindow")
                Hyprland.refreshToplevels();

        }

        target: Hyprland
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }

    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
        }

    }

    Behavior on implicitHeight {
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
        }

    }

}
