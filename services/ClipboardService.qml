import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property var items: []
    property int imageCount: 0
    property int textCount: 0
    property int pinnedCount: 0
    property string copiedFeedbackId: ""
    readonly property string scriptPath: Quickshell.env("HOME") + "/.config/quickshell/src/qdeck-clipboard.py"
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/qdeck/clipboard"
    readonly property string historyPath: root.stateDir + "/history.json"
    property Timer copiedTimer
    property FileView historyFile
    property Process syncProc

    function parseHistory(raw) {
        var str = String(raw || "").trim();
        if (!str)
            return ;

        try {
            var parsed = JSON.parse(str);
            var arr = (parsed && Array.isArray(parsed.items)) ? parsed.items : (Array.isArray(parsed) ? parsed : []);
            var imgs = 0;
            var txts = 0;
            var pins = 0;
            for (var i = 0; i < arr.length; i++) {
                if (arr[i].type === "image")
                    imgs++;
                else
                    txts++;
                if (arr[i].pinned)
                    pins++;

            }
            root.imageCount = imgs;
            root.textCount = txts;
            root.pinnedCount = pins;
            root.items = arr;
        } catch (e) {
            console.warn("[ClipboardService] Failed to parse history JSON:", e);
        }
    }

    function syncNow() {
        if (!syncProc.running)
            syncProc.running = true;

    }

    function filteredItems(mode, query) {
        var list = root.items || [];
        var q = String(query || "").trim().toLowerCase();
        var out = [];
        for (var i = 0; i < list.length; i++) {
            var it = list[i];
            if (!it)
                continue;

            if (mode === "image" && it.type !== "image")
                continue;

            if (mode === "text" && it.type !== "text")
                continue;

            if (mode === "pinned" && !it.pinned)
                continue;

            if (q.length > 0) {
                var hay = "";
                if (it.type === "image")
                    hay = String(it.title || "") + " " + String(it.path || "") + " " + String(it.width || "") + "x" + String(it.height || "");
                else
                    hay = String(it.text || "");
                if (hay.toLowerCase().indexOf(q) === -1)
                    continue;

            }
            out.push(it);
        }
        return out;
    }

    function copyItem(itemId) {
        if (!itemId)
            return ;

        root.copiedFeedbackId = itemId;
        copiedTimer.restart();
        Quickshell.execDetached(["python3", root.scriptPath, "copy", itemId]);
    }

    function pasteItem(itemId) {
        if (!itemId)
            return ;

        root.copiedFeedbackId = itemId;
        copiedTimer.restart();
        Quickshell.execDetached(["python3", root.scriptPath, "paste", itemId]);
    }

    function togglePin(itemId) {
        if (!itemId)
            return ;

        Quickshell.execDetached(["python3", root.scriptPath, "pin", itemId]);
    }

    function deleteItem(itemId) {
        if (!itemId)
            return ;

        var list = root.items || [];
        var next = [];
        var imgs = 0;
        var txts = 0;
        var pins = 0;
        for (var i = 0; i < list.length; i++) {
            var it = list[i];
            if (!it || it.id === itemId)
                continue;

            next.push(it);
            if (it.type === "image")
                imgs++;
            else
                txts++;
            if (it.pinned)
                pins++;

        }
        root.imageCount = imgs;
        root.textCount = txts;
        root.pinnedCount = pins;
        root.items = next;
        Quickshell.execDetached(["python3", root.scriptPath, "delete", itemId]);
    }

    function clearUnpinned() {
        Quickshell.execDetached(["python3", root.scriptPath, "clear"]);
    }

    function annotateImage(filePath) {
        if (!filePath)
            return ;

        Quickshell.execDetached(["swappy", "-f", filePath]);
    }

    function captureSnap(mode) {
        var m = mode || "region";
        Quickshell.execDetached(["sh", "-c", "sleep 0.25 && qdeck screenshot clipboard " + m]);
    }

    function formatRelativeTime(ts) {
        if (!ts)
            return "";

        var diff = Math.max(0, Math.floor(Date.now() / 1000 - ts));
        if (diff < 15)
            return "just now";

        if (diff < 60)
            return diff + "s ago";

        var mins = Math.floor(diff / 60);
        if (mins < 60)
            return mins + "m ago";

        var hrs = Math.floor(mins / 60);
        if (hrs < 24)
            return hrs + "h ago";

        var days = Math.floor(hrs / 24);
        return days + "d ago";
    }

    function formatSize(bytes) {
        if (!bytes || bytes <= 0)
            return "";

        if (bytes < 1024)
            return bytes + " B";

        var kb = bytes / 1024;
        if (kb < 1024)
            return Math.round(kb) + " KB";

        return (kb / 1024).toFixed(1) + " MB";
    }

    Component.onCompleted: {
        Quickshell.execDetached(["python3", root.scriptPath, "daemon"]);
        syncNow();
    }

    copiedTimer: Timer {
        interval: 1400
        repeat: false
        onTriggered: {
            root.copiedFeedbackId = "";
        }
    }

    historyFile: FileView {
        path: root.historyPath
        watchChanges: true
        printErrors: false
        onLoaded: {
            root.parseHistory(text());
        }
    }

    syncProc: Process {
        command: ["python3", root.scriptPath, "sync"]
        onExited: function() {
            root.historyFile.reload();
        }
    }

}
