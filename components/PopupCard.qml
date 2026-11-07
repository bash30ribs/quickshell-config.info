import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"

PanelWindow {
    id: root

    required property Item anchorItem
    property string title: ""
    property string icon: ""
    property bool open: false
    property int contentWidth: 320
    property int contentHeight: 280
    property bool showDefaultHeader: true
    property double lastClearedTime: 0
    property int keyboardFocus: WlrKeyboardFocus.None

    property bool _animatingClose: false
    readonly property bool isCardActive: root.open && !root._animatingClose

    function toggle() {
        if (Date.now() - root.lastClearedTime < 250) {
            root.closeAnimated()
            return
        }
        if (root.open) {
            root.closeAnimated()
        } else {
            root._animatingClose = false
            root.open = true
        }
    }

    function closeAnimated() {
        if (!root.open || root._animatingClose) return
        root._animatingClose = true
        closeTimer.start()
    }

    Timer {
        id: closeTimer
        interval: 130
        repeat: false
        onTriggered: {
            root._animatingClose = false
            root.open = false
        }
    }

    default property alias content: bodyContainer.data

    visible: root.open
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    screen: (root.anchorItem && root.anchorItem.QsWindow && root.anchorItem.QsWindow.window) ? root.anchorItem.QsWindow.window.screen : null

    WlrLayershell.namespace: "quickshell-surface"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: root.open ? root.keyboardFocus : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    HyprlandFocusGrab {
        active: false
        windows: [root]
        onCleared: {
            root.lastClearedTime = Date.now()
            root.closeAnimated()
        }
    }

    // Dismiss when clicking outside the card
    MouseArea {
        anchors.fill: parent
        onClicked: {
            root.lastClearedTime = Date.now()
            root.closeAnimated()
        }
    }

    // Dismiss when pressing Escape key
    Shortcut {
        enabled: root.open
        sequence: "Escape"
        onActivated: {
            root.lastClearedTime = Date.now()
            root.closeAnimated()
        }
    }

    // Calculate card position relative to anchorItem across different bar modes
    readonly property real cardX: {
        var _ = root.open // reactively recompute whenever popup opens
        if (!root.anchorItem) return Appearance.popupMargin

        var win = (root.anchorItem.QsWindow && root.anchorItem.QsWindow.window) ? root.anchorItem.QsWindow.window : null
        var screenW = (win && win.screen) ? win.screen.width : root.width

        // Compute bar window X position on screen
        var barScreenX = 0
        if (win) {
            if (win.anchors && win.anchors.left) {
                barScreenX = (win.margins && win.margins.left) ? win.margins.left : 0
            } else {
                // Compositor horizontally centers unanchored windows (compact & wide modes)
                barScreenX = Math.round((screenW - win.width) / 2)
            }
        }

        var pt = root.anchorItem.mapToItem(null, 0, 0)
        var itemCenterScreenX = barScreenX + pt.x + (root.anchorItem.width / 2)
        var desiredX = itemCenterScreenX - (root.contentWidth / 2)

        var margin = Appearance.popupMargin
        var maxRight = screenW - root.contentWidth - margin
        return Math.max(margin, Math.min(desiredX, maxRight))
    }

    readonly property real cardY: {
        var _ = root.open // reactively recompute whenever popup opens
        if (!root.anchorItem) return Appearance.barHeight + 6

        var win = (root.anchorItem.QsWindow && root.anchorItem.QsWindow.window) ? root.anchorItem.QsWindow.window : null
        var barScreenY = 0
        if (win && win.margins && win.margins.top) {
            barScreenY = win.margins.top
        }

        var pt = root.anchorItem.mapToItem(null, 0, 0)
        var itemBottomScreenY = barScreenY + pt.y + root.anchorItem.height
        return Math.max(Appearance.barHeight + 6, itemBottomScreenY + 6)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Card Container with Mornye Liquid Glass Material Surface
    // (Compositor blur handles native background frosting without stacked layers)
    // ─────────────────────────────────────────────────────────────────────────
    GlassPanel {
        id: cardRect
        x: Math.round(root.cardX)
        y: Math.round(root.cardY) + (root.isCardActive ? 0 : -12)
        width: root.contentWidth
        height: root.contentHeight
        radius: Appearance.popupRadius > 0 ? Appearance.popupRadius : 14

        opacity: root.isCardActive ? 1.0 : 0.0
        scale: root.isCardActive ? 1.0 : 0.85
        transformOrigin: Item.Top

        Behavior on y {
            NumberAnimation {
                duration: root.isCardActive ? 190 : 120
                easing.type: root.isCardActive ? Easing.OutBack : Easing.InCubic
                easing.overshoot: 1.15
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: root.isCardActive ? 160 : 110
                easing.type: root.isCardActive ? Easing.OutQuad : Easing.InQuad
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: root.isCardActive ? 190 : 120
                easing.type: root.isCardActive ? Easing.OutBack : Easing.InCubic
                easing.overshoot: root.isCardActive ? 1.32 : 1.0
            }
        }

        // Prevent clicks inside the card from closing the popup
        MouseArea {
            anchors.fill: parent
            propagateComposedEvents: true
            onClicked: function(mouse) { mouse.accepted = false }
        }

        // Card Header (Optional, default true)
        Item {
            id: headerRect
            visible: root.showDefaultHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.showDefaultHeader ? Appearance.popupHeaderHeight : 0

            // Hairline glass border of header
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: Appearance.borderWidthThin
                color: Qt.rgba(1, 1, 1, 0.14)
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Appearance.spacingLarge
                anchors.verticalCenter: parent.verticalCenter
                spacing: Appearance.spacingMedium

                Text {
                    visible: root.icon.length > 0
                    text: root.icon
                    font.family: Icons.effectiveFont(root.icon)
                    font.pixelSize: Fonts.sizeMedium
                    color: Theme.accent
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: root.title
                    font.family: Fonts.uiFont
                    font.pixelSize: Fonts.sizeMedium
                    font.weight: Fonts.weightBold
                    color: Theme.foreground
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // Body Content Container
        Item {
            id: bodyContainer
            anchors.top: root.showDefaultHeader ? headerRect.bottom : parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: root.showDefaultHeader ? Appearance.paddingMedium : Appearance.popupPadding
        }
    }
}
