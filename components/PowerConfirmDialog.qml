import "../services"
import "../theme"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: root

    required property PowerService powerService
    readonly property bool isOpen: root.powerService && root.powerService.confirmOpen
    property real animProgress: 0

    onIsOpenChanged: {
        if (root.isOpen) {
            closeAnim.stop();
            openAnim.restart();
        } else {
            openAnim.stop();
            closeAnim.restart();
        }
    }
    visible: root.isOpen || root.animProgress > 0.001
    screen: (root.powerService && root.powerService.targetScreen) ? root.powerService.targetScreen : null
    color: "transparent"
    WlrLayershell.namespace: "quickshell-confirm"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.isOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    onVisibleChanged: {
        if (visible)
            keyHandler.forceActiveFocus();

    }

    NumberAnimation {
        id: openAnim

        target: root
        property: "animProgress"
        from: root.animProgress
        to: 1
        duration: 210
        easing.type: Easing.OutBack
        easing.overshoot: 1.1
    }

    NumberAnimation {
        id: closeAnim

        target: root
        property: "animProgress"
        from: root.animProgress
        to: 0
        duration: 150
        easing.type: Easing.OutCubic
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.isOpen
        onActivated: {
            if (root.powerService)
                root.powerService.cancelConfirm();

        }
    }

    HyprlandFocusGrab {
        active: false
        windows: [root]
        onCleared: {
            if (root.powerService)
                root.powerService.cancelConfirm();

        }
    }

    // Keyboard navigation (Esc to cancel, Enter/Return to execute)
    Item {
        id: keyHandler

        anchors.fill: parent
        focus: root.isOpen
        Keys.onEscapePressed: {
            if (root.powerService)
                root.powerService.cancelConfirm();

        }
        Keys.onReturnPressed: {
            if (root.powerService)
                root.powerService.executeConfirmed();

        }
        Keys.onEnterPressed: {
            if (root.powerService)
                root.powerService.executeConfirmed();

        }
    }

    // Semi-transparent backdrop overlay
    Rectangle {
        anchors.fill: parent
        color: Theme.withAlpha(Theme.darker_background, Theme.scrimOpacity)
        opacity: root.animProgress

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (root.powerService)
                    root.powerService.cancelConfirm();

            }
        }

    }

    // Centered Confirmation Dialog Box
    GlassPanel {
        id: dialogCard

        width: 380
        height: 190
        anchors.centerIn: parent
        radius: Appearance.dialogRadius
        baseColor: Theme.barBackground
        opacity: Math.min(1, root.animProgress * 1.5)
        scale: 0.9 + 0.1 * root.animProgress

        // Prevent clicks on the card from falling through to the backdrop
        MouseArea {
            anchors.fill: parent
            propagateComposedEvents: true
            onClicked: function(mouse) {
                mouse.accepted = false;
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Appearance.paddingXl + 2 // 22px
            spacing: Appearance.spacingXl

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacingXl

                // Action Icon Badge
                Rectangle {
                    readonly property bool isUrgent: root.powerService && root.powerService.confirmAction === "poweroff"

                    width: Appearance.osdHeight
                    height: Appearance.osdHeight
                    radius: Appearance.radiusPill
                    color: Theme.darker_background
                    border.color: isUrgent ? Theme.red : Theme.yellow
                    border.width: Appearance.borderWidthThin

                    Text {
                        anchors.centerIn: parent
                        text: root.powerService ? root.powerService.confirmIcon : ""
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: Fonts.sizeTitle
                        color: parent.isUrgent ? Theme.red : Theme.yellow
                    }

                }

                // Title and prompt text
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacingSmall

                    Text {
                        Layout.fillWidth: true
                        text: root.powerService ? root.powerService.confirmTitle : ""
                        font.family: Fonts.uiFont
                        font.pixelSize: Fonts.sizeLarge
                        font.bold: true
                        color: Theme.foreground
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.powerService ? root.powerService.confirmMessage : ""
                        font.family: Fonts.uiFont
                        font.pixelSize: Fonts.sizeSmall
                        color: Theme.muted
                        wrapMode: Text.WordWrap
                    }

                }

            }

            Item {
                Layout.fillHeight: true
            }

            // Action Buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacingLarge

                // Cancel Button
                Rectangle {
                    id: cancelBtn

                    Layout.fillWidth: true
                    height: Appearance.popupHeaderHeight
                    radius: Appearance.buttonRadius
                    color: cancelMouse.containsMouse ? Theme.lighter_background : Theme.dark_background
                    border.color: cancelMouse.containsMouse ? Theme.accent : Theme.selection
                    border.width: Appearance.borderWidthThin

                    Row {
                        anchors.centerIn: parent
                        spacing: Appearance.spacingMedium - 2 // 6px

                        Text {
                            text: Icons.close
                            font.family: Icons.effectiveFont(text)
                            font.pixelSize: Fonts.sizeRegular
                            color: cancelMouse.containsMouse ? Theme.foreground : Theme.muted
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "Cancel"
                            font.family: Fonts.uiFont
                            font.pixelSize: Fonts.sizeSmall
                            font.bold: true
                            color: cancelMouse.containsMouse ? Theme.foreground : Theme.muted
                            anchors.verticalCenter: parent.verticalCenter
                        }

                    }

                    MouseArea {
                        id: cancelMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.powerService)
                                root.powerService.cancelConfirm();

                        }
                    }

                }

                // Confirm Action Button
                Rectangle {
                    id: confirmBtn

                    readonly property bool isUrgent: root.powerService && root.powerService.confirmAction === "poweroff"
                    readonly property color themeColor: isUrgent ? Theme.red : Theme.yellow

                    Layout.fillWidth: true
                    height: Appearance.popupHeaderHeight
                    radius: Appearance.buttonRadius
                    color: {
                        if (confirmMouse.containsMouse)
                            return themeColor;

                        return Theme.selection;
                    }
                    border.color: themeColor
                    border.width: Appearance.borderWidthThin

                    Row {
                        anchors.centerIn: parent
                        spacing: Appearance.spacingMedium - 2 // 6px

                        Text {
                            text: root.powerService ? root.powerService.confirmIcon : ""
                            font.family: Icons.effectiveFont(text)
                            font.pixelSize: Fonts.sizeRegular
                            color: confirmMouse.containsMouse ? Theme.darker_background : confirmBtn.themeColor
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: root.powerService && root.powerService.confirmAction === "poweroff" ? "Power Off" : "Restart"
                            font.family: Fonts.uiFont
                            font.pixelSize: Fonts.sizeSmall
                            font.bold: true
                            color: confirmMouse.containsMouse ? Theme.darker_background : Theme.foreground
                            anchors.verticalCenter: parent.verticalCenter
                        }

                    }

                    MouseArea {
                        id: confirmMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.powerService)
                                root.powerService.executeConfirmed();

                        }
                    }

                }

            }

        }

    }

}
