// Helper functions for Launcher search and mode management

function normalizeText(text) {
    return String(text || "").toLowerCase().trim();
}

var KNOWN_ICON_MAP = {
    "antigravity": "file:///usr/share/pixmaps/antigravity.png",
    "antigravity-ide": "file:///usr/share/pixmaps/antigravity-ide.png",
    "antigravity-ide-url-handler": "file:///usr/share/pixmaps/antigravity-ide.png",
    "nwg-look": "file:///usr/share/pixmaps/nwg-look.svg",
    "pinentry": "file:///usr/share/pixmaps/pinentry.png",
    "spotify-launcher": "file:///usr/share/pixmaps/spotify-launcher.png",
    "network-wired": "file:///usr/share/icons/Adwaita/symbolic/devices/network-wired-symbolic.svg",
    "multimedia-photo-viewer": "file:///usr/share/icons/Adwaita/symbolic/categories/applications-multimedia-symbolic.svg"
};

function resolveIcon(icon) {
    if (!icon || icon === "") return "";
    var s = String(icon).trim();
    if (s.startsWith("file://") || s.startsWith("image://")) return s;
    if (s.startsWith("/")) return "file://" + s;

    var cleaned = s.replace(/\.(png|svg|xpm|ico)$/i, "");
    var lower = cleaned.toLowerCase();
    if (KNOWN_ICON_MAP[lower]) {
        return KNOWN_ICON_MAP[lower];
    }
    if (KNOWN_ICON_MAP[cleaned]) {
        return KNOWN_ICON_MAP[cleaned];
    }

    return "image://icon/" + cleaned;
}

// Apps mode filtering and sorting
function filterApps(apps, query) {
    var q = normalizeText(query);
    var results = [];
    if (!apps || !apps.length) return results;

    for (var i = 0; i < apps.length; i++) {
        var app = apps[i];
        if (!app || app.noDisplay) continue;

        var name = String(app.name || app.id || "").trim();
        if (!name) continue;

        var generic = String(app.genericName || "").trim();
        var comment = String(app.comment || "").trim();
        var id = String(app.id || "").trim();
        var keywords = "";
        try {
            if (app.keywords && Array.isArray(app.keywords)) {
                keywords = app.keywords.join(" ");
            }
        } catch (e) {}

        var score = 0;
        if (!q) {
            score = 1;
        } else {
            var nameLower = name.toLowerCase();
            var idLower = id.toLowerCase();
            var genericLower = generic.toLowerCase();
            var commentLower = comment.toLowerCase();
            var keywordsLower = keywords.toLowerCase();

            if (nameLower === q) score += 1000;
            else if (nameLower.startsWith(q)) score += 500;
            else if (nameLower.indexOf(q) !== -1) score += 200;
            else if (idLower.startsWith(q)) score += 150;
            else if (idLower.indexOf(q) !== -1) score += 100;
            else if (genericLower.indexOf(q) !== -1) score += 80;
            else if (keywordsLower.indexOf(q) !== -1) score += 50;
            else if (commentLower.indexOf(q) !== -1) score += 30;
            else {
                // Acronym search (e.g. "ide" matches "Antigravity IDE")
                var words = nameLower.split(/[\s\-_]+/);
                var acronym = "";
                for (var w = 0; w < words.length; w++) {
                    if (words[w]) acronym += words[w].charAt(0);
                }
                if (acronym.indexOf(q) !== -1) score += 40;
            }
        }

        if (score > 0) {
            results.push({
                type: "app",
                id: id,
                name: name,
                generic: generic,
                icon: resolveIcon(app.icon),
                score: score,
                entry: app
            });
        }
    }

    results.sort(function(a, b) {
        if (q) {
            if (b.score !== a.score) return b.score - a.score;
        }
        return a.name.localeCompare(b.name);
    });

    return results;
}

// Windows mode parsing
function parseWindows(rawJson, query) {
    var q = normalizeText(query);
    var results = [];
    if (!rawJson) return results;

    var list = [];
    try {
        list = JSON.parse(rawJson);
    } catch (e) {
        return results;
    }

    if (!Array.isArray(list)) return results;

    for (var i = 0; i < list.length; i++) {
        var w = list[i];
        if (!w || !w.mapped || w.hidden) continue;

        var title = String(w.title || "").trim();
        var winClass = String(w.class || w.initialClass || "").trim();
        var wsName = w.workspace ? String(w.workspace.name || w.workspace.id || "") : "";
        var addr = String(w.address || "");

        var name = title || winClass || "Window";
        var generic = winClass + (wsName ? " · WS " + wsName : "");

        var match = !q || name.toLowerCase().indexOf(q) !== -1 || winClass.toLowerCase().indexOf(q) !== -1 || wsName.toLowerCase().indexOf(q) !== -1;
        if (match) {
            results.push({
                type: "window",
                id: addr,
                address: addr,
                winClass: winClass,
                name: name,
                generic: generic,
                icon: resolveIcon(winClass.toLowerCase()),
                workspaceId: w.workspace ? w.workspace.id : 1
            });
        }
    }

    return results;
}

