import "../theme"
import QtQuick

Item {
    id: root

    required property string glyph
    property int buttonSize: 28
    property int glyphSize: 14
    property real cornerRadius: 7
    property bool active: false
    property bool destructive: false
    property bool darkSurface: false

    signal clicked()

    width: root.buttonSize
    height: root.buttonSize
    implicitWidth: root.buttonSize
    implicitHeight: root.buttonSize

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: {
            if (root.active)
                return Theme.withAlpha(Theme.accent, root.darkSurface ? 0.28 : 0.16);

            if (mouseArea.containsMouse)
                return root.destructive ? Theme.withAlpha(Theme.urgent, root.darkSurface ? 0.35 : 0.16) : Theme.withAlpha(Theme.bright_foreground, root.darkSurface ? 0.14 : 0.08);

            return "transparent";
        }

        Behavior on color {
            ColorAnimation {
                duration: 110
            }

        }

    }

    Text {
        anchors.centerIn: parent
        text: root.glyph
        font.family: Icons.effectiveFont(root.glyph)
        font.pixelSize: root.glyphSize
        color: {
            if (root.active)
                return Theme.accent;

            if (root.destructive)
                return mouseArea.containsMouse ? Theme.urgent : (root.darkSurface ? Theme.bright_foreground : Theme.muted);

            return mouseArea.containsMouse ? Theme.bright_foreground : (root.darkSurface ? Theme.withAlpha(Theme.bright_foreground, 0.85) : Theme.muted);
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
