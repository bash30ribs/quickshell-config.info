import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // Live Telemetry
    property real cpuPercent: 0
    property real ramPercent: 0
    property string ramUsedGb: "0.0"
    property string ramTotalGb: "0.0"
    property int tempCelsius: 40
    // Quick Setting States
    property bool micMuted: false
    property bool nightLight: false
    property string powerProfile: "balanced"
    // Internal delta tracking for CPU calculation
    property real _lastIdle: 0
    property real _lastTotal: 0
    property bool _hasFirstCpuSample: false
    property Process telemetryProc

    telemetryProc: Process {
        id: telemetryProc

        // Single fast subshell reading cpu, memory, temp, mic mute, and power profile in parallel
        command: ["sh", "-c", "head -n 1 /proc/stat; " + "grep -E 'MemTotal|MemAvailable' /proc/meminfo; " + "cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0; " + "wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null || echo ''; " + "powerprofilesctl get 2>/dev/null || echo 'balanced'"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var lines = text.trim().split("\n");
                if (lines.length < 3)
                    return ;

                // 1. CPU line: cpu  user nice system idle iowait irq softirq steal guest guest_nice
                var cpuParts = lines[0].trim().split(/\s+/);
                if (cpuParts[0] === "cpu" && cpuParts.length >= 5) {
                    var user = parseFloat(cpuParts[1]) || 0;
                    var nice = parseFloat(cpuParts[2]) || 0;
                    var sys = parseFloat(cpuParts[3]) || 0;
                    var idle = parseFloat(cpuParts[4]) || 0;
                    var iowait = parseFloat(cpuParts[5]) || 0;
                    var irq = parseFloat(cpuParts[6]) || 0;
                    var softirq = parseFloat(cpuParts[7]) || 0;
                    var steal = parseFloat(cpuParts[8]) || 0;
                    var total = user + nice + sys + idle + iowait + irq + softirq + steal;
                    var idleTime = idle + iowait;
                    if (root._hasFirstCpuSample) {
                        var deltaTotal = total - root._lastTotal;
                        var deltaIdle = idleTime - root._lastIdle;
                        if (deltaTotal > 0) {
                            var usage = Math.max(0, Math.min(100, Math.round(100 * (1 - (deltaIdle / deltaTotal)))));
                            root.cpuPercent = usage;
                        }
                    } else {
                        root._hasFirstCpuSample = true;
                    }
                    root._lastTotal = total;
                    root._lastIdle = idleTime;
                }
                // 2. RAM parsing
                var memTotalKb = 0;
                var memAvailableKb = 0;
                var nextIdx = 1;
                while (nextIdx < lines.length && (lines[nextIdx].indexOf("MemTotal:") !== -1 || lines[nextIdx].indexOf("MemAvailable:") !== -1)) {
                    var l = lines[nextIdx];
                    if (l.indexOf("MemTotal:") !== -1)
                        memTotalKb = parseFloat(l.replace(/[^0-9]/g, "")) || 0;
                    else if (l.indexOf("MemAvailable:") !== -1)
                        memAvailableKb = parseFloat(l.replace(/[^0-9]/g, "")) || 0;
                    nextIdx++;
                }
                if (memTotalKb > 0 && memAvailableKb > 0) {
                    var usedKb = Math.max(0, memTotalKb - memAvailableKb);
                    root.ramPercent = Math.max(0, Math.min(100, Math.round((usedKb / memTotalKb) * 100)));
                    root.ramUsedGb = (usedKb / 1.04858e+06).toFixed(1);
                    root.ramTotalGb = (memTotalKb / 1.04858e+06).toFixed(1);
                }
                // 3. Temp line
                if (nextIdx < lines.length) {
                    var rawTemp = parseInt(lines[nextIdx].trim(), 10) || 0;
                    root.tempCelsius = rawTemp > 1000 ? Math.round(rawTemp / 1000) : rawTemp;
                    nextIdx++;
                }
                // 4. Mic line
                if (nextIdx < lines.length) {
                    var micStr = lines[nextIdx];
                    root.micMuted = micStr.indexOf("[MUTED]") !== -1;
                    nextIdx++;
                }
                // 5. Power profile line
                if (nextIdx < lines.length) {
                    var prof = lines[nextIdx].trim();
                    if (prof)
                        root.powerProfile = prof;

                }
            }
        }

    }

    property Timer refreshTimer

    refreshTimer: Timer {
        id: refreshTimer

        interval: 350
        repeat: false
        onTriggered: root.refresh()
    }

    property Timer pollTimer

    pollTimer: Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    function refresh() {
        if (!telemetryProc.running)
            telemetryProc.running = true;

    }

    function toggleMicMute() {
        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]);
        refreshTimer.restart();
    }

    function toggleNightLight() {
        root.nightLight = !root.nightLight;
        var shaderPath = root.nightLight ? (Quickshell.env("HOME") + "/.config/quickshell/effects/nightlight.frag") : "";
        var cmd = "hl.config({ decoration = { screen_shader = \"" + shaderPath + "\" } })";
        Quickshell.execDetached(["hyprctl", "eval", cmd]);
    }

    function cyclePowerProfile() {
        var next = "balanced";
        if (root.powerProfile === "balanced")
            next = "performance";
        else if (root.powerProfile === "performance")
            next = "power-saver";
        else
            next = "balanced";
        root.powerProfile = next;
        Quickshell.execDetached(["powerprofilesctl", "set", next]);
    }

    Component.onCompleted: root.refresh()
}