// Run commands filtering
function filterCommands(binaries, query) {
    var q = normalizeText(query);
    var results = [];

    // Always put typed query as first "Run" action if non-empty
    if (query && query.trim().length > 0) {
        results.push({
            type: "command",
            id: "cmd-custom",
            name: query.trim(),
            generic: "Run Command",
            icon: resolveIcon("system-run"),
            cmd: query.trim()
        });
    }

    if (!binaries || !binaries.length) return results;

    for (var i = 0; i < binaries.length; i++) {
        var b = binaries[i];
        if (!b) continue;
        if (!q || b.toLowerCase().indexOf(q) !== -1) {
            // Avoid duplicate with custom query
            if (query && b.toLowerCase() === q) continue;
            results.push({
                type: "command",
                id: "cmd-" + b,
                name: b,
                generic: "Command",
                icon: resolveIcon("utilities-terminal"),
                cmd: b
            });
            if (results.length >= 50) break;
        }
    }

    return results;
}

// Files mode parsing
function parseFiles(rawLines, query) {
    var q = normalizeText(query);
    var results = [];
    if (!rawLines) return results;

    var home = "";
    try {
        if (typeof Quickshell !== "undefined" && Quickshell.env) {
            home = Quickshell.env("HOME") || "";
        }
    } catch (e) {}

    var lines = String(rawLines).split("\n");
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (!line) continue;
        var parts = line.split("\t");
        var filename = parts[0] || "";
        var fullpath = parts[1] || line;
        var isDir = parts[2] === "d";

        if (!filename && fullpath) {
            var slashIdx = fullpath.lastIndexOf("/");
            filename = slashIdx >= 0 ? fullpath.substring(slashIdx + 1) : fullpath;
        }

        if (!filename) continue;

        if (!q || filename.toLowerCase().indexOf(q) !== -1 || fullpath.toLowerCase().indexOf(q) !== -1) {
            var displayPath = home ? fullpath.replace(home, "~") : fullpath.replace(/^\/home\/[^\/]+/, "~");
            results.push({
                type: "file",
                id: fullpath,
                name: filename,
                generic: displayPath,
                icon: isDir ? resolveIcon("folder") : resolveIcon("text-x-generic"),
                path: fullpath,
                isDir: isDir
            });
            if (results.length >= 50) break;
        }
    }

    return results;
}

/**
 * Launches a desktop application entry, routing terminal apps through kitty
 * since QuickShell's DesktopEntry.execute() does not honor runInTerminal.
 */
function launchAppEntry(item, execDetachedFn) {
    if (!item)
        return false;

    var entry = item.entry;
    if (entry && entry.runInTerminal && typeof execDetachedFn === "function") {
        var rawCmd = entry.command;
        var cmd = [];
        if (rawCmd && rawCmd.length > 0) {
            for (var i = 0; i < rawCmd.length; i++)
                cmd.push(rawCmd[i]);
        }
        if (cmd.length > 0) {
            var launchSpec = {
                command: ["kitty", "--"].concat(cmd)
            };
            if (entry.workingDirectory)
                launchSpec.workingDirectory = entry.workingDirectory;
            execDetachedFn(launchSpec);
            return true;
        }
    }

    try {
        if (entry && typeof entry.execute === "function") {
            entry.execute();
            return true;
        }
    } catch (e) {}

    if (item.id && typeof execDetachedFn === "function") {
        execDetachedFn(["gtk-launch", item.id]);
        return true;
    }
    return false;
}

