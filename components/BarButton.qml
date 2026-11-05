import QtQuick
import Quickshell
import "../theme"

Rectangle {
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

    signal clicked()

    implicitWidth: Math.max(Appearance.barButtonHeight, contentRow.implicitWidth + (customPadding * 2))
    implicitHeight: Appearance.barButtonHeight
    width: implicitWidth
    height: implicitHeight
    radius: Appearance.buttonRadius > 0 ? Appearance.buttonRadius : 6
    antialiasing: true

    // Merged into the bar at rest; Apple-grade frosted glass pill on hover/active
    color: {
        if (root.active) return Theme.withAlpha(Theme.accent, 0.25)
        if (mouseArea.containsMouse) return Theme.withAlpha(Theme.glassCrest, 0.14)
        return "transparent"
    }

    border.color: {
        if (root.active) return Theme.withAlpha(Theme.accent, 0.65)
        if (mouseArea.containsMouse) return Theme.withAlpha(Theme.glassCrest, 0.28)
        return "transparent"
    }
    border.width: (root.active || mouseArea.containsMouse) ? 1 : 0

    Behavior on color {
        ColorAnimation { duration: Appearance.animDurationNormal }
    }
    Behavior on border.color {
        ColorAnimation { duration: Appearance.animDurationNormal }
    }

    // Top specular highlight (visible only on hover or active)
    Rectangle {
        visible: root.active || mouseArea.containsMouse
        anchors.top: parent.top
        anchors.topMargin: 1
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Math.max(3, root.radius / 2)
        anchors.rightMargin: Math.max(3, root.radius / 2)
        height: 1
        color: root.active ? Theme.withAlpha(Theme.accent, 0.85) : Theme.withAlpha(Theme.glassCrest, 0.50)
        antialiasing: true

        Behavior on color {
            ColorAnimation { duration: Appearance.animDurationNormal }
        }
    }

    // Inner subtle sheen on hover/active
    Rectangle {
        visible: root.active || mouseArea.containsMouse
        anchors.top: parent.top
        anchors.topMargin: 2
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Math.max(3, root.radius / 2)
        anchors.rightMargin: Math.max(3, root.radius / 2)
        height: Math.min(5, parent.height / 3)
        antialiasing: true
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: root.active ? Theme.withAlpha(Theme.accent, 0.22) : Theme.withAlpha(Theme.glassCrest, 0.15)
            }
            GradientStop {
                position: 1.0
                color: "transparent"
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
