import QtQuick
import Quickshell
import "../theme"

Rectangle {
    id: root

    // ─────────────────────────────────────────────────────────────────────────
    // Mornye Selection Pill Specification (mornye_selection_pill.dart)
    // Fluid Animated Selection Background Indicator
    // ─────────────────────────────────────────────────────────────────────────

    property int targetX: 0
    property int targetWidth: 0
    property color pillColor: Theme.withAlpha(Theme.accent, 0.22)
    property color rimColor: Theme.withAlpha(Theme.accent, 0.50)
    property int pillRadius: height / 2

    x: targetX
    width: targetWidth
    radius: pillRadius
    color: pillColor
    border.color: rimColor
    border.width: 1
    antialiasing: true

    // Smooth Spring Animation on Position & Width Transitions
    Behavior on x {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
        }
    }

    Behavior on width {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    // Top diffuse specular sheen
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.max(3, parent.height * 0.4)
        radius: parent.radius
        antialiasing: true
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.12) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
}
