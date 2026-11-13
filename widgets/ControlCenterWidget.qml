import "../components"
import "../services"
import "../theme"
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property HardwareService hardwareService
    required property var notificationsService
    required property AudioService audioService
    required property BrightnessService brightnessService
    required property NetworkService networkService
    required property BluetoothService bluetoothService
    required property PowerService powerService
    property string currentTab: "controls" // "controls" | "notifications"
    property int iconSize: Appearance.barIconSize

    function toggle() {
        ccPopup.toggle();
        if (ccPopup.open) {
            root.hardwareService.refresh();
            root.notificationsService.markHistoryRead();
        }
    }

    function openTab(tabName) {
        root.currentTab = tabName;
        if (!ccPopup.open) {
            ccPopup.open = true;
            root.hardwareService.refresh();
            root.notificationsService.markHistoryRead();
        }
    }

    implicitWidth: ccButton.implicitWidth
    implicitHeight: ccButton.implicitHeight
    width: implicitWidth
    height: implicitHeight

    BarButton {
        id: ccButton

        icon: Icons.useMaterialSymbols ? "tune" : "󰒓"
        iconSize: root.iconSize
        active: ccPopup.open
        accentActive: root.notificationsService.unreadCount > 0 || root.notificationsService.doNotDisturb
        onClicked: {
            root.toggle();
        }

        // Unread notification badge dot
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 4
            width: 7
            height: 7
            radius: 3.5
            color: Theme.red
            visible: root.notificationsService.unreadCount > 0 && !ccPopup.open
            border.color: Theme.bright_foreground
            border.width: 1
        }

    }

    PopupCard {
        id: ccPopup

        anchorItem: ccButton
        showDefaultHeader: false
        contentWidth: 380
        contentHeight: mainCol.implicitHeight + 24

        Column {
            id: mainCol

            anchors.fill: parent
            spacing: 14

            // ── Top Header & Tab Pill Switcher ────────────────────────────────
            Item {
                width: parent.width
                height: 36

                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        text: "Control Center"
                        font.family: Fonts.uiFont
                        font.pixelSize: Fonts.scale(15)
                        font.bold: true
                        color: Theme.bright_foreground
                    }

                    Text {
                        text: root.powerService.uptime ? ("Uptime: " + root.powerService.uptime) : "System Status"
                        font.family: Fonts.uiFont
                        font.pixelSize: Fonts.scale(10)
                        color: Theme.glassLabel
                    }

                }

                // Tab Switcher Capsules
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    // Controls Tab Button
                    Rectangle {
                        width: 78
                        height: 28
                        radius: 14
                        color: root.currentTab === "controls" ? Theme.withAlpha(Theme.accent, 0.22) : Theme.withAlpha(Theme.glassCrest, 0.08)
                        border.color: root.currentTab === "controls" ? Theme.withAlpha(Theme.accent, 0.5) : Theme.withAlpha(Theme.glassBorderColor, 0.2)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "Controls"
                            font.family: Fonts.uiFont
                            font.pixelSize: Fonts.scale(11)
                            font.weight: root.currentTab === "controls" ? Fonts.weightBold : Fonts.weightMedium
                            color: root.currentTab === "controls" ? Theme.accent : Theme.foreground
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.currentTab = "controls"
                        }

                    }

                    // Notifications Tab Button
                    Rectangle {
                        width: 82
                        height: 28
                        radius: 14
                        color: root.currentTab === "notifications" ? Theme.withAlpha(Theme.accent, 0.22) : Theme.withAlpha(Theme.glassCrest, 0.08)
                        border.color: root.currentTab === "notifications" ? Theme.withAlpha(Theme.accent, 0.5) : Theme.withAlpha(Theme.glassBorderColor, 0.2)
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: "Alerts"
                                font.family: Fonts.uiFont
                                font.pixelSize: Fonts.scale(11)
                                font.weight: root.currentTab === "notifications" ? Fonts.weightBold : Fonts.weightMedium
                                color: root.currentTab === "notifications" ? Theme.accent : Theme.foreground
                            }

                            Rectangle {
                                width: 16
                                height: 16
                                radius: 8
                                color: root.notificationsService.historyModel.count > 0 ? Theme.accent : Theme.withAlpha(Theme.glassBorderColor, 0.3)
                                anchors.verticalCenter: parent.verticalCenter
                                visible: root.notificationsService.historyModel.count > 0

                                Text {
                                    anchors.centerIn: parent
                                    text: String(root.notificationsService.historyModel.count)
                                    font.family: Fonts.uiFont
                                    font.pixelSize: Fonts.scale(9)
                                    font.bold: true
                                    color: Theme.background
                                }

                            }

                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.currentTab = "notifications";
                                root.notificationsService.markHistoryRead();
                            }
                        }

                    }

                }

            }

            // ── VIEW 1: CONTROLS & HUD ───────────────────────────────────────
            Column {
                width: parent.width
                spacing: 14
                visible: root.currentTab === "controls"

                // 1. Quick Toggles (2 columns x 3 rows)
                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: 10
                    rowSpacing: 10

                    // Wi-Fi
                    GlassToggleTile {
                        icon: root.networkService.icon || (Icons.useMaterialSymbols ? "wifi" : "󰤨")
                        title: "Wi-Fi"
                        subtitle: root.networkService.currentSsid || (root.networkService.wifiEnabled ? "Searching..." : "Off")
                        active: root.networkService.wifiEnabled && root.networkService.currentSsid.length > 0
                        onClicked: root.networkService.toggleWifi()
                    }

                    // Bluetooth
                    GlassToggleTile {
                        icon: root.bluetoothService.icon || (Icons.useMaterialSymbols ? "bluetooth" : "󰂯")
                        title: "Bluetooth"
                        subtitle: root.bluetoothService.bluetoothEnabled ? (root.bluetoothService.connectedDevices.length > 0 ? (root.bluetoothService.connectedDevices.length + " Connected") : "On") : "Off"
                        active: root.bluetoothService.bluetoothEnabled
                        onClicked: root.bluetoothService.togglePower()
                    }

                    // Do Not Disturb
                    GlassToggleTile {
                        icon: root.notificationsService.doNotDisturb ? (Icons.useMaterialSymbols ? "notifications_off" : "󰂛") : (Icons.useMaterialSymbols ? "notifications" : "󰂚")
                        title: "Do Not Disturb"
                        subtitle: root.notificationsService.doNotDisturb ? "Active" : "Off"
                        active: root.notificationsService.doNotDisturb
                        activeColor: Theme.purple || Theme.accent
                        onClicked: {
                            root.notificationsService.doNotDisturb = !root.notificationsService.doNotDisturb;
                            root.notificationsService.saveSettings();
                        }
                    }

                    // Night Shift / Blue Light
                    GlassToggleTile {
                        icon: Icons.useMaterialSymbols ? "brightness_medium" : "󰃠"
                        title: "Night Shift"
                        subtitle: root.hardwareService.nightLight ? "4500K Warm" : "Standard"
                        active: root.hardwareService.nightLight
                        activeColor: Theme.yellow || Theme.accent
                        onClicked: root.hardwareService.toggleNightLight()
                    }

                    // Microphone Mute
                    GlassToggleTile {
                        icon: root.hardwareService.micMuted ? (Icons.useMaterialSymbols ? "mic_off" : "󰍭") : (Icons.useMaterialSymbols ? "mic" : "󰍬")
                        title: "Microphone"
                        subtitle: root.hardwareService.micMuted ? "Muted" : "Active"
                        active: !root.hardwareService.micMuted
                        activeColor: Theme.green || Theme.accent
                        onClicked: root.hardwareService.toggleMicMute()
                    }

                    // Power Profile
                    GlassToggleTile {
                        icon: Icons.useMaterialSymbols ? "speed" : "󰓅"
                        title: "Power Profile"
                        subtitle: {
                            var p = root.hardwareService.powerProfile;
                            return p.charAt(0).toUpperCase() + p.slice(1);
                        }
                        active: root.hardwareService.powerProfile === "performance"
                        activeColor: Theme.red || Theme.accent
                        onClicked: root.hardwareService.cyclePowerProfile()
                    }

                }

                // 2. Real-Time Hardware Telemetry Gauges
                Rectangle {
                    width: parent.width
                    height: 120
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
                                text: "SYSTEM TELEMETRY"
                                font.family: Fonts.uiFont
                                font.pixelSize: Fonts.scale(9)
                                font.weight: Fonts.weightBold
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
                            spacing: 34

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

                // 3. Precision Sliders
                Column {
                    width: parent.width
                    spacing: 10

                    // Volume
                    Rectangle {
                        width: parent.width
                        height: 44
                        radius: 12
                        color: Theme.withAlpha(Theme.glassCrest, 0.06)
                        border.color: Theme.withAlpha(Theme.glassBorderColor, 0.16)
                        border.width: 1

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            Text {
                                text: Icons.volumeLevel(root.audioService.volume, root.audioService.isMuted, false)
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: Fonts.scale(16)
                                color: root.audioService.isMuted ? Theme.muted : Theme.accent
                                anchors.verticalCenter: parent.verticalCenter

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.audioService.toggleMute()
                                }

                            }

                            Slider {
                                width: parent.width - 76
                                anchors.verticalCenter: parent.verticalCenter
                                value: root.audioService.volume
                                from: 0
                                to: 100
                                onMoved: function(v) {
                                    root.audioService.setVolume(v);
                                }
                            }

                            Text {
                                text: (root.audioService ? root.audioService.volume : 0) + "%"
                                font.family: Fonts.uiFont
                                font.pixelSize: Fonts.scale(11)
                                font.weight: Fonts.weightDemiBold
                                color: Theme.bright_foreground
                                anchors.verticalCenter: parent.verticalCenter
                                width: 34
                                horizontalAlignment: Text.AlignRight
                            }

                        }

                    }

                    // Brightness
                    Rectangle {
                        width: parent.width
                        height: 44
                        radius: 12
                        color: Theme.withAlpha(Theme.glassCrest, 0.06)
                        border.color: Theme.withAlpha(Theme.glassBorderColor, 0.16)
                        border.width: 1

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            Text {
                                text: Icons.brightnessLevel(root.brightnessService.brightness)
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: Fonts.scale(16)
                                color: Theme.accent
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Slider {
                                width: parent.width - 76
                                anchors.verticalCenter: parent.verticalCenter
                                value: root.brightnessService.brightness
                                from: 5
                                to: 100
                                onMoved: function(v) {
                                    root.brightnessService.setBrightness(v);
                                }
                            }

                            Text {
                                text: (root.brightnessService ? root.brightnessService.brightness : 100) + "%"
                                font.family: Fonts.uiFont
                                font.pixelSize: Fonts.scale(11)
                                font.weight: Fonts.weightDemiBold
                                color: Theme.bright_foreground
                                anchors.verticalCenter: parent.verticalCenter
                                width: 34
                                horizontalAlignment: Text.AlignRight
                            }

                        }

                    }

                }

                // 4. Quick Footer Actions
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12

                    // Lock Session
                    Rectangle {
                        width: 112
                        height: 32
                        radius: 16
                        color: lockMouse.containsMouse ? Theme.withAlpha(Theme.glassCrest, 0.16) : Theme.withAlpha(Theme.glassCrest, 0.08)
                        border.color: Theme.withAlpha(Theme.glassBorderColor, 0.2)
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: Icons.lock
                                font.family: Icons.effectiveFont(Icons.lock)
                                font.pixelSize: Fonts.scale(12)
                                color: Theme.foreground
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Lock"
                                font.family: Fonts.uiFont
                                font.pixelSize: Fonts.scale(11)
                                color: Theme.foreground
                                anchors.verticalCenter: parent.verticalCenter
                            }

                        }

                        MouseArea {
                            id: lockMouse

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                ccPopup.open = false;
                                root.powerService.lockSession();
                            }
                        }

                    }

                    // Suspend
                    Rectangle {
                        width: 112
                        height: 32
                        radius: 16
                        color: sleepMouse.containsMouse ? Theme.withAlpha(Theme.glassCrest, 0.16) : Theme.withAlpha(Theme.glassCrest, 0.08)
                        border.color: Theme.withAlpha(Theme.glassBorderColor, 0.2)
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: Icons.suspend
                                font.family: Icons.effectiveFont(Icons.suspend)
                                font.pixelSize: Fonts.scale(12)
                                color: Theme.foreground
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Sleep"
                                font.family: Fonts.uiFont
                                font.pixelSize: Fonts.scale(11)
                                color: Theme.foreground
                                anchors.verticalCenter: parent.verticalCenter
                            }

                        }

                        MouseArea {
                            id: sleepMouse

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                ccPopup.open = false;
                                root.powerService.suspendSystem();
                            }
                        }

                    }

                    // Power Menu Trigger
                    Rectangle {
                        width: 112
                        height: 32
                        radius: 16
                        color: pwrMouse.containsMouse ? Theme.withAlpha(Theme.red, 0.22) : Theme.withAlpha(Theme.glassCrest, 0.08)
                        border.color: Theme.withAlpha(Theme.glassBorderColor, 0.2)
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: Icons.power
                                font.family: Icons.effectiveFont(Icons.power)
                                font.pixelSize: Fonts.scale(12)
                                color: pwrMouse.containsMouse ? Theme.red : Theme.foreground
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Power"
                                font.family: Fonts.uiFont
                                font.pixelSize: Fonts.scale(11)
                                color: pwrMouse.containsMouse ? Theme.red : Theme.foreground
                                anchors.verticalCenter: parent.verticalCenter
                            }

                        }

                        MouseArea {
                            id: pwrMouse

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                ccPopup.open = false;
                                root.powerService.requestShutdown(null);
                            }
                        }

                    }

                }

            }

            // ── VIEW 2: NOTIFICATION CENTER & HISTORY ─────────────────────────
            Column {
                width: parent.width
                spacing: 10
                visible: root.currentTab === "notifications"

                // Header with Clear All
                Item {
                    width: parent.width
                    height: 28

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "RECENT NOTIFICATIONS"
                        font.family: Fonts.uiFont
                        font.pixelSize: Fonts.scale(10)
                        font.weight: Fonts.weightBold
                        color: Theme.glassLabel
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 84
                        height: 26
                        radius: 13
                        color: clearMouse.containsMouse ? Theme.withAlpha(Theme.red, 0.2) : Theme.withAlpha(Theme.glassCrest, 0.08)
                        border.color: Theme.withAlpha(Theme.glassBorderColor, 0.2)
                        border.width: 1
                        visible: root.notificationsService.historyModel.count > 0

                        Row {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: Icons.useMaterialSymbols ? "delete_sweep" : "󰆴"
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: Fonts.scale(11)
                                color: clearMouse.containsMouse ? Theme.red : Theme.foreground
                            }

                            Text {
                                text: "Clear All"
                                font.family: Fonts.uiFont
                                font.pixelSize: Fonts.scale(10)
                                color: clearMouse.containsMouse ? Theme.red : Theme.foreground
                            }

                        }

                        MouseArea {
                            id: clearMouse

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.notificationsService.clearHistory()
                        }

                    }

                }

                // Empty State
                Item {
                    width: parent.width
                    height: 260
                    visible: root.notificationsService.historyModel.count === 0

                    Column {
                        anchors.centerIn: parent
                        spacing: 10

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Icons.useMaterialSymbols ? "notifications_active" : "󰂚"
                            font.family: Icons.effectiveFont(text)
                            font.pixelSize: Fonts.scale(36)
                            color: Theme.withAlpha(Theme.accent, 0.45)
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "No Notifications"
                            font.family: Fonts.uiFont
                            font.pixelSize: Fonts.scale(13)
                            font.bold: true
                            color: Theme.foreground
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "You are all caught up!"
                            font.family: Fonts.uiFont
                            font.pixelSize: Fonts.scale(10)
                            color: Theme.glassLabel
                        }

                    }

                }

                // Scrollable Notifications List
                ListView {
                    id: historyList

                    width: parent.width
                    height: Math.min(380, count * 76)
                    clip: true
                    spacing: 8
                    model: root.notificationsService.historyModel
                    visible: count > 0

                    delegate: Rectangle {
                        id: notifCard

                        width: historyList.width
                        height: 68
                        radius: 12
                        color: cardMouse.containsMouse ? Theme.withAlpha(Theme.glassCrest, 0.14) : Theme.withAlpha(Theme.glassCrest, 0.06)
                        border.color: cardMouse.containsMouse ? Theme.withAlpha(Theme.accent, 0.4) : Theme.withAlpha(Theme.glassBorderColor, 0.16)
                        border.width: 1

                        Row {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            // App Icon / Glyph
                            Rectangle {
                                width: 34
                                height: 34
                                radius: 17
                                color: Theme.withAlpha(Theme.accent, 0.16)
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: model.glyph || (Icons.useMaterialSymbols ? "notifications" : "󰂚")
                                    font.family: Icons.effectiveFont(text)
                                    font.pixelSize: Fonts.scale(14)
                                    color: Theme.accent
                                }

                            }

                            // Notification Texts
                            Column {
                                width: parent.width - 76
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Item {
                                    width: parent.width
                                    height: 16

                                    Text {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: model.app || "System"
                                        font.family: Fonts.uiFont
                                        font.pixelSize: Fonts.scale(10)
                                        font.bold: true
                                        color: Theme.accent
                                        elide: Text.ElideRight
                                        width: parent.width - 60
                                    }

                                    Text {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: {
                                            var elapsed = Math.round((Date.now() - (model.timestamp || Date.now())) / 60000);
                                            if (elapsed <= 1)
                                                return "Just now";

                                            if (elapsed < 60)
                                                return elapsed + "m ago";

                                            return Math.round(elapsed / 60) + "h ago";
                                        }
                                        font.family: Fonts.uiFont
                                        font.pixelSize: Fonts.scale(9)
                                        color: Theme.glassLabel
                                    }

                                }

                                Text {
                                    text: model.summary || ""
                                    font.family: Fonts.uiFont
                                    font.pixelSize: Fonts.scale(11)
                                    font.weight: Fonts.weightDemiBold
                                    color: Theme.bright_foreground
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                Text {
                                    text: model.body || ""
                                    font.family: Fonts.uiFont
                                    font.pixelSize: Fonts.scale(10)
                                    color: Theme.foreground
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    width: parent.width
                                }

                            }

                            // Dismiss button
                            Rectangle {
                                width: 22
                                height: 22
                                radius: 11
                                anchors.verticalCenter: parent.verticalCenter
                                color: delMouse.containsMouse ? Theme.withAlpha(Theme.red, 0.3) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: Icons.useMaterialSymbols ? "close" : "󰅖"
                                    font.family: Icons.effectiveFont(text)
                                    font.pixelSize: Fonts.scale(10)
                                    color: delMouse.containsMouse ? Theme.red : Theme.glassLabel
                                }

                                MouseArea {
                                    id: delMouse

                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.notificationsService.removeHistoryItem(index)
                                }

                            }

                        }

                        MouseArea {
                            id: cardMouse

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                // Focus application if possible
                                if (model.app)
                                    Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "class:(?i)" + model.app]);

                                ccPopup.open = false;
                            }
                        }

                    }

                }

            }

        }

    }

}
