import "../theme"
import QtQuick

Item {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property color activeColor: Theme.accent

    signal clicked()

    implicitWidth: 175
    implicitHeight: 52

    Rectangle {
        id: bg

        anchors.fill: parent
        radius: 14
        antialiasing: true
        color: root.active ? Theme.withAlpha(root.activeColor, tileMouse.containsMouse ? 0.24 : 0.16) : (tileMouse.containsMouse ? Theme.withAlpha(Theme.glassCrest, 0.14) : Theme.withAlpha(Theme.glassCrest, 0.07))
        border.color: root.active ? Theme.withAlpha(root.activeColor, 0.5) : (tileMouse.containsMouse ? Theme.withAlpha(Theme.glassBorderColor, 0.35) : Theme.withAlpha(Theme.glassBorderColor, 0.18))
        border.width: 1
        scale: tileMouse.pressed ? 0.96 : (tileMouse.containsMouse ? 1.02 : 1)

        // Top specular rim highlight
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 1
            height: 1
            radius: parent.radius
            color: Theme.withAlpha(Theme.glassRim, 0.3)
            opacity: root.active ? 0.7 : 0.35
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10
            anchors.verticalCenter: parent.verticalCenter

            // Icon Capsule
            Rectangle {
                width: 34
                height: 34
                radius: 17
                anchors.verticalCenter: parent.verticalCenter
                color: root.active ? root.activeColor : Theme.withAlpha(Theme.dark_background, 0.6)
                border.color: root.active ? "transparent" : Theme.withAlpha(Theme.glassBorderColor, 0.2)
                border.width: root.active ? 0 : 1

                Text {
                    anchors.centerIn: parent
                    text: root.icon
                    font.family: Icons.effectiveFont(root.icon)
                    font.pixelSize: Fonts.scale(14)
                    color: root.active ? Theme.background : (tileMouse.containsMouse ? Theme.bright_foreground : Theme.foreground)

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }

                    }

                }

                Behavior on color {
                    ColorAnimation {
                        duration: 180
                    }

                }

            }

            // Labels
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 44
                spacing: 1

                Text {
                    text: root.title
                    font.family: Fonts.uiFont
                    font.pixelSize: Fonts.scale(11)
                    font.weight: Fonts.weightBold
                    color: root.active ? Theme.bright_foreground : Theme.foreground
                    elide: Text.ElideRight
                    width: parent.width
                }

                Text {
                    text: root.subtitle
                    font.family: Fonts.uiFont
                    font.pixelSize: Fonts.scale(9)
                    color: root.active ? Theme.accent : Theme.glassLabel
                    elide: Text.ElideRight
                    width: parent.width
                }

            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: 180
            }

        }

        Behavior on border.color {
            ColorAnimation {
                duration: 180
            }

        }

    }

    MouseArea {
        id: tileMouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

}
