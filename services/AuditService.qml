import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    readonly property string currentReportPath: Quickshell.env("HOME") + "/.local/state/qdeck/audit/current_session_report.txt"
    readonly property string lastReportPath: Quickshell.env("HOME") + "/.local/state/qdeck/audit/last_session_report.txt"
    readonly property string activityLogPath: Quickshell.env("HOME") + "/.local/state/qdeck/audit/activity.log"

    // File viewers for instant cached reads
    FileView {
        id: currentReportFile

        path: root.currentReportPath
    }

    FileView {
        id: lastReportFile

        path: root.lastReportPath
    }

    FileView {
        id: activityLogFile

        path: root.activityLogPath
    }

    // Process helper to control daemon
    Process {
        id: auditProc

        command: ["qdeck-audit"]
    }

    IpcHandler {
        function report() : string {
            return currentReportFile.text() || "No active audit report found.";
        }

        function last() : string {
            return lastReportFile.text() || "No previous session report found.";
        }

        function log() : string {
            return activityLogFile.text() || "No activity log entries found.";
        }

        function status() : string {
            auditProc.arguments = ["status"];
            auditProc.running = true;
            return "ok";
        }

        function start() : string {
            auditProc.arguments = ["start"];
            auditProc.running = true;
            return "started";
        }

        function stop() : string {
            auditProc.arguments = ["stop"];
            auditProc.running = true;
            return "stopped";
        }

        target: "audit"
    }

}
