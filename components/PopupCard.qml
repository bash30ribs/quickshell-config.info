import "../theme"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

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
    default property alias content: bodyContainer.data
    // Calculate card position relative to anchorItem across all 4 bar edges
    readonly property point popupPos: {
        var _ = root.open;
        var _e = Appearance.barEdge;
        return Appearance.computeBarPopupPos(root.anchorItem, root.contentWidth, root.contentHeight, Appearance.popupMargin, root.width, root.height);
    }
    readonly property real cardX: popupPos.x
    readonly property real cardY: popupPos.y

    function toggle() {
        if (Date.now() - root.lastClearedTime < 250) {
            root.closeAnimated();
            return ;
        }
        if (root.open) {
            root.closeAnimated();
        } else {
            root._animatingClose = false;
            root.open = true;
        }
    }

    function closeAnimated() {
        if (!root.open || root._animatingClose)
            return ;

        root._animatingClose = true;
        closeTimer.start();
    }

    visible: root.open
    color: "transparent"
    screen: (root.anchorItem && root.anchorItem.QsWindow && root.anchorItem.QsWindow.window) ? root.anchorItem.QsWindow.window.screen : null
    WlrLayershell.namespace: "quickshell-surface"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: root.open ? root.keyboardFocus : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    Timer {
        id: closeTimer

        interval: 105
        repeat: false
        onTriggered: {
            root._animatingClose = false;
            root.open = false;
        }
    }

    Connections {
        function onCloseBarPopups() {
            if (root.open)
                root.closeAnimated();

        }

        target: Appearance
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    HyprlandFocusGrab {
        active: false
        windows: [root]
        onCleared: {
            root.lastClearedTime = Date.now();
            root.closeAnimated();
        }
    }

    // Dismiss when clicking outside the card
    MouseArea {
        anchors.fill: parent
        onClicked: {
            root.lastClearedTime = Date.now();
            root.closeAnimated();
        }
    }

    // Dismiss when pressing Escape key
    Shortcut {
        enabled: root.open
        sequence: "Escape"
        onActivated: {
            root.lastClearedTime = Date.now();
            root.closeAnimated();
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Card Container with Mornye Liquid Glass Material Surface
    // (Compositor blur handles native background frosting without stacked layers)
    // ─────────────────────────────────────────────────────────────────────────
    GlassPanel {
        id: cardRect

        readonly property real slideOffset: root.isCardActive ? 0 : 16

        x: Math.round(root.cardX)
        y: Math.round(root.cardY)
        width: root.contentWidth
        height: root.contentHeight
        radius: Appearance.popupRadius > 0 ? Appearance.popupRadius : 14
        opacity: root.isCardActive ? 1 : 0
        scale: root.isCardActive ? 1 : 0.9
        transformOrigin: Appearance.barIsBottom ? Item.Bottom : (Appearance.barIsLeft ? Item.Left : (Appearance.barIsRight ? Item.Right : Item.Top))

        // Prevent clicks inside the card from closing the popup
        MouseArea {
            anchors.fill: parent
            propagateComposedEvents: true
            onClicked: function(mouse) {
                mouse.accepted = false;
            }
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

        transform: Translate {
            x: Appearance.barIsLeft ? -cardRect.slideOffset : (Appearance.barIsRight ? cardRect.slideOffset : 0)
            y: Appearance.barIsTop ? -cardRect.slideOffset : (Appearance.barIsBottom ? cardRect.slideOffset : 0)

            Behavior on x {
                NumberAnimation {
                    duration: root.isCardActive ? 160 : 100
                    easing.type: root.isCardActive ? Easing.OutQuart : Easing.InCubic
                }

            }

            Behavior on y {
                NumberAnimation {
                    duration: root.isCardActive ? 160 : 100
                    easing.type: root.isCardActive ? Easing.OutQuart : Easing.InCubic
                }

            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: root.isCardActive ? 130 : 95
                easing.type: root.isCardActive ? Easing.OutQuad : Easing.InCubic
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: root.isCardActive ? 165 : 100
                easing.type: root.isCardActive ? Easing.OutBack : Easing.InCubic
                easing.overshoot: root.isCardActive ? 1.16 : 1
            }

        }

    }

}
