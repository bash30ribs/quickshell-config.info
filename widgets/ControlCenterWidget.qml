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

    // ── Minimalist Mornye Liquid Glass Popup ──────────────────────────────────
    PopupCard {
        id: usagePopup

        anchorItem: usageButton
        showDefaultHeader: false
        contentWidth: 260
        contentHeight: root.hardwareService.topProcess !== "" ? 276 : 248

        Column {
            id: mainCol

            anchors.fill: parent
            spacing: 10

            // 1. Sleek Header
            Item {
                width: parent.width
                height: 28

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        width: 22
                        height: 22
                        radius: 6
                        color: Theme.withAlpha(root.profileColor, 0.16)
                        border.width: 1
                        border.color: Theme.withAlpha(root.profileColor, 0.35)

                        Text {
                            anchors.centerIn: parent
                            text: root.profileIcon
                            font.family: Icons.effectiveFont(text)
                            font.pixelSize: 12
                            color: root.profileColor
                        }

                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

                        Text {
                            text: "PERFORMANCE"
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
                                return "Up " + u.trim();
                            }
                            font.family: Fonts.uiFont
                            font.pixelSize: 9
                            color: Theme.muted
                        }

                    }

                }

                // Profile Badge Pill
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 18
                    width: badgeText.implicitWidth + 12
                    radius: 9
                    color: Theme.withAlpha(root.profileColor, 0.15)
                    border.width: 1
                    border.color: Theme.withAlpha(root.profileColor, 0.4)

                    Text {
                        id: badgeText

                        anchors.centerIn: parent
                        text: root.profileLabelText
                        font.family: Fonts.uiFont
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        color: root.profileColor
                    }

                }

            }

            // 2. Segmented Governor Switcher Pill
            Rectangle {
                width: parent.width
                height: 32
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.05)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.08)

                Row {
                    anchors.fill: parent
                    anchors.margins: 2
                    spacing: 2

                    // Saver Pill
                    Rectangle {
                        width: (parent.width - 4) / 3
                        height: parent.height
                        radius: 6
                        color: root.isSaver ? Theme.withAlpha(Theme.green, 0.22) : (saverHover.hovered ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                        border.width: root.isSaver ? 1 : 0
                        border.color: Theme.withAlpha(Theme.green, 0.45)

                        Row {
                            anchors.centerIn: parent
                            spacing: 4

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
                                font.weight: root.isSaver ? Font.Bold : Font.Normal
                                color: root.isSaver ? Theme.bright_foreground : Theme.muted
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

                    // Balanced Pill
                    Rectangle {
                        width: (parent.width - 4) / 3
                        height: parent.height
                        radius: 6
                        color: root.isBalanced ? Theme.withAlpha(Theme.cyan, 0.22) : (balHover.hovered ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                        border.width: root.isBalanced ? 1 : 0
                        border.color: Theme.withAlpha(Theme.cyan, 0.45)

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
                                text: "Bal"
                                font.family: Fonts.uiFont
                                font.pixelSize: 10
                                font.weight: root.isBalanced ? Font.Bold : Font.Normal
                                color: root.isBalanced ? Theme.bright_foreground : Theme.muted
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

                    // Turbo / Performance Pill
                    Rectangle {
                        width: (parent.width - 4) / 3
                        height: parent.height
                        radius: 6
                        color: root.isPerf ? Theme.withAlpha(Theme.red, 0.26) : (perfHover.hovered ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                        border.width: root.isPerf ? 1 : 0
                        border.color: Theme.withAlpha(Theme.red, 0.5)

                        Row {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: Icons.useMaterialSymbols ? "bolt" : "󰓅"
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: 12
                                color: root.isPerf ? Theme.red : Theme.muted
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Turbo"
                                font.family: Fonts.uiFont
                                font.pixelSize: 10
                                font.weight: root.isPerf ? Font.Bold : Font.Normal
                                color: root.isPerf ? Theme.bright_foreground : Theme.muted
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

            // 3. Compact Resource Telemetry Rows
            Rectangle {
                width: parent.width
                height: root.hardwareService.topProcess !== "" ? 138 : 112
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.035)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.07)

                Column {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 7

                    // CPU Meter Row
                    Column {
                        width: parent.width
                        spacing: 2

                        Item {
                            width: parent.width
                            height: 14

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "CPU Load"
                                font.family: Fonts.uiFont
                                font.pixelSize: 10
                                color: Theme.muted
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.hardwareService.cpuPercent + "%"
                                font.family: Fonts.monoFont
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: root.hardwareService.cpuPercent > 75 ? Theme.red : (root.hardwareService.cpuPercent > 40 ? Theme.yellow : Theme.bright_foreground)
                            }

                        }

                        Rectangle {
                            width: parent.width
                            height: 4
                            radius: 2
                            color: Qt.rgba(1, 1, 1, 0.1)

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Math.max(3, parent.width * (root.hardwareService.cpuPercent / 100))
                                radius: 2
                                color: root.hardwareService.cpuPercent > 75 ? Theme.red : (root.hardwareService.cpuPercent > 40 ? Theme.yellow : Theme.accent)
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

                    // Memory Meter Row
                    Column {
                        width: parent.width
                        spacing: 2

                        Item {
                            width: parent.width
                            height: 14

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Memory"
                                font.family: Fonts.uiFont
                                font.pixelSize: 10
                                color: Theme.muted
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.hardwareService.ramUsedGb + " / " + root.hardwareService.ramTotalGb + " GB"
                                font.family: Fonts.monoFont
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: root.hardwareService.ramPercent > 85 ? Theme.red : Theme.bright_foreground
                            }

                        }

                        Rectangle {
                            width: parent.width
                            height: 4
                            radius: 2
                            color: Qt.rgba(1, 1, 1, 0.1)

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Math.max(3, parent.width * (root.hardwareService.ramPercent / 100))
                                radius: 2
                                color: root.hardwareService.ramPercent > 85 ? Theme.red : Theme.cyan
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

                    // Temperature Row
                    Column {
                        width: parent.width
                        spacing: 2

                        Item {
                            width: parent.width
                            height: 14

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Core Temperature"
                                font.family: Fonts.uiFont
                                font.pixelSize: 10
                                color: Theme.muted
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.hardwareService.tempCelsius + "°C"
                                font.family: Fonts.monoFont
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: root.hardwareService.tempCelsius > 75 ? Theme.red : (root.hardwareService.tempCelsius > 55 ? Theme.yellow : Theme.green)
                            }

                        }

                        Rectangle {
                            width: parent.width
                            height: 4
                            radius: 2
                            color: Qt.rgba(1, 1, 1, 0.1)

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Math.max(3, Math.min(parent.width, parent.width * (root.hardwareService.tempCelsius / 100)))
                                radius: 2
                                color: root.hardwareService.tempCelsius > 75 ? Theme.red : (root.hardwareService.tempCelsius > 55 ? Theme.yellow : Theme.green)
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

                    // Divider
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.06)
                        visible: root.hardwareService.topProcess !== ""
                    }

                    // Top Consumer Task
                    Item {
                        width: parent.width
                        height: 14
                        visible: root.hardwareService.topProcess !== ""

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 5

                            Text {
                                text: Icons.useMaterialSymbols ? "local_fire_department" : "󰈸"
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: 11
                                color: Theme.yellow
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Top Task:"
                                font.family: Fonts.uiFont
                                font.pixelSize: 9
                                color: Theme.muted
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: root.hardwareService.topProcess
                                font.family: Fonts.monoFont
                                font.pixelSize: 9
                                font.weight: Font.Medium
                                color: Theme.bright_foreground
                                elide: Text.ElideRight
                                width: Math.min(implicitWidth, 120)
                                anchors.verticalCenter: parent.verticalCenter
                            }

                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.hardwareService.topProcessCpu
                            font.family: Fonts.monoFont
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            color: Theme.muted
                        }

                    }

                }

            }

            // 4. Quick Action Button (Open Activity Monitor)
            Rectangle {
                width: parent.width
                height: 28
                radius: 7
                color: btopHover.hovered ? Theme.withAlpha(Theme.accent, 0.2) : Qt.rgba(1, 1, 1, 0.05)
                border.width: 1
                border.color: btopHover.hovered ? Theme.withAlpha(Theme.accent, 0.45) : Qt.rgba(1, 1, 1, 0.1)

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: Icons.useMaterialSymbols ? "terminal" : "󰆍"
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: 12
                        color: btopHover.hovered ? Theme.bright_foreground : Theme.muted
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "System Monitor (btop)"
                        font.family: Fonts.uiFont
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: btopHover.hovered ? Theme.bright_foreground : Theme.muted
                        anchors.verticalCenter: parent.verticalCenter
                    }

                }

                HoverHandler {
                    id: btopHover
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached(["qdeck", "terminal", "btop"]);
                        root.toggle();
                    }
                }

            }

        }

    }

}
