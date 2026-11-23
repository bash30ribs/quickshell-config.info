import "../components"
import "../services"
import "../theme"
import QtQuick
import Quickshell

Item {
    id: root

    required property HardwareService hardwareService
    required property PowerService powerService
    property int iconSize: Appearance.barIconSize
    readonly property string profile: root.hardwareService.powerProfile
    readonly property bool isPerf: root.profile === "performance"
    readonly property bool isSaver: root.profile === "power-saver"
    readonly property bool isBalanced: root.profile === "balanced"
    readonly property color profileColor: {
        if (root.isPerf)
            return Theme.red;

        if (root.isSaver)
            return Theme.green;

        return Theme.cyan;
    }
    readonly property string profileIcon: {
        if (root.isPerf)
            return Icons.useMaterialSymbols ? "bolt" : "󰓅";

        if (root.isSaver)
            return Icons.useMaterialSymbols ? "eco" : "󰌪";

        return Icons.useMaterialSymbols ? "speed" : "󰓅";
    }
    readonly property string profileLabelText: {
        if (root.isPerf)
            return "TURBO";

        if (root.isSaver)
            return "SAVER";

        return "BALANCED";
    }

    function toggle() {
        usagePopup.toggle();
        if (usagePopup.open)
            root.hardwareService.refresh();

    }

    function cycleProfile() {
        root.hardwareService.cyclePowerProfile();
        showProfileToast();
    }

    function toggleTurbo() {
        if (root.isPerf)
            root.hardwareService.setPowerProfile("balanced");
        else
            root.hardwareService.setPowerProfile("performance");
        showProfileToast();
    }

    function showProfileToast() {
        var icon = root.isPerf ? "⚡" : (root.isSaver ? "🌱" : "⚖️");
        var name = root.isPerf ? "Turbo Performance" : (root.isSaver ? "Power Saver" : "Balanced Profile");
        Quickshell.execDetached(["qs", "ipc", "call", "osd", "trigger", icon, name]);
    }

    implicitWidth: usageButton.implicitWidth
    implicitHeight: usageButton.implicitHeight
    width: implicitWidth
    height: implicitHeight

    // ── Bar Button with Quick Controls ─────────────────────────────────────────
    BarButton {
        id: usageButton

        icon: root.profileIcon
        iconSize: root.iconSize
        text: {
            var profileShort = root.isPerf ? "Turbo" : (root.isSaver ? "Saver" : "Bal");
            if (Appearance.barIsVertical)
                return profileShort;

            if (root.hardwareService && root.hardwareService.cpuUsage > 0)
                return profileShort + " " + root.hardwareService.cpuUsage + "%";

            return profileShort;
        }
        active: usagePopup.open
        accentActive: root.isPerf
        customColor: {
            if (usagePopup.open)
                return Theme.accent;

            if (root.isPerf)
                return Theme.red;

            if (root.isSaver)
                return Theme.green;

            return Theme.bright_foreground;
        }
        onClicked: root.toggle()

        // Right click: instant Turbo toggle
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleTurbo()
        }

        // Scroll wheel: instant cycle profile
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function(event) {
                if (event.angleDelta.y !== 0)
                    root.cycleProfile();

            }
        }

    }

    // ── Apple visionOS Mornye Liquid Glass Card ──────────────────────────────
    PopupCard {
        id: usagePopup

        anchorItem: usageButton
        showDefaultHeader: false
        contentWidth: 280
        contentHeight: mainCol.implicitHeight + (Appearance.popupPadding * 2)

        Column {
            id: mainCol

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 10

            // 1. Hero Header: Title, Uptime & Status Badge
            Item {
                width: parent.width
                height: 30

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 9

                    Rectangle {
                        width: 26
                        height: 26
                        radius: 8
                        color: Theme.withAlpha(root.profileColor, 0.16)
                        border.width: 1
                        border.color: Theme.withAlpha(root.profileColor, 0.35)
                        antialiasing: true

                        Text {
                            anchors.centerIn: parent
                            text: root.profileIcon
                            font.family: Icons.effectiveFont(text)
                            font.pixelSize: 13
                            color: root.profileColor
                        }

                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            text: "Performance"
                            font.family: Fonts.uiFont
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: Theme.bright_foreground
                        }

                        Text {
                            text: {
                                if (!root.powerService.uptime)
                                    return "System Profile";

                                var u = root.powerService.uptime.replace(/^up\s*/i, "").replace(/,\s*/g, " ").replace(/hours?/i, "h").replace(/minutes?/i, "m").replace(/seconds?/i, "s").replace(/days?/i, "d");
                                return "System · Up " + u.trim();
                            }
                            font.family: Fonts.uiFont
                            font.pixelSize: 9
                            color: Theme.muted
                        }

                    }

                }

                // Profile Badge Pill with Glowing Dot
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 20
                    width: badgeContent.implicitWidth + 14
                    radius: 10
                    color: Theme.withAlpha(root.profileColor, 0.14)
                    border.width: 1
                    border.color: Theme.withAlpha(root.profileColor, 0.35)
                    antialiasing: true

                    Row {
                        id: badgeContent

                        anchors.centerIn: parent
                        spacing: 5

                        Rectangle {
                            width: 5
                            height: 5
                            radius: 2.5
                            color: root.profileColor
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: root.profileLabelText
                            font.family: Fonts.uiFont
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            color: root.profileColor
                            anchors.verticalCenter: parent.verticalCenter
                        }

                    }

                }

            }

            // 2. Floating Sliding Governor Capsule
            Rectangle {
                id: governorTrack

                readonly property real itemWidth: (width - 4) / 3
                readonly property int activeIndex: root.isSaver ? 0 : (root.isPerf ? 2 : 1)

                width: parent.width
                height: 34
                radius: 10
                color: Qt.rgba(1, 1, 1, 0.04)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.08)
                antialiasing: true

                // Sliding Liquid Selection Pill
                Rectangle {
                    id: sliderPill

                    x: 2 + governorTrack.activeIndex * governorTrack.itemWidth
                    y: 2
                    width: governorTrack.itemWidth
                    height: governorTrack.height - 4
                    radius: 8
                    color: Theme.withAlpha(root.profileColor, 0.22)
                    border.width: 1
                    border.color: Theme.withAlpha(root.profileColor, 0.45)
                    antialiasing: true

                    // Top diffuse specular sheen
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: Math.max(3, parent.height * 0.4)
                        radius: parent.radius
                        antialiasing: true

                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: Qt.rgba(1, 1, 1, 0.14)
                            }

                            GradientStop {
                                position: 1
                                color: "transparent"
                            }

                        }

                    }

                    Behavior on x {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.12
                        }

                    }

                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 2

                    // Option 1: Saver
                    Item {
                        width: governorTrack.itemWidth
                        height: parent.height

                        Row {
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                text: Icons.useMaterialSymbols ? "eco" : "󰌪"
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: 11
                                color: root.isSaver ? Theme.green : Theme.muted
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Saver"
                                font.family: Fonts.uiFont
                                font.pixelSize: 10
                                font.weight: root.isSaver ? Font.DemiBold : Font.Normal
                                color: root.isSaver ? Theme.bright_foreground : (saverHover.hovered ? Theme.foreground : Theme.muted)
                                anchors.verticalCenter: parent.verticalCenter
                            }

                        }

                        HoverHandler {
                            id: saverHover
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.hardwareService.setPowerProfile("power-saver");
                                root.showProfileToast();
                            }
                        }

                    }

                    // Option 2: Balanced
                    Item {
                        width: governorTrack.itemWidth
                        height: parent.height

                        Row {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: Icons.useMaterialSymbols ? "balance" : "󰈐"
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: 11
                                color: root.isBalanced ? Theme.cyan : Theme.muted
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Balanced"
                                font.family: Fonts.uiFont
                                font.pixelSize: 10
                                font.weight: root.isBalanced ? Font.DemiBold : Font.Normal
                                color: root.isBalanced ? Theme.bright_foreground : (balHover.hovered ? Theme.foreground : Theme.muted)
                                anchors.verticalCenter: parent.verticalCenter
                            }

                        }

                        HoverHandler {
                            id: balHover
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.hardwareService.setPowerProfile("balanced");
                                root.showProfileToast();
                            }
                        }

                    }

                    // Option 3: Turbo
                    Item {
                        width: governorTrack.itemWidth
                        height: parent.height

                        Row {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: Icons.useMaterialSymbols ? "bolt" : "󰓅"
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: 11
                                color: root.isPerf ? Theme.red : Theme.muted
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Turbo"
                                font.family: Fonts.uiFont
                                font.pixelSize: 10
                                font.weight: root.isPerf ? Font.DemiBold : Font.Normal
                                color: root.isPerf ? Theme.bright_foreground : (perfHover.hovered ? Theme.foreground : Theme.muted)
                                anchors.verticalCenter: parent.verticalCenter
                            }

                        }

                        HoverHandler {
                            id: perfHover
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.hardwareService.setPowerProfile("performance");
                                root.showProfileToast();
                            }
                        }

                    }

                }

            }

            // 3. 3-Column visionOS Metric Stat Tiles (CPU, RAM, TEMP)
            Row {
                id: statsRow

                readonly property int baseTileWidth: Math.floor((width - (spacing * 2)) / 3)

                width: parent.width
                spacing: 6

                // Tile 1: CPU Load
                Rectangle {
                    id: cpuTile

                    readonly property color cpuColor: root.hardwareService.cpuPercent > 75 ? Theme.red : (root.hardwareService.cpuPercent > 40 ? Theme.yellow : Theme.accent)

                    width: statsRow.baseTileWidth
                    height: 76
                    radius: 10
                    color: cpuHover.hovered ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.04)
                    border.width: 1
                    border.color: cpuHover.hovered ? Theme.withAlpha(cpuColor, 0.35) : Qt.rgba(1, 1, 1, 0.08)
                    antialiasing: true

                    // Top diffuse sheen
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 20
                        radius: parent.radius
                        antialiasing: true

                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: Qt.rgba(1, 1, 1, 0.06)
                            }

                            GradientStop {
                                position: 1
                                color: "transparent"
                            }

                        }

                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        // Header: Icon + Metric Label
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 5

                            Text {
                                text: Icons.useMaterialSymbols ? "speed" : "󰻠"
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: 11
                                color: cpuTile.cpuColor
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "CPU"
                                font.family: Fonts.uiFont
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                color: Theme.muted
                                anchors.verticalCenter: parent.verticalCenter
                            }

                        }

                        // Prominent Value
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.hardwareService.cpuPercent + "%"
                            font.family: Fonts.uiFont
                            font.pixelSize: 17
                            font.weight: Font.Bold
                            color: Theme.bright_foreground
                        }

                        Item {
                            width: 1
                            height: 2
                        }

                        // Micro Capsule Meter
                        Rectangle {
                            width: parent.width
                            height: 3
                            radius: 1.5
                            color: Qt.rgba(1, 1, 1, 0.1)

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Math.max(3, parent.width * (root.hardwareService.cpuPercent / 100))
                                radius: 1.5
                                color: cpuTile.cpuColor
                                antialiasing: true

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 250
                                        easing.type: Easing.OutCubic
                                    }

                                }

                            }

                        }

                    }

                    HoverHandler {
                        id: cpuHover
                    }

                }

                // Tile 2: Memory (RAM)
                Rectangle {
                    id: ramTile

                    readonly property color ramColor: root.hardwareService.ramPercent > 85 ? Theme.red : Theme.cyan

                    width: statsRow.baseTileWidth
                    height: 76
                    radius: 10
                    color: ramHover.hovered ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.04)
                    border.width: 1
                    border.color: ramHover.hovered ? Theme.withAlpha(ramColor, 0.35) : Qt.rgba(1, 1, 1, 0.08)
                    antialiasing: true

                    // Top diffuse sheen
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 20
                        radius: parent.radius
                        antialiasing: true

                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: Qt.rgba(1, 1, 1, 0.06)
                            }

                            GradientStop {
                                position: 1
                                color: "transparent"
                            }

                        }

                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        // Header: Icon + Metric Label
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 5

                            Text {
                                text: Icons.useMaterialSymbols ? "memory" : "󰍛"
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: 11
                                color: ramTile.ramColor
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "RAM"
                                font.family: Fonts.uiFont
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                color: Theme.muted
                                anchors.verticalCenter: parent.verticalCenter
                            }

                        }

                        // Prominent Value with Unit
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 3

                            Text {
                                text: root.hardwareService.ramUsedGb
                                font.family: Fonts.uiFont
                                font.pixelSize: 17
                                font.weight: Font.Bold
                                color: Theme.bright_foreground
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "GB"
                                font.family: Fonts.uiFont
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: Theme.muted
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 2
                            }

                        }

                        Item {
                            width: 1
                            height: 2
                        }

                        // Micro Capsule Meter
                        Rectangle {
                            width: parent.width
                            height: 3
                            radius: 1.5
                            color: Qt.rgba(1, 1, 1, 0.1)

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Math.max(3, parent.width * (root.hardwareService.ramPercent / 100))
                                radius: 1.5
                                color: ramTile.ramColor
                                antialiasing: true

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 300
                                        easing.type: Easing.OutCubic
                                    }

                                }

                            }

                        }

                    }

                    HoverHandler {
                        id: ramHover
                    }

                }

                // Tile 3: Core Temperature (Thermal)
                Rectangle {
                    id: tempTile

                    readonly property color tempColor: root.hardwareService.tempCelsius > 75 ? Theme.red : (root.hardwareService.tempCelsius > 55 ? Theme.yellow : Theme.green)

                    width: statsRow.width - cpuTile.width - ramTile.width - (statsRow.spacing * 2)
                    height: 76
                    radius: 10
                    color: tempHover.hovered ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.04)
                    border.width: 1
                    border.color: tempHover.hovered ? Theme.withAlpha(tempColor, 0.35) : Qt.rgba(1, 1, 1, 0.08)
                    antialiasing: true

                    // Top diffuse sheen
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 20
                        radius: parent.radius
                        antialiasing: true

                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: Qt.rgba(1, 1, 1, 0.06)
                            }

                            GradientStop {
                                position: 1
                                color: "transparent"
                            }

                        }

                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        // Header: Icon + Metric Label
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 5

                            Text {
                                text: Icons.useMaterialSymbols ? "thermostat" : "󰔏"
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: 11
                                color: tempTile.tempColor
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "TEMP"
                                font.family: Fonts.uiFont
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                color: Theme.muted
                                anchors.verticalCenter: parent.verticalCenter
                            }

                        }

                        // Prominent Value with Unit
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 2

                            Text {
                                text: root.hardwareService.tempCelsius
                                font.family: Fonts.uiFont
                                font.pixelSize: 17
                                font.weight: Font.Bold
                                color: Theme.bright_foreground
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "°C"
                                font.family: Fonts.uiFont
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: Theme.muted
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 2
                            }

                        }

                        Item {
                            width: 1
                            height: 2
                        }

                        // Micro Capsule Meter
                        Rectangle {
                            width: parent.width
                            height: 3
                            radius: 1.5
                            color: Qt.rgba(1, 1, 1, 0.1)

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Math.max(3, Math.min(parent.width, parent.width * (root.hardwareService.tempCelsius / 100)))
                                radius: 1.5
                                color: tempTile.tempColor
                                antialiasing: true

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 300
                                        easing.type: Easing.OutCubic
                                    }

                                }

                            }

                        }

                    }

                    HoverHandler {
                        id: tempHover
                    }

                }

            }

            // 4. Refined Peak Process Chip
            Rectangle {
                id: topTaskChip

                width: parent.width
                height: 28
                radius: 8
                visible: root.hardwareService.topProcess !== ""
                color: topTaskHover.hovered ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.035)
                border.width: 1
                border.color: topTaskHover.hovered ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                antialiasing: true

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Text {
                        text: Icons.useMaterialSymbols ? "local_fire_department" : "󰈸"
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: 12
                        color: Theme.orange
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "Peak:"
                        font.family: Fonts.uiFont
                        font.pixelSize: 10
                        color: Theme.muted
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: root.hardwareService.topProcess
                        font.family: Fonts.uiFont
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: Theme.bright_foreground
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, 120)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                }

                // CPU Badge
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    height: 18
                    width: topCpuText.implicitWidth + 10
                    radius: 5
                    color: Theme.withAlpha(Theme.orange, 0.15)
                    border.width: 1
                    border.color: Theme.withAlpha(Theme.orange, 0.35)
                    antialiasing: true

                    Text {
                        id: topCpuText

                        anchors.centerIn: parent
                        text: root.hardwareService.topProcessCpu
                        font.family: Fonts.monoFont
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        color: Theme.orange
                    }

                }

                HoverHandler {
                    id: topTaskHover
                }

            }

            // 5. Mornye Glass Action Button: Activity Monitor
            Rectangle {
                id: monitorBtn

                width: parent.width
                height: 32
                radius: 8
                color: monitorHover.hovered ? Theme.withAlpha(Theme.accent, 0.18) : Qt.rgba(1, 1, 1, 0.045)
                border.width: 1
                border.color: monitorHover.hovered ? Theme.withAlpha(Theme.accent, 0.45) : Qt.rgba(1, 1, 1, 0.09)
                antialiasing: true
                scale: monitorMouse.pressed ? 0.975 : (monitorHover.hovered ? 1.015 : 1)

                // Top diffuse sheen
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 12
                    radius: parent.radius
                    antialiasing: true

                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: Qt.rgba(1, 1, 1, monitorHover.hovered ? 0.12 : 0.06)
                        }

                        GradientStop {
                            position: 1
                            color: "transparent"
                        }

                    }

                }

                Row {
                    anchors.centerIn: parent
                    spacing: 7

                    Text {
                        text: Icons.useMaterialSymbols ? "terminal" : "󰆍"
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: 13
                        color: monitorHover.hovered ? Theme.accent : Theme.muted
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "Activity Monitor"
                        font.family: Fonts.uiFont
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: monitorHover.hovered ? Theme.bright_foreground : Theme.foreground
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: Icons.useMaterialSymbols ? "chevron_right" : "→"
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: 10
                        color: monitorHover.hovered ? Theme.accent : Theme.muted
                        anchors.verticalCenter: parent.verticalCenter
                    }

                }

                HoverHandler {
                    id: monitorHover
                }

                MouseArea {
                    id: monitorMouse

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached(["qdeck", "terminal", "btop"]);
                        root.toggle();
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutQuad
                    }

                }

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }

                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: 150
                    }

                }

            }

        }

    }

}
