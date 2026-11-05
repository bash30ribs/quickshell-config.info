import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../theme"

QtObject {
    id: root

    property int capacity: 100
    property string status: "Full"
    property string statusDisplay: "FULLY CHARGED"
    property bool isCharging: false
    property bool isPluggedIn: false
    property string batterySize: "84Wh"
    property string batteryHealth: "93%"
    property string cycleLabel: "Charge cycles"
    property string cycleCount: "177"
    property string timeLabel: "Time to full"
    property string timeToFull: "-"
    property string powerSource: "AC Power"
    property string rateLabel: "Charging rate"
    property string chargingRate: "-"

    readonly property string icon: Icons.battery(root.capacity, root.isCharging || root.isPluggedIn)

    function refresh() {
        if (!getBatteryProc.running) getBatteryProc.running = true
    }

    property FileView cycleOverrideFile: FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/battery-cycles"
        watchChanges: true
        printErrors: false
        onLoaded: root.refresh()
    }

    property Connections uPowerConn: Connections {
        target: UPower
        function onOnBatteryChanged() {
            root.refresh()
        }
    }

    property Connections uPowerDevConn: Connections {
        target: UPower.displayDevice
        function onStateChanged() {
            root.refresh()
        }
        function onPercentageChanged() {
            root.refresh()
        }
    }

    property Process getBatteryProc: Process {
        id: getBatteryProc
        command: ["qdeck-battery-info"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var data = JSON.parse(text.trim())
                    if (data) {
                        if (typeof data.capacity === "number") root.capacity = data.capacity
                        if (data.status) root.status = data.status
                        if (data.statusDisplay) root.statusDisplay = data.statusDisplay
                        if (typeof data.isCharging === "boolean") root.isCharging = data.isCharging
                        if (typeof data.isPluggedIn === "boolean") root.isPluggedIn = data.isPluggedIn
                        if (data.batterySize) root.batterySize = data.batterySize
                        if (data.batteryHealth) root.batteryHealth = data.batteryHealth
                        if (data.cycleLabel) root.cycleLabel = data.cycleLabel
                        if (data.cycleCount !== undefined) root.cycleCount = String(data.cycleCount)
                        if (data.timeLabel) root.timeLabel = data.timeLabel
                        if (data.timeToFull) root.timeToFull = data.timeToFull
                        if (data.powerSource) root.powerSource = data.powerSource
                        if (data.rateLabel) root.rateLabel = data.rateLabel
                        if (data.chargingRate) root.chargingRate = data.chargingRate
                    }
                } catch (e) {
                    // ignore json parsing errors
                }
            }
        }
    }

    property Timer pollTimer: Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
