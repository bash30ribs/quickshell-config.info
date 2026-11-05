import QtQuick
import Quickshell
import "../theme"

Item {
    id: root

    readonly property var window: QsWindow.window

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

    // Precision frosted glass tile chassis
    Rectangle {
        id: glassBg
        anchors.fill: parent
        radius: root.radius
        antialiasing: true

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: {
                    if (root.active) return Theme.withAlpha(Theme.accent, 0.32)
                    if (mouseArea.containsMouse) return Qt.rgba(1, 1, 1, 0.22)
                    return Qt.rgba(1, 1, 1, 0.10)
                }
            }
            GradientStop {
                position: 1.0
                color: {
                    if (root.active) return Theme.withAlpha(Theme.accent, 0.14)
                    if (mouseArea.containsMouse) return Qt.rgba(1, 1, 1, 0.08)
                    return Qt.rgba(1, 1, 1, 0.03)
                }
            }
        }

        border.color: {
            if (root.active) return Theme.glassActiveBorder
            if (mouseArea.containsMouse) return Theme.glassHoverBorder
            return Theme.glassWidgetBorder
        }
        border.width: 1

        Behavior on border.color {
            ColorAnimation { duration: Appearance.animDurationNormal }
        }

        // Top specular edge highlight
        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: 1
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Math.max(3, root.radius / 2)
            anchors.rightMargin: Math.max(3, root.radius / 2)
            height: 1
            color: {
                if (root.active) return Theme.withAlpha(Theme.accent, 0.85)
                if (mouseArea.containsMouse) return Qt.rgba(1, 1, 1, 0.65)
                return Qt.rgba(1, 1, 1, 0.32)
            }
            antialiasing: true

            Behavior on color {
                ColorAnimation { duration: Appearance.animDurationNormal }
            }
        }

        // Inner diffuse glass sheen
        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: 2
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Math.max(3, root.radius / 2)
            anchors.rightMargin: Math.max(3, root.radius / 2)
            height: Math.min(6, parent.height / 3)
            antialiasing: true
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: {
                        if (root.active) return Theme.withAlpha(Theme.accent, 0.25)
                        if (mouseArea.containsMouse) return Qt.rgba(1, 1, 1, 0.18)
                        return Qt.rgba(1, 1, 1, 0.08)
                    }
                }
                GradientStop {
                    position: 1.0
                    color: "transparent"
                }
            }
        }
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Appearance.spacingMedium - 2 // 6px

        Text {
            visible: root.icon.length > 0
            text: root.icon
            font.family: Icons.effectiveFont(root.icon)
            font.pixelSize: root.iconSize
            color: {
                if (root.accentActive || root.active) return Theme.accent
                if (root.customColor.a > 0) return root.customColor
                return Theme.foreground
            }
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color {
                ColorAnimation { duration: Appearance.animDurationNormal }
            }
        }

        Text {
            visible: root.text.length > 0
            text: root.text
            font.family: Fonts.uiFont
            font.pixelSize: root.textSize
            font.bold: root.active
            color: root.active ? Theme.accent : Theme.foreground
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color {
                ColorAnimation { duration: Appearance.animDurationNormal }
            }
        }
    }

    // Active bottom indicator line
    Rectangle {
        visible: root.active
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - 6, 14)
        height: 2
        radius: 1
        color: Theme.accent

        Behavior on color {
            ColorAnimation { duration: Appearance.animDurationNormal }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
