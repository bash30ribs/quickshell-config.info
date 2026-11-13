import "../services"
import "../theme"
import QtQuick

// Workspace switcher container on the glass bar
Item {
    id: root

    required property WorkspacesService service
    readonly property bool isVertical: Appearance.barIsVertical
    readonly property int capsuleThickness: Appearance.barButtonHeight - (Appearance.workspacesPaddingVertical * 2)

    implicitHeight: root.isVertical ? (wsRow.implicitHeight + (Appearance.workspacesPaddingHorizontal * 2)) : Appearance.barButtonHeight
    implicitWidth: root.isVertical ? Math.max(Appearance.barButtonHeight, Appearance.barThickness - 10) : (wsRow.implicitWidth + (Appearance.workspacesPaddingHorizontal * 2))
    width: implicitWidth
    height: implicitHeight

    WheelHandler {
        onWheel: (event) => {
            if (event.angleDelta.y < 0)
                root.service.next();
            else if (event.angleDelta.y > 0)
                root.service.prev();
        }
    }

    Grid {
        id: wsRow

        anchors.centerIn: parent
        columns: root.isVertical ? 1 : 24
        columnSpacing: Appearance.workspacesSpacing
        rowSpacing: Appearance.workspacesSpacing
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

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

                height: root.isVertical ? (isActive ? Math.max(30, Appearance.workspacesActiveCapsuleWidth - 12) : root.capsuleThickness) : root.capsuleThickness
                width: root.isVertical ? root.capsuleThickness : (isActive ? Appearance.workspacesActiveCapsuleWidth : Appearance.workspacesCapsuleWidth)
                radius: Math.min(width, height) / 2
                antialiasing: true
                color: {
                    if (isActive)
                        return Theme.accent;

                    if (wsMouse.containsMouse)
                        return Theme.withAlpha(Theme.accent, 0.2);

                    return "transparent";
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
                    color: Theme.bright_foreground
                    opacity: wsCapsule.isOccupied ? 0.95 : 0.4
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
                    color: Theme.bright_foreground
                    opacity: wsCapsule.isOccupied ? 0.95 : 0.4
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
                    enabled: !Appearance.barTransitioning

                    NumberAnimation {
                        duration: Appearance.animDurationNormal
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on height {
                    enabled: !Appearance.barTransitioning

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
