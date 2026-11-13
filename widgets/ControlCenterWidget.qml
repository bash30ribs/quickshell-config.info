import "../components"
import "../services"
import "../theme"
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property HardwareService hardwareService
    required property PowerService powerService
    property int iconSize: Appearance.barIconSize
    // ── btop / Arch Linux Color Tokens ─────────────────────────────────────────
    readonly property color btopBg: "#1e2326"
    readonly property color btopBoxBg: "#232a2e"
    readonly property color btopBorder: "#3d484d"
    readonly property color btopFg: "#d3c6aa"
    readonly property color btopMuted: "#9da9a0"
    readonly property color btopArchTeal: "#7fbbb3"
    readonly property color btopSage: "#a7c080"
    readonly property color btopAmber: "#dbbc7f"
    readonly property color btopRed: "#f85552"
    // Dynamic CPU palette (btop cpu meter)
    readonly property color cpuStartColor: {
        var c = root.hardwareService.cpuPercent;
        if (c > 75)
            return btopAmber;

        return btopSage;
    }
    readonly property color cpuEndColor: {
        var c = root.hardwareService.cpuPercent;
        if (c > 75)
            return btopRed;

        if (c > 40)
            return btopAmber;

        return btopSage;
    }
    // Dynamic RAM palette (btop memory meter)
    readonly property color ramStartColor: btopArchTeal
    readonly property color ramEndColor: {
        var r = root.hardwareService.ramPercent;
        if (r > 80)
            return btopRed;

        if (r > 60)
            return btopAmber;

        return "#83c092";
    }
    // Dynamic Temperature palette (btop temp graph)
    readonly property color tempStartColor: {
        var t = root.hardwareService.tempCelsius;
        if (t > 72)
            return btopAmber;

        return btopSage;
    }
    readonly property color tempEndColor: {
        var t = root.hardwareService.tempCelsius;
        if (t > 72)
            return btopRed;

        if (t > 54)
            return btopAmber;

        return btopSage;
    }

    function toggle() {
        usagePopup.toggle();
        if (usagePopup.open)
            root.hardwareService.refresh();

    }

    implicitWidth: usageButton.implicitWidth
    implicitHeight: usageButton.implicitHeight
    width: implicitWidth
    height: implicitHeight

    BarButton {
        id: usageButton

        icon: Icons.useMaterialSymbols ? "speed" : "󰓅"
        iconSize: root.iconSize
        active: usagePopup.open
        accentActive: root.hardwareService.powerProfile === "performance"
        customColor: {
            if (usagePopup.open)
                return root.btopArchTeal;

            if (root.hardwareService.powerProfile === "performance")
                return root.btopRed;

            if (root.hardwareService.powerProfile === "power-saver")
                return root.btopSage;

            return root.btopFg;
        }
        onClicked: {
            root.toggle();
        }
    }

    PopupCard {
        id: usagePopup

        anchorItem: usageButton
        showDefaultHeader: false
        contentWidth: 350
        contentHeight: mainCol.implicitHeight + 24

        Column {
            id: mainCol

            anchors.fill: parent
            spacing: 12

            // ── 1. Terminal Header ────────────────────────────────────────────
            Item {
                width: parent.width
                height: 34

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // Terminal prompt icon
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 6
                        color: root.btopBoxBg
                        border.color: root.btopBorder
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: Icons.useMaterialSymbols ? "terminal" : "󰆍"
                            font.family: Icons.effectiveFont(text)
                            font.pixelSize: Fonts.scale(14)
                            color: root.btopArchTeal
                        }

                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            text: "SYS::TELEMETRY"
                            font.family: Fonts.monoFont
                            font.pixelSize: Fonts.scale(12)
                            font.bold: true
                            color: root.btopFg
                        }

                        Text {
                            text: root.powerService.uptime ? ("uptime: " + root.powerService.uptime) : "btop core monitor"
                            font.family: Fonts.monoFont
                            font.pixelSize: Fonts.scale(9.5)
                            color: root.btopMuted
                        }

                    }

                }

                // Profile Indicator Capsule
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: profileLabel.implicitWidth + 18
                    height: 24
                    radius: 4
                    color: root.btopBoxBg
                    border.color: {
                        if (root.hardwareService.powerProfile === "performance")
                            return root.btopRed;

                        if (root.hardwareService.powerProfile === "power-saver")
                            return root.btopSage;

                        return root.btopArchTeal;
                    }
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: "●"
                            font.pixelSize: Fonts.scale(8)
                            color: {
                                if (root.hardwareService.powerProfile === "performance")
                                    return root.btopRed;

                                if (root.hardwareService.powerProfile === "power-saver")
                                    return root.btopSage;

                                return root.btopArchTeal;
                            }
                        }

                        Text {
                            id: profileLabel

                            text: root.hardwareService.powerProfile.toUpperCase()
                            font.family: Fonts.monoFont
                            font.pixelSize: Fonts.scale(9)
                            font.bold: true
                            color: root.btopFg
                        }

                    }

                }

            }

            // ── 2. Real-Time Resource Telemetry Box ───────────────────────────
            Rectangle {
                width: parent.width
                height: 160
                radius: 8
                antialiasing: true
                color: root.btopBoxBg
                border.color: root.btopBorder
                border.width: 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    // Box Section Title
                    Item {
                        width: parent.width
                        height: 14

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "┌─ [ METRICS ]"
                            font.family: Fonts.monoFont
                            font.pixelSize: Fonts.scale(9.5)
                            font.bold: true
                            color: root.btopArchTeal
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.hardwareService.ramUsedGb + " GiB / " + root.hardwareService.ramTotalGb + " GiB"
                            font.family: Fonts.monoFont
                            font.pixelSize: Fonts.scale(9)
                            font.bold: true
                            color: root.btopMuted
                        }

                    }

                    // 3 Precision Telemetry Gauges
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 18

                        // CPU Gauge (Sage -> Amber -> Red)
                        GlassCircularGauge {
                            value: root.hardwareService.cpuPercent
                            maxValue: 100
                            label: "CPU"
                            unit: "%"
                            accentColor: root.cpuStartColor
                            gradientEndColor: root.cpuEndColor
                            gaugeSize: 86
                            strokeWidth: 5
                        }

                        // RAM Gauge (Arch Teal -> Aqua)
                        GlassCircularGauge {
                            value: root.hardwareService.ramPercent
                            maxValue: 100
                            label: "MEM"
                            unit: "%"
                            accentColor: root.ramStartColor
                            gradientEndColor: root.ramEndColor
                            gaugeSize: 86
                            strokeWidth: 5
                        }

                        // Temperature Gauge (btop thermal progression)
                        GlassCircularGauge {
                            value: root.hardwareService.tempCelsius
                            maxValue: 100
                            label: "TEMP"
                            unit: "°"
                            accentColor: root.tempStartColor
                            gradientEndColor: root.tempEndColor
                            gaugeSize: 86
                            strokeWidth: 5
                        }

                    }

                    // Precision Memory Bar
                    Item {
                        width: parent.width
                        height: 6

                        // Recessed Track
                        Rectangle {
                            anchors.fill: parent
                            radius: 2
                            color: "#1e2326"
                            border.color: root.btopBorder
                            border.width: 1
                        }

                        // Memory Fill (Arch Teal)
                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.margins: 1
                            width: Math.max(0, Math.min(parent.width - 2, (parent.width - 2) * (root.hardwareService.ramPercent / 100)))
                            radius: 1
                            color: root.btopArchTeal
                            antialiasing: true

                            Behavior on width {
                                NumberAnimation {
                                    duration: 350
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                    }

                }

            }

            // ── 3. Energy & Power Governor Box ────────────────────────────────
            Rectangle {
                width: parent.width
                height: 76
                radius: 8
                antialiasing: true
                color: root.btopBoxBg
                border.color: root.btopBorder
                border.width: 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    Text {
                        text: "┌─ [ POWER GOVERNOR ]"
                        font.family: Fonts.monoFont
                        font.pixelSize: Fonts.scale(9.5)
                        font.bold: true
                        color: root.btopSage
                    }

                    Row {
                        width: parent.width
                        spacing: 8

                        // ── Power Saver Button ──
                        Rectangle {
                            width: (parent.width - 16) / 3
                            height: 32
                            radius: 4
                            color: root.hardwareService.powerProfile === "power-saver" ? "#2d353b" : "#1e2326"
                            border.color: root.hardwareService.powerProfile === "power-saver" ? root.btopSage : root.btopBorder
                            border.width: 1
                            scale: psMouse.pressed ? 0.97 : (psMouse.containsMouse ? 1.02 : 1)

                            Row {
                                anchors.centerIn: parent
                                spacing: 5

                                Text {
                                    text: Icons.useMaterialSymbols ? "eco" : "󰌪"
                                    font.family: Icons.effectiveFont(text)
                                    font.pixelSize: Fonts.scale(12)
                                    color: root.hardwareService.powerProfile === "power-saver" ? root.btopSage : root.btopMuted
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "saver"
                                    font.family: Fonts.monoFont
                                    font.pixelSize: Fonts.scale(10)
                                    font.bold: root.hardwareService.powerProfile === "power-saver"
                                    color: root.hardwareService.powerProfile === "power-saver" ? root.btopFg : root.btopMuted
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                            }

                            MouseArea {
                                id: psMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.hardwareService.setPowerProfile("power-saver")
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 120
                                }

                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: 140
                                }

                            }

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: 140
                                }

                            }

                        }

                        // ── Balanced Button ──
                        Rectangle {
                            width: (parent.width - 16) / 3
                            height: 32
                            radius: 4
                            color: root.hardwareService.powerProfile === "balanced" ? "#2d353b" : "#1e2326"
                            border.color: root.hardwareService.powerProfile === "balanced" ? root.btopArchTeal : root.btopBorder
                            border.width: 1
                            scale: balMouse.pressed ? 0.97 : (balMouse.containsMouse ? 1.02 : 1)

                            Row {
                                anchors.centerIn: parent
                                spacing: 5

                                Text {
                                    text: Icons.useMaterialSymbols ? "balance" : "󰈐"
                                    font.family: Icons.effectiveFont(text)
                                    font.pixelSize: Fonts.scale(12)
                                    color: root.hardwareService.powerProfile === "balanced" ? root.btopArchTeal : root.btopMuted
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "balanced"
                                    font.family: Fonts.monoFont
                                    font.pixelSize: Fonts.scale(10)
                                    font.bold: root.hardwareService.powerProfile === "balanced"
                                    color: root.hardwareService.powerProfile === "balanced" ? root.btopFg : root.btopMuted
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                            }

                            MouseArea {
                                id: balMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.hardwareService.setPowerProfile("balanced")
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 120
                                }

                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: 140
                                }

                            }

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: 140
                                }

                            }

                        }

                        // ── Performance Button ──
                        Rectangle {
                            width: (parent.width - 16) / 3
                            height: 32
                            radius: 4
                            color: root.hardwareService.powerProfile === "performance" ? "#2d353b" : "#1e2326"
                            border.color: root.hardwareService.powerProfile === "performance" ? root.btopRed : root.btopBorder
                            border.width: 1
                            scale: perfMouse.pressed ? 0.97 : (perfMouse.containsMouse ? 1.02 : 1)

                            Row {
                                anchors.centerIn: parent
                                spacing: 5

                                Text {
                                    text: Icons.useMaterialSymbols ? "bolt" : "󰓅"
                                    font.family: Icons.effectiveFont(text)
                                    font.pixelSize: Fonts.scale(12)
                                    color: root.hardwareService.powerProfile === "performance" ? root.btopRed : root.btopMuted
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "perf"
                                    font.family: Fonts.monoFont
                                    font.pixelSize: Fonts.scale(10)
                                    font.bold: root.hardwareService.powerProfile === "performance"
                                    color: root.hardwareService.powerProfile === "performance" ? root.btopFg : root.btopMuted
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                            }

                            MouseArea {
                                id: perfMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.hardwareService.setPowerProfile("performance")
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 120
                                }

                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: 140
                                }

                            }

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: 140
                                }

                            }

                        }

                    }

                }

            }

        }

    }

}
