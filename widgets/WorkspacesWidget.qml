import "../services"
import "../theme"
import QtQuick

// Workspace switcher container on the glass bar
Item {
    id: root

    required property WorkspacesService service

    implicitHeight: Appearance.barButtonHeight
    implicitWidth: wsRow.implicitWidth + (Appearance.workspacesPaddingHorizontal * 2)

    WheelHandler {
        onWheel: (event) => {
            if (event.angleDelta.y < 0)
                root.service.next();
            else if (event.angleDelta.y > 0)
                root.service.prev();
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
                readonly property string resolvedInactiveIcon: {
                    if (isOccupied && Icons.workspaceOccupied && Icons.workspaceOccupied.length > 0)
                        return Icons.workspaceOccupied;

                    if (!isOccupied && Icons.workspaceEmpty && Icons.workspaceEmpty.length > 0)
                        return Icons.workspaceEmpty;

                    return Icons.workspaceInactive || "";
                }
                readonly property bool hasCustomInactiveIcon: resolvedInactiveIcon.length > 0

                height: parent.height
                width: isActive ? Appearance.workspacesActiveCapsuleWidth : Appearance.workspacesCapsuleWidth
                radius: height / 2
                antialiasing: true
                color: {
                    if (isActive)
                        return Theme.accent;

                    if (wsMouse.containsMouse)
                        return Qt.rgba(1, 1, 1, 0.22);

                    return Qt.rgba(0, 0, 0, 0.28);
                }
                border.width: 0
                border.color: "transparent"

                // Inactive workspace indicator: circular dot
                Rectangle {
                    id: dot

                    anchors.centerIn: parent
                    width: Appearance.workspacesDotSize
                    height: Appearance.workspacesDotSize
                    radius: width / 2
                    visible: !wsCapsule.isActive && !wsCapsule.hasCustomInactiveIcon
                    color: "#ffffff"
                    opacity: wsCapsule.isOccupied ? 1 : 0.35
                    antialiasing: true

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.animDurationNormal
                        }

                    }

                }

                // Inactive workspace indicator: custom glyph
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
                    opacity: wsCapsule.isOccupied ? 1 : 0.35
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.animDurationNormal
                        }

                    }

                }

                // Active workspace indicator: icon
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

            }

        }

    }

}
