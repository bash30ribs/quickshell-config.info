import "../theme"
import QtQuick
import Quickshell

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
    property bool vertical: Appearance.barIsVertical
    readonly property int buttonSize: root.vertical ? Math.max(28, Appearance.barThickness - 10) : Math.max(Appearance.barButtonHeight, Appearance.barThickness - 10)

    signal clicked()

    implicitWidth: root.vertical ? root.buttonSize : Math.max(Appearance.barButtonHeight, contentGrid.implicitWidth + (customPadding * 2))
    implicitHeight: root.vertical ? root.buttonSize : Appearance.barButtonHeight
    width: implicitWidth
    height: implicitHeight
    radius: Appearance.buttonRadius > 0 ? (root.vertical ? Appearance.radiusSmall : Appearance.buttonRadius) : 8
    antialiasing: true
    // Spring hover elevation & press compression (matching GlassButton)
    scale: mouseArea.pressed ? 0.96 : (mouseArea.containsMouse ? 1.025 : 1)
    // Borderless bar button: clean transparent resting state, soft frosted glass highlight on hover, subtle translucent accent wash when active
    color: {
        if (root.active)
            return Theme.withAlpha(Theme.accent, 0.18);

        if (mouseArea.containsMouse)
            return Theme.withAlpha(Theme.accent, 0.1);

        return "transparent";
    }
    border.width: 0
    border.color: "transparent"

    Grid {
        id: contentGrid

        anchors.centerIn: parent
        columns: root.vertical ? 1 : 2
        columnSpacing: Appearance.spacingMedium - 2 // 6px
        rowSpacing: 0
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        Text {
            visible: root.icon.length > 0
            text: root.icon
            font.family: Icons.effectiveFont(root.icon)
            font.pixelSize: root.iconSize
            color: {
                if (root.accentActive || root.active)
                    return Theme.accent;

                if (root.customColor.a > 0)
                    return root.customColor;

                return Theme.bright_foreground;
            }

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.animDurationNormal
                }

            }

        }

        Text {
            visible: !root.vertical && root.text.length > 0
            text: root.text
            font.family: Fonts.uiFont
            font.pixelSize: root.textSize
            font.bold: root.active
            font.weight: root.active ? Font.Bold : Font.Medium
            font.letterSpacing: 0.15
            horizontalAlignment: Text.AlignHCenter
            color: root.active ? Theme.accent : Theme.bright_foreground

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.animDurationNormal
                }

            }

        }

    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Behavior on scale {
        NumberAnimation {
            duration: mouseArea.pressed ? 70 : 185
            easing.type: mouseArea.pressed ? Easing.OutQuad : Easing.OutBack
            easing.overshoot: mouseArea.pressed ? 1 : 1.25
        }

    }

    Behavior on color {
        ColorAnimation {
            duration: 130
        }

    }

}
