import "../components"
import "../services"
import "../theme"
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property BatteryService batteryService
    required property PowerService powerService
    property bool showPercentage: Appearance.batteryShowPercentage
    property bool showCycles: Appearance.batteryShowCycles
    property bool showHealth: Appearance.batteryShowHealth
    property int cycleOverride: Appearance.batteryCycleOverride
    property int iconSize: Appearance.batteryIconSize
    readonly property bool isCharging: root.batteryService && (root.batteryService.isCharging || root.batteryService.isPluggedIn)
    readonly property bool isVertical: Appearance.barIsVertical

    function toggle() {
        batPopup.toggle();
        if (batPopup.open)
            root.batteryService.refresh();

    }

    implicitWidth: batButton.implicitWidth
    implicitHeight: batButton.implicitHeight
    width: implicitWidth
    height: implicitHeight

    Rectangle {
        id: batButton

        implicitHeight: Appearance.barButtonHeight
        implicitWidth: root.isVertical ? Appearance.barButtonHeight : Math.max(Appearance.barButtonHeight, contentContainer.implicitWidth + (Appearance.buttonPadding * 2))
        width: implicitWidth
        height: implicitHeight
        radius: Appearance.buttonRadius > 0 ? (root.isVertical ? Appearance.radiusMedium : Appearance.buttonRadius) : 8
        antialiasing: true
        scale: batMouse.pressed ? 0.96 : (batMouse.containsMouse ? 1.025 : 1)
        color: {
            if (batPopup.open)
                return Theme.withAlpha(Theme.accent, 0.18);

            if (batMouse.containsMouse)
                return Theme.withAlpha(Theme.accent, 0.1);

            return "transparent";
        }
        border.width: 0
        border.color: "transparent"

        // ── Horizontal Layout ──
        Row {
            id: contentContainer

            anchors.centerIn: parent
            visible: !root.isVertical
            spacing: 2

            // Battery Capacity Number
            Text {
                id: capText

                anchors.verticalCenter: parent.verticalCenter
                text: (root.batteryService ? root.batteryService.capacity : 0)
                font.family: Fonts.uiFont
                font.pixelSize: Fonts.sizeRegular
                font.weight: Fonts.weightDemiBold
                color: {
                    if (root.batteryService && root.batteryService.capacity <= 20)
                        return Theme.red;

                    if (root.batteryService && root.batteryService.capacity <= 40)
                        return Theme.yellow;

                    return Theme.bright_foreground;
                }
                style: Text.Raised
                styleColor: Qt.rgba(0, 0, 0, 0.65)
            }

            // State 1: When NOT charging -> show "%" symbol next to battery number
            Text {
                id: percentSign

                anchors.verticalCenter: parent.verticalCenter
                visible: !root.isCharging
                text: "%"
                font.family: Fonts.uiFont
                font.pixelSize: Fonts.sizeRegular
                font.weight: Fonts.weightDemiBold
                color: capText.color
                style: Text.Raised
                styleColor: Qt.rgba(0, 0, 0, 0.65)
            }

            // State 2: When CHARGING -> percentage "%" won't be shown, instead show animated electric_bolt
            Item {
                id: chargingBoltItem

                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                visible: root.isCharging

                // Radial energy aura ripple
                Rectangle {
                    id: auraRing

                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    radius: 8
                    color: Theme.withAlpha(Theme.accent, 0.28)
                    visible: root.isCharging

                    SequentialAnimation on scale {
                        running: root.isCharging
                        loops: Animation.Infinite

                        NumberAnimation {
                            to: 1.35
                            duration: 800
                            easing.type: Easing.InOutSine
                        }

                        NumberAnimation {
                            to: 0.85
                            duration: 800
                            easing.type: Easing.InOutSine
                        }

                    }

                    SequentialAnimation on opacity {
                        running: root.isCharging
                        loops: Animation.Infinite

                        NumberAnimation {
                            to: 0.15
                            duration: 800
                            easing.type: Easing.InOutSine
                        }

                        NumberAnimation {
                            to: 0.7
                            duration: 800
                            easing.type: Easing.InOutSine
                        }

                    }

                }

                // Material Symbols Rounded electric_bolt
                Text {
                    id: boltGlyph

                    anchors.centerIn: parent
                    text: Icons.electricBolt
                    font.family: Icons.effectiveFont(text)
                    font.pixelSize: 16
                    color: Theme.accent
                    style: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.5)

                    SequentialAnimation on scale {
                        running: root.isCharging
                        loops: Animation.Infinite

                        NumberAnimation {
                            to: 1.18
                            duration: 500
                            easing.type: Easing.InOutSine
                        }

                        NumberAnimation {
                            to: 0.92
                            duration: 500
                            easing.type: Easing.InOutSine
                        }

                    }

                    SequentialAnimation on opacity {
                        running: root.isCharging
                        loops: Animation.Infinite

                        NumberAnimation {
                            to: 1
                            duration: 500
                            easing.type: Easing.InOutSine
                        }

                        NumberAnimation {
                            to: 0.72
                            duration: 500
                            easing.type: Easing.InOutSine
                        }

                    }

                }

            }

        }

        // ── Vertical Bar Layout ──
        Column {
            id: contentContainerVertical

            anchors.centerIn: parent
            visible: root.isVertical
            spacing: 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (root.batteryService ? root.batteryService.capacity : 0)
                font.family: Fonts.uiFont
                font.pixelSize: (text.length > 2) ? Fonts.scale(9.5) : Fonts.sizeRegular
                font.weight: Fonts.weightDemiBold
                color: capText.color
                style: Text.Raised
                styleColor: Qt.rgba(0, 0, 0, 0.65)
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !root.isCharging
                text: "%"
                font.family: Fonts.uiFont
                font.pixelSize: Fonts.scale(9)
                font.weight: Fonts.weightDemiBold
                color: capText.color
                style: Text.Raised
                styleColor: Qt.rgba(0, 0, 0, 0.65)
            }

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 14
                height: 14
                visible: root.isCharging

                Text {
                    anchors.centerIn: parent
                    text: Icons.electricBolt
                    font.family: Icons.effectiveFont(text)
                    font.pixelSize: 13
                    color: Theme.accent
                }

            }

        }

        MouseArea {
            id: batMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.toggle();
            }
        }

        Behavior on implicitWidth {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: batMouse.pressed ? 70 : 180
                easing.type: batMouse.pressed ? Easing.OutQuad : Easing.OutBack
                easing.overshoot: batMouse.pressed ? 1 : 1.25
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: Appearance.animDurationNormal
            }

        }

    }

    PopupCard {
        id: batPopup

        anchorItem: batButton
        showDefaultHeader: false
        contentWidth: 360
        contentHeight: (root.showCycles && root.showHealth) ? 265 : 240

        Column {
            anchors.fill: parent
            spacing: 12

            // Top Banner: Battery icon + title + status, and percentage
            Item {
                width: parent.width
                height: 38

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Text {
                        text: root.batteryService.icon
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: 30
                        color: {
                            if (root.batteryService.isCharging || root.batteryService.isPluggedIn)
                                return Theme.accent;

                            if (root.batteryService.capacity <= 20)
                                return Theme.red;

                            if (root.batteryService.capacity <= 40)
                                return Theme.yellow;

                            return Theme.bright_foreground;
                        }
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "Battery"
                            font.family: Fonts.uiFont
                            font.pixelSize: Fonts.sizeLarge
                            font.bold: true
                            color: Theme.bright_foreground
                        }

                        Text {
                            text: root.batteryService.statusDisplay
                            font.family: Fonts.uiFont
                            font.pixelSize: 10
                            font.bold: true
                            color: (root.batteryService.isCharging || root.batteryService.isPluggedIn) ? Theme.accent : Theme.withAlpha(Theme.foreground, 0.75)
                        }

                    }

                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.batteryService.capacity + "%"
                    font.family: Fonts.monoFont
                    font.pixelSize: 28
                    font.bold: true
                    color: Theme.bright_foreground
                }

            }

            // Wide Battery Progress Bar (Capsule)
            Rectangle {
                width: parent.width
                height: 8
                radius: Appearance.radiusSmall
                color: Qt.rgba(0, 0, 0, 0.35)
                border.color: Qt.rgba(255, 255, 255, 0.1)
                border.width: 1

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: 1
                    width: Math.max(8, Math.min(parent.width - 2, (parent.width - 2) * (root.batteryService.capacity / 100)))
                    radius: 3
                    color: {
                        if (root.batteryService.capacity <= 20)
                            return Theme.red;

                        if (root.batteryService.capacity <= 40)
                            return Theme.yellow;

                        if (root.batteryService.isCharging || root.batteryService.isPluggedIn)
                            return Theme.accent;

                        return Theme.bright_foreground;
                    }
                }

            }

            // Stats Inset Well Container
            Rectangle {
                width: parent.width
                height: statsGrid.implicitHeight + 16
                radius: 10
                color: Qt.rgba(0, 0, 0, 0.22)
                border.color: Qt.rgba(255, 255, 255, 0.08)
                border.width: 1

                Row {
                    id: statsGrid

                    readonly property real colWidth: (width - spacing) / 2

                    anchors.centerIn: parent
                    width: parent.width - 20
                    spacing: 16

                    // Left Column
                    Column {
                        width: parent.colWidth
                        spacing: 6

                        // Battery size
                        Item {
                            width: parent.width
                            height: 18

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Battery size"
                                font.family: Fonts.uiFont
                                font.pixelSize: Fonts.sizeSmall
                                color: Theme.withAlpha(Theme.foreground, 0.72)
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.batteryService.batterySize
                                font.family: Fonts.monoFont
                                font.pixelSize: Fonts.sizeSmall
                                font.bold: true
                                color: Theme.bright_foreground
                            }

                        }

                        // Battery health (if enabled)
                        Item {
                            visible: root.showHealth
                            width: parent.width
                            height: visible ? 18 : 0

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Battery health"
                                font.family: Fonts.uiFont
                                font.pixelSize: Fonts.sizeSmall
                                color: Theme.withAlpha(Theme.foreground, 0.72)
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.batteryService.batteryHealth
                                font.family: Fonts.monoFont
                                font.pixelSize: Fonts.sizeSmall
                                font.bold: true
                                color: Theme.bright_foreground
                            }

                        }

                        // Charge cycles (if enabled)
                        Item {
                            visible: root.showCycles
                            width: parent.width
                            height: visible ? 18 : 0

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Charge cycles"
                                font.family: Fonts.uiFont
                                font.pixelSize: Fonts.sizeSmall
                                color: Theme.withAlpha(Theme.foreground, 0.72)
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: (root.cycleOverride > 0) ? String(root.cycleOverride) : root.batteryService.cycleCount
                                font.family: Fonts.monoFont
                                font.pixelSize: Fonts.sizeSmall
                                font.bold: true
                                color: Theme.bright_foreground
                            }

                        }

                    }

                    // Right Column
                    Column {
                        width: parent.colWidth
                        spacing: 6

                        // Time to full (or Time to empty)
                        Item {
                            width: parent.width
                            height: 18

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.batteryService.timeLabel
                                font.family: Fonts.uiFont
                                font.pixelSize: Fonts.sizeSmall
                                color: Theme.withAlpha(Theme.foreground, 0.72)
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: (root.batteryService.timeToFull === "-" || !root.batteryService.timeToFull) ? "Idle" : root.batteryService.timeToFull
                                font.family: Fonts.monoFont
                                font.pixelSize: Fonts.sizeSmall
                                font.bold: true
                                color: Theme.bright_foreground
                            }

                        }

                        // Power source
                        Item {
                            visible: root.showCycles && root.showHealth
                            width: parent.width
                            height: visible ? 18 : 0

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Power source"
                                font.family: Fonts.uiFont
                                font.pixelSize: Fonts.sizeSmall
                                color: Theme.withAlpha(Theme.foreground, 0.72)
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.batteryService.powerSource
                                font.family: Fonts.monoFont
                                font.pixelSize: Fonts.sizeSmall
                                font.bold: true
                                color: Theme.bright_foreground
                            }

                        }

                        // Charging rate
                        Item {
                            width: parent.width
                            height: 18

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: (root.showCycles && root.showHealth) ? root.batteryService.rateLabel : (root.batteryService.rateLabel || "Charging")
                                font.family: Fonts.uiFont
                                font.pixelSize: Fonts.sizeSmall
                                color: Theme.withAlpha(Theme.foreground, 0.72)
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: (root.batteryService.chargingRate === "-" || !root.batteryService.chargingRate) ? "Idle" : root.batteryService.chargingRate
                                font.family: Fonts.monoFont
                                font.pixelSize: Fonts.sizeSmall
                                font.bold: true
                                color: Theme.bright_foreground
                            }

                        }

                    }

                }

            }

            // Power Profile Section Header
            Text {
                text: "POWER PROFILE"
                font.family: Fonts.uiFont
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1
                color: Theme.withAlpha(Theme.foreground, 0.65)
            }

            // Power Profiles Row (Power-saver, Balanced, Performance)
            Row {
                readonly property var profiles: [{
                    "id": "power-saver",
                    "label": "Power-saver",
                    "icon": "󰌪"
                }, {
                    "id": "balanced",
                    "label": "Balanced",
                    "icon": "󰾆"
                }, {
                    "id": "performance",
                    "label": "Performance",
                    "icon": "󰓅"
                }]

                width: parent.width
                spacing: 8

                Repeater {
                    model: parent.profiles

                    Rectangle {
                        id: profBtn

                        required property var modelData
                        readonly property bool isActive: root.powerService.activeProfile === modelData.id

                        width: (parent.width - 16) / 3
                        height: 38
                        radius: Appearance.radiusSmall
                        color: {
                            if (isActive)
                                return Theme.withAlpha(Theme.accent, 0.25);

                            if (profMouse.containsMouse)
                                return Qt.rgba(255, 255, 255, 0.1);

                            return Qt.rgba(0, 0, 0, 0.22);
                        }
                        border.color: isActive ? Theme.accent : Qt.rgba(255, 255, 255, 0.08)
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: profBtn.modelData.icon
                                font.family: Icons.effectiveFont(profBtn.modelData.icon)
                                font.pixelSize: Fonts.sizeRegular
                                color: profBtn.isActive ? Theme.accent : Theme.withAlpha(Theme.foreground, 0.7)
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: profBtn.modelData.label
                                font.family: Fonts.uiFont
                                font.pixelSize: 11
                                font.bold: profBtn.isActive
                                color: profBtn.isActive ? Theme.accent : Theme.bright_foreground
                                anchors.verticalCenter: parent.verticalCenter
                            }

                        }

                        MouseArea {
                            id: profMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.powerService.setProfile(profBtn.modelData.id)
                        }

                    }

                }

            }

        }

    }

}
