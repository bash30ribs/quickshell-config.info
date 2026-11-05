import QtQuick
import "../theme"
import "../services"

// Outer container for workspaces on the bar
Rectangle {
    id: root

    required property WorkspacesService service

    implicitHeight: Appearance.barButtonHeight
    implicitWidth: wsRow.implicitWidth + (Appearance.workspacesPaddingHorizontal * 2)
    radius: Appearance.buttonRadius > 0 ? Appearance.buttonRadius : 8
    antialiasing: true

    gradient: Gradient {
        GradientStop { position: 0.0; color: Theme.withAlpha(Theme.glassCrest, 0.20) }
        GradientStop { position: 1.0; color: Theme.withAlpha(Theme.glassSurface, 0.18) }
    }
    border.color: Theme.glassWidgetBorder
    border.width: 1

    // Top specular edge highlight
    Rectangle {
        anchors.top: parent.top
        anchors.topMargin: 1
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Math.max(3, root.radius / 2)
        anchors.rightMargin: Math.max(3, root.radius / 2)
        height: 1
        color: Theme.withAlpha(Theme.glassCrest, 0.45)
        antialiasing: true
    }

    // Inner diffuse glass sheen
    Rectangle {
        anchors.top: parent.top
        anchors.topMargin: 2
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Math.max(3, root.radius / 2)
        anchors.rightMargin: Math.max(3, root.radius / 2)
        height: 5
        antialiasing: true
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.withAlpha(Theme.glassTint, 0.15) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    WheelHandler {
        onWheel: (event) => {
            if (event.angleDelta.y < 0) {
                root.service.next()
            } else if (event.angleDelta.y > 0) {
                root.service.prev()
            }
        }
    }

    Row {
        id: wsRow
        anchors.centerIn: parent
        spacing: Appearance.workspacesSpacing
        height: parent.height - (Appearance.workspacesPaddingVertical * 2)

        Repeater {
            model: root.service.workspaceIds

            Rectangle {
                id: wsCapsule
                required property int modelData

                readonly property bool isActive: root.service.activeWorkspaceId === modelData
                readonly property bool isOccupied: !!root.service.occupiedWorkspaces[modelData]

                height: parent.height
                width: isActive ? Appearance.workspacesActiveCapsuleWidth : Appearance.workspacesCapsuleWidth
                radius: height / 2
                antialiasing: true

                color: {
                    if (isActive) return Theme.accent
                    if (wsMouse.containsMouse) return Qt.rgba(1, 1, 1, 0.20)
                    return Qt.rgba(1, 1, 1, 0.08)
                }
                border.color: isActive ? Qt.rgba(1, 1, 1, 0.50) : (wsMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : "transparent")
                border.width: 1

                // Top specular highlight on active workspace
                Rectangle {
                    visible: wsCapsule.isActive
                    anchors.top: parent.top
                    anchors.topMargin: 1
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 2
                    anchors.rightMargin: 2
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.60)
                    antialiasing: true
                }

                Behavior on width {
                    NumberAnimation {
                        duration: Appearance.animDurationNormal
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.animDurationNormal
                    }
                }

                readonly property string resolvedInactiveIcon: {
                    if (isOccupied && Icons.workspaceOccupied && Icons.workspaceOccupied.length > 0) return Icons.workspaceOccupied
                    if (!isOccupied && Icons.workspaceEmpty && Icons.workspaceEmpty.length > 0) return Icons.workspaceEmpty
                    return Icons.workspaceInactive || ""
                }
                readonly property bool hasCustomInactiveIcon: resolvedInactiveIcon.length > 0

                // Inactive workspace indicator: circular dot (shown when no custom icon is configured)
                Rectangle {
                    id: dot
                    anchors.centerIn: parent
                    width: Appearance.workspacesDotSize
                    height: Appearance.workspacesDotSize
                    radius: width / 2
                    visible: !wsCapsule.isActive && !wsCapsule.hasCustomInactiveIcon
                    color: "#ffffff"
                    opacity: wsCapsule.isOccupied ? 1.0 : 0.28
                    antialiasing: true

                    Behavior on opacity {
                        NumberAnimation { duration: Appearance.animDurationNormal }
                    }
                }

                // Inactive workspace indicator: custom glyph defined in Icons.qml
                Text {
                    id: inactiveIcon
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: Appearance.workspacesIconOffsetX
                    anchors.verticalCenterOffset: Appearance.workspacesIconOffsetY
                    visible: !wsCapsule.isActive && wsCapsule.hasCustomInactiveIcon
                    text: wsCapsule.resolvedInactiveIcon
                    font.family: Icons.effectiveFont(text)
                    font.pixelSize: Appearance.workspacesInactiveIconSize
                    color: "#ffffff"
                    opacity: wsCapsule.isOccupied ? 1.0 : 0.28
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter

                    Behavior on opacity {
                        NumberAnimation { duration: Appearance.animDurationNormal }
                    }
                }

                // Active workspace indicator: user manual icon defined in Icons.qml
                Text {
                    id: activeIcon
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: Appearance.workspacesIconOffsetX
                    anchors.verticalCenterOffset: Appearance.workspacesIconOffsetY
                    visible: wsCapsule.isActive
                    text: Icons.workspaceActive || Icons.workspace
                    font.family: Icons.effectiveFont(text)
                    font.pixelSize: Appearance.workspacesIconSize
                    color: Theme.dark_background
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                }

                MouseArea {
                    id: wsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.service.switchTo(wsCapsule.modelData)
                }
            }
        }
    }
}
