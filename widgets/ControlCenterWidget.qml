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
        onClicked: {
            root.toggle();
        }
    }

    PopupCard {
        id: usagePopup

        anchorItem: usageButton
        showDefaultHeader: false
        contentWidth: 340
        contentHeight: mainCol.implicitHeight + 24

        Column {
            id: mainCol

            anchors.fill: parent
            spacing: 14

            // ── Top Header ───────────────────────────────────────────────────
            Item {
                width: parent.width
                height: 34

                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        text: "System Resources"
                        font.family: Fonts.uiFont
                        font.pixelSize: Fonts.scale(14)
                        font.bold: true
                        color: Theme.bright_foreground
                    }

                    Text {
                        text: root.powerService.uptime ? ("Uptime: " + root.powerService.uptime) : "Live Diagnostics"
                        font.family: Fonts.uiFont
                        font.pixelSize: Fonts.scale(10)
                        color: Theme.glassLabel
                    }

                }

                // Profile Badge
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: profileLabel.implicitWidth + 16
                    height: 24
                    radius: 12
                    color: root.hardwareService.powerProfile === "performance" ? Theme.withAlpha(Theme.red, 0.22) : (root.hardwareService.powerProfile === "power-saver" ? Theme.withAlpha(Theme.green, 0.22) : Theme.withAlpha(Theme.accent, 0.18))
                    border.color: root.hardwareService.powerProfile === "performance" ? Theme.withAlpha(Theme.red, 0.5) : (root.hardwareService.powerProfile === "power-saver" ? Theme.withAlpha(Theme.green, 0.5) : Theme.withAlpha(Theme.accent, 0.45))
                    border.width: 1

                    Text {
                        id: profileLabel

                        anchors.centerIn: parent
                        text: root.hardwareService.powerProfile.toUpperCase()
                        font.family: Fonts.uiFont
                        font.pixelSize: Fonts.scale(9)
                        font.bold: true
                        color: root.hardwareService.powerProfile === "performance" ? Theme.red : (root.hardwareService.powerProfile === "power-saver" ? Theme.green : Theme.accent)
                    }

                }

            }

            // ── Real-Time Resource Telemetry ─────────────────────────────────
            Rectangle {
                width: parent.width
                height: 124
                radius: 16
                color: Theme.withAlpha(Theme.glassCrest, 0.06)
                border.color: Theme.withAlpha(Theme.glassBorderColor, 0.16)
                border.width: 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    Item {
                        width: parent.width
                        height: 14

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "HARDWARE TELEMETRY"
                            font.family: Fonts.uiFont
                            font.pixelSize: Fonts.scale(9)
                            font.bold: true
                            color: Theme.glassLabel
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "RAM: " + root.hardwareService.ramUsedGb + " / " + root.hardwareService.ramTotalGb + " GB"
                            font.family: Fonts.uiFont
                            font.pixelSize: Fonts.scale(9)
                            font.weight: Fonts.weightMedium
                            color: Theme.glassLabel
                        }

                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 28

                        // CPU Gauge
                        GlassCircularGauge {
                            value: root.hardwareService.cpuPercent
                            label: "CPU"
                            unit: "%"
                            accentColor: Theme.accent
                        }

                        // RAM Gauge
                        GlassCircularGauge {
                            value: root.hardwareService.ramPercent
                            label: "RAM"
                            unit: "%"
                            accentColor: Theme.blue || Theme.accent
                        }

                        // Temperature Gauge
                        GlassCircularGauge {
                            value: root.hardwareService.tempCelsius
                            label: "TEMP"
                            unit: "°"
                            accentColor: root.hardwareService.tempCelsius > 75 ? Theme.red : (root.hardwareService.tempCelsius > 60 ? Theme.yellow : Theme.green)
                        }

                    }

                }

            }

            // ── System Optimization Profile Selector ─────────────────────────
            Column {
                width: parent.width
                spacing: 6

                Text {
                    text: "SYSTEM OPTIMIZATION"
                    font.family: Fonts.uiFont
                    font.pixelSize: Fonts.scale(9)
                    font.bold: true
                    color: Theme.glassLabel
                }

                Row {
                    width: parent.width
                    spacing: 8

                    // Power Saver
                    Rectangle {
                        width: (parent.width - 16) / 3
                        height: 34
                        radius: 12
                        color: root.hardwareService.powerProfile === "power-saver" ? Theme.withAlpha(Theme.green, 0.22) : (psMouse.containsMouse ? Theme.withAlpha(Theme.glassCrest, 0.14) : Theme.withAlpha(Theme.glassCrest, 0.06))
                        border.color: root.hardwareService.powerProfile === "power-saver" ? Theme.withAlpha(Theme.green, 0.6) : Theme.withAlpha(Theme.glassBorderColor, 0.2)
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                text: Icons.useMaterialSymbols ? "eco" : "󰌪"
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: Fonts.scale(12)
                                color: root.hardwareService.powerProfile === "power-saver" ? Theme.green : Theme.foreground
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Saver"
                                font.family: Fonts.uiFont
                                font.pixelSize: Fonts.scale(10)
                                font.bold: root.hardwareService.powerProfile === "power-saver"
                                color: root.hardwareService.powerProfile === "power-saver" ? Theme.green : Theme.foreground
                                anchors.verticalCenter: parent.verticalCenter
                            }

                        }

                        MouseArea {
                            id: psMouse

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.hardwareService.setPowerProfile("power-saver")
                        }

                    }

                    // Balanced
                    Rectangle {
                        width: (parent.width - 16) / 3
                        height: 34
                        radius: 12
                        color: root.hardwareService.powerProfile === "balanced" ? Theme.withAlpha(Theme.accent, 0.22) : (balMouse.containsMouse ? Theme.withAlpha(Theme.glassCrest, 0.14) : Theme.withAlpha(Theme.glassCrest, 0.06))
                        border.color: root.hardwareService.powerProfile === "balanced" ? Theme.withAlpha(Theme.accent, 0.6) : Theme.withAlpha(Theme.glassBorderColor, 0.2)
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                text: Icons.useMaterialSymbols ? "balance" : "󰈐"
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: Fonts.scale(12)
                                color: root.hardwareService.powerProfile === "balanced" ? Theme.accent : Theme.foreground
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Balanced"
                                font.family: Fonts.uiFont
                                font.pixelSize: Fonts.scale(10)
                                font.bold: root.hardwareService.powerProfile === "balanced"
                                color: root.hardwareService.powerProfile === "balanced" ? Theme.accent : Theme.foreground
                                anchors.verticalCenter: parent.verticalCenter
                            }

                        }

                        MouseArea {
                            id: balMouse

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.hardwareService.setPowerProfile("balanced")
                        }

                    }

                    // Performance
                    Rectangle {
                        width: (parent.width - 16) / 3
                        height: 34
                        radius: 12
                        color: root.hardwareService.powerProfile === "performance" ? Theme.withAlpha(Theme.red, 0.22) : (perfMouse.containsMouse ? Theme.withAlpha(Theme.glassCrest, 0.14) : Theme.withAlpha(Theme.glassCrest, 0.06))
                        border.color: root.hardwareService.powerProfile === "performance" ? Theme.withAlpha(Theme.red, 0.6) : Theme.withAlpha(Theme.glassBorderColor, 0.2)
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                text: Icons.useMaterialSymbols ? "bolt" : "󰓅"
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: Fonts.scale(12)
                                color: root.hardwareService.powerProfile === "performance" ? Theme.red : Theme.foreground
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Performance"
                                font.family: Fonts.uiFont
                                font.pixelSize: Fonts.scale(10)
                                font.bold: root.hardwareService.powerProfile === "performance"
                                color: root.hardwareService.powerProfile === "performance" ? Theme.red : Theme.foreground
                                anchors.verticalCenter: parent.verticalCenter
                            }

                        }

                        MouseArea {
                            id: perfMouse

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.hardwareService.setPowerProfile("performance")
                        }

                    }

                }

            }

        }

    }

}
