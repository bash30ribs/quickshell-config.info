import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool active: false
    property real level: 0
    property real bass: 0
    property real beat: 0
    property real speed: 0.85
    property bool hasSignal: false

    function resetState() {
        root.level = 0;
        root.bass = 0;
        root.beat = 0;
        root.speed = 0.85;
        root.hasSignal = false;
    }

    visible: false
    onActiveChanged: {
        if (!root.active) {
            restartTimer.stop();
            root.resetState();
        }
    }

    Timer {
        id: restartTimer

        interval: 1500
        repeat: false
        onTriggered: {
            if (root.active && !syncProc.running)
                syncProc.running = true;

        }
    }

    Process {
        id: syncProc

        command: ["qdeck-audio-sync"]
        running: root.active
        onExited: function(code, status) {
            if (root.active)
                restartTimer.restart();

        }

        stdout: SplitParser {
            onRead: function(line) {
                var parts = String(line || "").trim().split(/\s+/);
                if (parts.length < 4)
                    return ;

                var lv = parseFloat(parts[0]);
                var bs = parseFloat(parts[1]);
                var bt = parseFloat(parts[2]);
                var sp = parseFloat(parts[3]);
                if (isNaN(lv) || isNaN(bs) || isNaN(bt) || isNaN(sp))
                    return ;

                root.level = Math.max(0, Math.min(1, lv));
                root.bass = Math.max(0, Math.min(1, bs));
                root.beat = Math.max(0, Math.min(1, bt));
                root.speed = Math.max(0.35, Math.min(2.5, sp));
                root.hasSignal = (root.level > 0.005 || root.bass > 0.005 || root.beat > 0.005);
            }
        }

    }

}
