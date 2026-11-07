import QtQuick
import Quickshell
import "../theme"

Item {
    id: root

    property string icon: ""
    property string text: ""
    property bool active: false
    property bool accentActive: false
    property color customColor: "transparent"
    property int customPadding: Appearance.buttonPadding
    property int iconSize: Icons.sizeNormal
    property int textSize: Fonts.sizeRegular
    property int radius: Appearance.buttonRadius > 0 ? Appearance.buttonRadius : 8

    signal clicked()

    implicitWidth: Math.max(Appearance.barButtonHeight, contentRow.implicitWidth + (customPadding * 2))
    implicitHeight: Appearance.barButtonHeight
    width: implicitWidth
    height: implicitHeight

    // ─────────────────────────────────────────────────────────────────────────
    // Mornye Spring Physics Scale & Compression (mornye_glass_press.dart)
    // Mass: 1, Stiffness: 420, Damping: 24
    // ─────────────────────────────────────────────────────────────────────────
    scale: {
        if (mouseArea.pressed) return 0.965
        if (mouseArea.containsMouse) return 1.025
        return 1.0
    }

    Behavior on scale {
        NumberAnimation {
            duration: mouseArea.pressed ? 70 : 180
            easing.type: mouseArea.pressed ? Easing.OutQuad : Easing.OutBack
            easing.overshoot: mouseArea.pressed ? 1.0 : 1.25
        }
    }

    // Glass Button Surface
    Rectangle {
        id: buttonBg
        anchors.fill: parent
        radius: root.radius
        antialiasing: true

        // Responsive Mornye Glass Fills
        color: {
            if (root.active) return Theme.withAlpha(Theme.accent, 0.22)
            if (mouseArea.containsMouse) return Qt.rgba(1, 1, 1, 0.10)
            return "transparent"
        }

        // Illuminated Rim Edge
        border.color: {
            if (root.active) return Theme.withAlpha(Theme.accent, 0.55)
            if (mouseArea.containsMouse) return Qt.rgba(1, 1, 1, 0.22)
            return "transparent"
        }
        border.width: (root.active || mouseArea.containsMouse) ? 1 : 0

        Behavior on color {
            ColorAnimation { duration: 140 }
        }
        Behavior on border.color {
            ColorAnimation { duration: 140 }
        }

        // Top specular sheen on hover/active
        Rectangle {
            visible: mouseArea.containsMouse || root.active
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Math.max(4, parent.height * 0.35)
            radius: parent.radius
            antialiasing: true
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Qt.rgba(1, 1, 1, root.active ? 0.15 : 0.08)
                }
                GradientStop {
                    position: 1.0
                    color: "transparent"
                }
            }
        }

        // Button Content Row
        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: Appearance.spacingMedium - 2

            Text {
                visible: root.icon.length > 0
                text: root.icon
                font.family: Icons.effectiveFont(root.icon)
                font.pixelSize: root.iconSize
                color: {
                    if (root.accentActive || root.active) return Theme.accent
                    if (root.customColor.a > 0) return root.customColor
                    return Theme.glassText
                }
                anchors.verticalCenter: parent.verticalCenter

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }
            }

            Text {
                visible: root.text.length > 0
                text: root.text
                font.family: Fonts.uiFont
                font.pixelSize: root.textSize
                font.bold: root.active
                color: root.active ? Theme.accent : Theme.glassText
                anchors.verticalCenter: parent.verticalCenter

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }
            }
        }

        // Active bottom indicator dot
        Rectangle {
            visible: root.active
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 3
            anchors.horizontalCenter: parent.horizontalCenter
            width: 14
            height: 2
            radius: 1
            color: Theme.accent
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
        }
    }
}
