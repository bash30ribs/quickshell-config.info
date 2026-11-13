import "../components"
import "../services"
import "../theme"
import QtQuick
import QtQuick.Layouts

Item {
    // Electric Cyan
    // Cyber Mint

    id: root

    required property HardwareService hardwareService
    required property PowerService powerService
    property int iconSize: Appearance.barIconSize
    // High-vibrancy dynamic temperature palette
    readonly property color tempStartColor: {
        var t = root.hardwareService.tempCelsius;
        if (t > 68)
            return "#FF0055";

        // Hyper Crimson
        if (t > 52)
            return "#FFB703";

        // Vivid Sunfire Amber
        return "#00F0FF";
    }
    readonly property color tempEndColor: {
        var t = root.hardwareService.tempCelsius;
        if (t > 68)
            return "#FF5500";

        // Solar Flare
        if (t > 52)
            return "#FF3366";

        // Neon Sunset Coral
        return "#00F5A0";
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
                return "#00F0FF";

            if (root.hardwareService.powerProfile === "performance")
                return "#FF3366";

            if (root.hardwareService.powerProfile === "power-saver")
                return "#00F5A0";

            return Theme.bright_foreground;
        }
        onClicked: {
            root.toggle();
        }
    }

    PopupCard {
        id: usagePopup

        anchorItem: usageButton
        showDefaultHeader: false
        contentWidth: 360
        contentHeight: mainCol.implicitHeight + 24

        Column {
            id: mainCol

            anchors.fill: parent
            spacing: 14

            // ── 1. Top Header & Active Status Capsule ─────────────────────────
            Item {
                width: parent.width
                height: 38

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    // Glowing icon circle
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: Theme.withAlpha("#00F0FF", 0.16)
                        border.color: Theme.withAlpha("#00F0FF", 0.5)
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: Icons.useMaterialSymbols ? "speed" : "󰓅"
                            font.family: Icons.effectiveFont(text)
                            font.pixelSize: Fonts.scale(16)
                            color: "#00F0FF"
                        }

                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "System Resources"
                            font.family: Fonts.uiFont
                            font.pixelSize: Fonts.scale(14)
                            font.bold: true
                            color: Theme.bright_foreground
                        }

                        Text {
                            text: root.powerService.uptime ? ("Uptime: " + root.powerService.uptime) : "Real-time Telemetry"
                            font.family: Fonts.uiFont
                            font.pixelSize: Fonts.scale(10)
                            color: Theme.glassLabel
                        }

                    }

                }

                // Profile Badge Capsule
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: profileLabel.implicitWidth + 22
                    height: 26
                    radius: 13
                    color: {
                        if (root.hardwareService.powerProfile === "performance")
                            return Theme.withAlpha("#FF3366", 0.25);

                        if (root.hardwareService.powerProfile === "power-saver")
                            return Theme.withAlpha("#00F5A0", 0.25);

                        return Theme.withAlpha("#00F0FF", 0.22);
                    }
                    border.color: {
                        if (root.hardwareService.powerProfile === "performance")
                            return "#FF3366";

                        if (root.hardwareService.powerProfile === "power-saver")
                            return "#00F5A0";

                        return "#00F0FF";
                    }
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            anchors.verticalCenter: parent.verticalCenter
                            color: {
                                if (root.hardwareService.powerProfile === "performance")
                                    return "#FF3366";

                                if (root.hardwareService.powerProfile === "power-saver")
                                    return "#00F5A0";

                                return "#00F0FF";
                            }
                        }

                        Text {
                            id: profileLabel

                            text: root.hardwareService.powerProfile.toUpperCase()
                            font.family: Fonts.uiFont
                            font.pixelSize: Fonts.scale(9.5)
                            font.bold: true
                            color: "#FFFFFF"
                        }

                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                        }

                    }

                    Behavior on border.color {
                        ColorAnimation {
                            duration: 200
                        }

                    }

                }

            }

            // ── 2. Real-Time Resource Telemetry Surface ───────────────────────
            Rectangle {
                width: parent.width
                height: 168
                radius: 18
                antialiasing: true
                color: Theme.withAlpha("#0A0E1A", 0.85)
                border.color: Theme.withAlpha("#00F0FF", 0.3)
                border.width: 1

                // Multi-tone top specular rim glow
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 1
                    height: 1.5
                    radius: parent.radius
                    color: Theme.withAlpha("#FFFFFF", 0.5)
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 11

                    // Section Title Row
                    Item {
                        width: parent.width
                        height: 14

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: "#00F0FF"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "LIVE TELEMETRY"
                                font.family: Fonts.uiFont
                                font.pixelSize: Fonts.scale(9)
                                font.bold: true
                                color: "#00F0FF"
                            }

                        }

                        // Memory stats pill
                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: ramText.implicitWidth + 12
                            height: 18
                            radius: 9
                            color: Theme.withAlpha("#00F5A0", 0.16)
                            border.color: Theme.withAlpha("#00F5A0", 0.35)
                            border.width: 1

                            Text {
                                id: ramText

                                anchors.centerIn: parent
                                text: root.hardwareService.ramUsedGb + " GB / " + root.hardwareService.ramTotalGb + " GB"
                                font.family: Fonts.monoFont
                                font.pixelSize: Fonts.scale(9.5)
                                font.bold: true
                                color: "#00F5A0"
                            }

                        }

                    }

                    // 3 Radiant High-Tech Gauges
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 20

                        // CPU Gauge: Electric Hyper Cyan -> Vivid Neon Violet
                        GlassCircularGauge {
                            value: root.hardwareService.cpuPercent
                            maxValue: 100
                            label: "CPU"
                            unit: "%"
                            accentColor: "#00F0FF"
                            gradientEndColor: "#B026FF"
                            gaugeSize: 92
                            strokeWidth: 7
                        }

                        // RAM Gauge: Cyber Spring Mint -> Electric Turquoise
                        GlassCircularGauge {
                            value: root.hardwareService.ramPercent
                            maxValue: 100
                            label: "RAM"
                            unit: "%"
                            accentColor: "#00F5A0"
                            gradientEndColor: "#00D9F5"
                            gaugeSize: 92
                            strokeWidth: 7
                        }

                        // Temperature Gauge: Dynamic Sunfire Embers
                        GlassCircularGauge {
                            value: root.hardwareService.tempCelsius
                            maxValue: 100
                            label: "TEMP"
                            unit: "°"
                            accentColor: root.tempStartColor
                            gradientEndColor: root.tempEndColor
                            gaugeSize: 92
                            strokeWidth: 7
                        }

                    }

                    // Micro Memory Track with Radiant Progress Bar
                    Item {
                        width: parent.width
                        height: 7

                        // Background Groove
                        Rectangle {
                            anchors.fill: parent
                            radius: 3.5
                            color: Theme.withAlpha("#00F5A0", 0.12)
                            border.color: Theme.withAlpha("#00F5A0", 0.22)
                            border.width: 1
                        }

                        // Active Neon Fill
                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: Math.max(0, Math.min(parent.width, parent.width * (root.hardwareService.ramPercent / 100)))
                            radius: 3.5
                            color: "#00F5A0"
                            antialiasing: true

                            // Specular gloss shine on bar
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                height: 2
                                radius: 1
                                color: Theme.withAlpha("#FFFFFF", 0.5)
                            }

                            Behavior on width {
                                NumberAnimation {
                                    duration: 400
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                    }

                }

            }

            // ── 3. Energy & Performance Profiles ──────────────────────────────
            Column {
                width: parent.width
                spacing: 8

                Item {
                    width: parent.width
                    height: 14

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: "#00F5A0"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "ENERGY & PERFORMANCE PROFILES"
                            font.family: Fonts.uiFont
                            font.pixelSize: Fonts.scale(9)
                            font.bold: true
                            color: Theme.bright_foreground
                        }

                    }

                }

                Row {
                    width: parent.width
                    spacing: 8

                    // ── Power Saver Button (Neon Emerald) ──
                    Rectangle {
                        width: (parent.width - 16) / 3
                        height: 40
                        radius: 12
                        color: root.hardwareService.powerProfile === "power-saver" ? Theme.withAlpha("#00F5A0", 0.25) : (psMouse.containsMouse ? Theme.withAlpha("#00F5A0", 0.14) : Theme.withAlpha("#0A0E1A", 0.7))
                        border.color: root.hardwareService.powerProfile === "power-saver" ? "#00F5A0" : (psMouse.containsMouse ? Theme.withAlpha("#00F5A0", 0.5) : Theme.withAlpha(Theme.glassBorderColor, 0.25))
                        border.width: root.hardwareService.powerProfile === "power-saver" ? 1.5 : 1
                        scale: psMouse.pressed ? 0.96 : (psMouse.containsMouse ? 1.025 : 1)

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: Icons.useMaterialSymbols ? "eco" : "󰌪"
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: Fonts.scale(14)
                                color: root.hardwareService.powerProfile === "power-saver" ? "#00F5A0" : Theme.foreground
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Saver"
                                font.family: Fonts.uiFont
                                font.pixelSize: Fonts.scale(11)
                                font.bold: root.hardwareService.powerProfile === "power-saver"
                                color: root.hardwareService.powerProfile === "power-saver" ? "#FFFFFF" : Theme.foreground
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
                                duration: 140
                                easing.type: Easing.OutQuad
                            }

                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 160
                            }

                        }

                        Behavior on border.color {
                            ColorAnimation {
                                duration: 160
                            }

                        }

                    }

                    // ── Balanced Button (Electric Cyan) ──
                    Rectangle {
                        width: (parent.width - 16) / 3
                        height: 40
                        radius: 12
                        color: root.hardwareService.powerProfile === "balanced" ? Theme.withAlpha("#00F0FF", 0.25) : (balMouse.containsMouse ? Theme.withAlpha("#00F0FF", 0.14) : Theme.withAlpha("#0A0E1A", 0.7))
                        border.color: root.hardwareService.powerProfile === "balanced" ? "#00F0FF" : (balMouse.containsMouse ? Theme.withAlpha("#00F0FF", 0.5) : Theme.withAlpha(Theme.glassBorderColor, 0.25))
                        border.width: root.hardwareService.powerProfile === "balanced" ? 1.5 : 1
                        scale: balMouse.pressed ? 0.96 : (balMouse.containsMouse ? 1.025 : 1)

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: Icons.useMaterialSymbols ? "balance" : "󰈐"
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: Fonts.scale(14)
                                color: root.hardwareService.powerProfile === "balanced" ? "#00F0FF" : Theme.foreground
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Balanced"
                                font.family: Fonts.uiFont
                                font.pixelSize: Fonts.scale(11)
                                font.bold: root.hardwareService.powerProfile === "balanced"
                                color: root.hardwareService.powerProfile === "balanced" ? "#FFFFFF" : Theme.foreground
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
                                duration: 140
                                easing.type: Easing.OutQuad
                            }

                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 160
                            }

                        }

                        Behavior on border.color {
                            ColorAnimation {
                                duration: 160
                            }

                        }

                    }

                    // ── Performance Button (Hyper Crimson) ──
                    Rectangle {
                        width: (parent.width - 16) / 3
                        height: 40
                        radius: 12
                        color: root.hardwareService.powerProfile === "performance" ? Theme.withAlpha("#FF3366", 0.28) : (perfMouse.containsMouse ? Theme.withAlpha("#FF3366", 0.14) : Theme.withAlpha("#0A0E1A", 0.7))
                        border.color: root.hardwareService.powerProfile === "performance" ? "#FF3366" : (perfMouse.containsMouse ? Theme.withAlpha("#FF3366", 0.5) : Theme.withAlpha(Theme.glassBorderColor, 0.25))
                        border.width: root.hardwareService.powerProfile === "performance" ? 1.5 : 1
                        scale: perfMouse.pressed ? 0.96 : (perfMouse.containsMouse ? 1.025 : 1)

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: Icons.useMaterialSymbols ? "bolt" : "󰓅"
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: Fonts.scale(14)
                                color: root.hardwareService.powerProfile === "performance" ? "#FF3366" : Theme.foreground
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Performance"
                                font.family: Fonts.uiFont
                                font.pixelSize: Fonts.scale(11)
                                font.bold: root.hardwareService.powerProfile === "performance"
                                color: root.hardwareService.powerProfile === "performance" ? "#FFFFFF" : Theme.foreground
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
                                duration: 140
                                easing.type: Easing.OutQuad
                            }

                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 160
                            }

                        }

                        Behavior on border.color {
                            ColorAnimation {
                                duration: 160
                            }

                        }

                    }

                }

            }

        }

    }

}
