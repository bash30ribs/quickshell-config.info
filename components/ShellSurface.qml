import "../theme"
import QtQuick
import Quickshell
import Quickshell.Wayland

Item {
    id: root

    // Visual properties matching centralized appearance theme
    property color surfaceColor: Theme.barBackground
    property color borderColor: Theme.glassBorder
    property int borderWidth: 1
    property int surfaceRadius: Appearance.surfaceRadius > 0 ? Appearance.surfaceRadius : 16
    // Exposed reference to the visual container
    readonly property Item surfaceContainer: backgroundRect
    readonly property int cornerRadius: surfaceRadius
    // Default property allows child items placed inside ShellSurface to be reparented into contentContainer
    default property alias content: contentContainer.data

    GlassPanel {
        id: backgroundRect

        anchors.fill: parent
        radius: root.surfaceRadius
        baseColor: root.surfaceColor

        Item {
            id: contentContainer

            anchors.fill: parent
        }

    }

}