// Safe recursive-descent math expression evaluator (no eval / Function)
function evaluateMath(rawQuery) {
    var s = String(rawQuery || "").trim();
    if (!s) return "";
    var explicit = s.charAt(0) === "=";
    if (explicit) s = s.slice(1).trim();
    if (!s || !/[0-9]/.test(s)) return "";
    if (!explicit && !(/[+\-*/%^()]/.test(s) || /^(sqrt|abs|sin|cos|tan|log|ln|round|floor|ceil|min|max)\s*\(/i.test(s)))
        return "";

    var pos = 0;
    function skipWs() { while (pos < s.length && /\s/.test(s.charAt(pos))) pos++; }
    function peek() { skipWs(); return pos < s.length ? s.charAt(pos) : ""; }

    function parsePrimary() {
        skipWs();
        if (pos >= s.length) throw new Error("EOF");
        var ch = s.charAt(pos);
        if (ch === "(") {
            pos++;
            var val = parseExpr();
            if (peek() !== ")") throw new Error("Missing )");
            pos++;
            return val;
        }
        if ((ch >= "0" && ch <= "9") || ch === ".") {
            var start = pos;
            var dots = 0;
            while (pos < s.length) {
                var c = s.charAt(pos);
                if (c >= "0" && c <= "9") pos++;
                else if (c === "." && dots === 0) { dots++; pos++; }
                else break;
            }
            var numStr = s.slice(start, pos);
            if (numStr === ".") throw new Error("Bad number");
            return parseFloat(numStr);
        }
        if (/[a-zA-Z]/.test(ch)) {
            var idStart = pos;
            while (pos < s.length && /[a-zA-Z0-9]/.test(s.charAt(pos))) pos++;
            var ident = s.slice(idStart, pos).toLowerCase();
            if (ident === "pi") return Math.PI;
            if (ident === "e") return Math.E;
            if (ident === "tau") return Math.PI * 2;
            if (peek() === "(") {
                pos++;
                var args = [parseExpr()];
                while (peek() === ",") {
                    pos++;
                    args.push(parseExpr());
                }
                if (peek() !== ")") throw new Error("Missing )");
                pos++;
                if (ident === "sqrt" && args.length === 1) return Math.sqrt(args[0]);
                if (ident === "abs" && args.length === 1) return Math.abs(args[0]);
                if (ident === "sin" && args.length === 1) return Math.sin(args[0]);
                if (ident === "cos" && args.length === 1) return Math.cos(args[0]);
                if (ident === "tan" && args.length === 1) return Math.tan(args[0]);
                if (ident === "log" && args.length === 1) return Math.log(args[0]) / Math.LN10;
                if (ident === "ln" && args.length === 1) return Math.log(args[0]);
                if (ident === "round" && args.length === 1) return Math.round(args[0]);
                if (ident === "floor" && args.length === 1) return Math.floor(args[0]);
                if (ident === "ceil" && args.length === 1) return Math.ceil(args[0]);
                if (ident === "min" && args.length >= 1) return Math.min.apply(null, args);
                if (ident === "max" && args.length >= 1) return Math.max.apply(null, args);
            }
            throw new Error("Unknown token");
        }
        throw new Error("Unexpected char");
    }

    function parseUnary() {
        var c = peek();
        if (c === "-") { pos++; return -parseUnary(); }
        if (c === "+") { pos++; return parseUnary(); }
        return parsePrimary();
    }

    function parsePower() {
        var base = parseUnary();
        if (peek() === "^") {
            pos++;
            return Math.pow(base, parsePower());
        }
        return base;
    }

    function parseTerm() {
        var left = parsePower();
        while (true) {
            var op = peek();
            if (op === "*") { pos++; left *= parsePower(); }
            else if (op === "/") { pos++; var d = parsePower(); if (d === 0) throw new Error("Div0"); left /= d; }
            else if (op === "%") { pos++; var m = parsePower(); if (m === 0) throw new Error("Div0"); left %= m; }
            else break;
        }
        return left;
    }

    function parseExpr() {
        var left = parseTerm();
        while (true) {
            var op = peek();
            if (op === "+") { pos++; left += parseTerm(); }
            else if (op === "-") { pos++; left -= parseTerm(); }
            else break;
        }
        return left;
    }

    try {
        var result = parseExpr();
        skipWs();
        if (pos !== s.length || typeof result !== "number" || !isFinite(result))
            return "";
        return String(Number(result.toPrecision(12)));
    } catch (e) {
        return "";
    }
}

function buildSpotlightResults(apps, windowsJson, query) {
    var raw = String(query || "");
    var trimmed = raw.trim();

    if (trimmed.indexOf(">") === 0) {
        var cmdStr = trimmed.slice(1).trim();
        if (!cmdStr) return [];
        return [{
            type: "command",
            id: "cmd-custom",
            name: cmdStr,
            generic: "Run command",
            badge: "RUN",
            glyph: "󰆍",
            icon: "",
            cmd: cmdStr
        }];
    }

    if (trimmed.indexOf("@") === 0) {
        var winsOnly = parseWindows(windowsJson, trimmed.slice(1));
        for (var wi = 0; wi < winsOnly.length; wi++) {
            winsOnly[wi].badge = "WINDOW";
            winsOnly[wi].glyph = "󰖯";
        }
        return winsOnly;
    }

    var results = [];
    var mathRes = evaluateMath(trimmed);
    if (mathRes !== "") {
        results.push({
            type: "math",
            id: "math-result",
            name: "= " + mathRes,
            value: mathRes,
            generic: "Press Enter to copy",
            badge: "CALC",
            glyph: "󰪚",
            icon: ""
        });
    }

    if (trimmed.indexOf("=") === 0 && results.length > 0)
        return results;

    var appMatches = filterApps(apps, trimmed);
    for (var ai = 0; ai < appMatches.length; ai++)
        results.push(appMatches[ai]);

    if (trimmed.length > 0 && windowsJson) {
        var winMatches = parseWindows(windowsJson, trimmed);
        var cap = Math.min(4, winMatches.length);
        for (var j = 0; j < cap; j++) {
            winMatches[j].badge = "WINDOW";
            winMatches[j].glyph = "󰖯";
            results.push(winMatches[j]);
        }
    }

    return results;
}

if (typeof module !== "undefined") {
    module.exports = {
        normalizeText: normalizeText,
        resolveIcon: resolveIcon,
        filterApps: filterApps,
        parseWindows: parseWindows,
        filterCommands: filterCommands,
        parseFiles: parseFiles,
        evaluateMath: evaluateMath,
        buildSpotlightResults: buildSpotlightResults,
        launchAppEntry: launchAppEntry
    };
}
