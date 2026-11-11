import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

QtObject {
    id: root

    // Central single source of truth path for colors configuration
    readonly property string colorsConfigPath: Quickshell.env("HOME") + "/.config/themes/current/colors.toml"
    readonly property string localColorsPath: (Quickshell.env("QS_CONFIG_PATH") || (Quickshell.env("HOME") + "/.config/quickshell")) + "/theme/colors.toml"
    readonly property string blurStatePath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell/blur-state"
    // Raw parsed colors dictionary
    property var _c: ({
    })
    // Surfaces & Backgrounds
    readonly property color background: _c.background || "#1a1b26"
    readonly property color dark_background: _c.dark_background || _c.color0 || Qt.darker(root.background, 1.25)
    readonly property color darker_background: _c.darker_background || Qt.darker(root.background, 1.45)
    readonly property color lighter_background: _c.lighter_background || Qt.lighter(root.background, 1.25)
    // Primary Accents (dynamically harmonized with active wallpaper)
    readonly property color accent: (root.hasWallpaperColors && root.wallpaperAccent) ? root.wallpaperAccent : (_c.accent || _c.color4 || "#7aa2f7")
    readonly property color selection: (root.hasWallpaperColors && root.wallpaperSelection) ? root.wallpaperSelection : (_c.selection || _c.color0 || "#292e42")
    readonly property color muted: _c.muted || _c.color8 || "#7a8478"
    // Typography & Foregrounds
    readonly property color foreground: _c.foreground || "#a9b1d6"
    readonly property color dark_foreground: _c.dark_foreground || _c.color8 || Qt.darker(root.foreground, 1.35)
    readonly property color light_foreground: _c.light_foreground || _c.color7 || Qt.lighter(root.foreground, 1.1)
    readonly property color bright_foreground: _c.bright_foreground || _c.color15 || _c.cursor || "#ffffff"
    // Semantic & Accent Palette
    readonly property color red: _c.red || _c.color1 || "#f7768e"
    readonly property color urgent: root.red
    readonly property color yellow: _c.yellow || _c.color3 || "#e0af68"
    readonly property color orange: _c.orange || _c.color3 || "#eb927b"
    readonly property color green: _c.green || _c.color2 || "#9ece6a"
    readonly property color cyan: _c.cyan || _c.color6 || "#449dab"
    readonly property color blue: _c.blue || _c.color4 || root.accent
    readonly property color magenta: _c.magenta || _c.color5 || "#ad8ee6"
    readonly property color brown: _c.brown || Qt.darker(root.yellow, 1.4)
    // High-Vibrancy Variants
    readonly property color bright_red: _c.bright_red || _c.color9 || root.red
    readonly property color bright_yellow: _c.bright_yellow || _c.color11 || root.yellow
    readonly property color bright_green: _c.bright_green || _c.color10 || root.green
    readonly property color bright_cyan: _c.bright_cyan || _c.color14 || root.cyan
    readonly property color bright_blue: _c.bright_blue || _c.color12 || root.blue
    readonly property color bright_magenta: _c.bright_magenta || _c.color13 || root.magenta
    // High-Contrast Glass Typography Tokens
    readonly property color glassText: root.bright_foreground
    readonly property color glassLabel: root.withAlpha(root.foreground, 0.72)
    readonly property color glassSubtext: root.withAlpha(root.foreground, 0.58)
    // ─────────────────────────────────────────────────────────────────────────
    // Dynamic Wallpaper & Harmony Palette
    // Harmonizes wallpaper tones with theme colors for the bar & widgets
    // ─────────────────────────────────────────────────────────────────────────
    property var _wp: ({
    })
    property string wallpaperAccent: (_wp && _wp.accent) ? _wp.accent : ""
    property string wallpaperSelection: (_wp && _wp.selection) ? _wp.selection : ""
    property string wallpaperDominant: (_wp && _wp.dominant) ? _wp.dominant : ""
    property string wallpaperGlassTint: (_wp && _wp.glass_tint) ? _wp.glass_tint : ""
    property string wallpaperGlassCrest: (_wp && _wp.glass_crest) ? _wp.glass_crest : ""
    property string wallpaperGlassBorder: (_wp && _wp.glass_border) ? _wp.glass_border : ""
    readonly property bool hasWallpaperColors: root.wallpaperAccent.length > 0
    readonly property bool isLightWallpaper: (_wp && _wp.is_light_wallpaper) ? true : false
    readonly property color barBackground: root.isLightWallpaper ? root.darker_background : root.background
    readonly property color barDarkBackground: root.darker_background
    readonly property color barLighterBackground: root.dark_background
    readonly property color barAccent: root.accent
    readonly property color barDominant: (root.hasWallpaperColors && root.wallpaperDominant) ? root.wallpaperDominant : root.foreground
    readonly property color glassTint: (root.hasWallpaperColors && root.wallpaperGlassTint) ? root.wallpaperGlassTint : root.accent
    readonly property color glassSurface: (root.hasWallpaperColors && _wp.glass_surface) ? _wp.glass_surface : root.lighter_background
    readonly property color glassCrest: (root.hasWallpaperColors && root.wallpaperGlassCrest) ? root.wallpaperGlassCrest : root.light_foreground
    readonly property color glassBorderColor: (root.hasWallpaperColors && root.wallpaperGlassBorder) ? root.wallpaperGlassBorder : root.accent
    readonly property color barBorderColor: root.withAlpha(root.glassBorderColor, 0.35)
    // ─────────────────────────────────────────────────────────────────────────
    // Glassmorphism & Frosted Glass Tokens (Apple-grade Smoked Liquid Glass)
    // ─────────────────────────────────────────────────────────────────────────
    readonly property real glassOpacity: 0.42
    readonly property real glassPillOpacity: 0.16
    readonly property color glassBorder: root.hasWallpaperColors ? Qt.tint(Qt.rgba(255, 255, 255, 0.2), root.withAlpha(root.glassBorderColor, 0.28)) : Qt.rgba(255, 255, 255, 0.2)
    readonly property color glassBorderLight: Qt.rgba(255, 255, 255, 0.26)
    readonly property color glassSpecular: Qt.rgba(255, 255, 255, 0.28)
    readonly property color glassInnerSheen: Qt.rgba(255, 255, 255, 0.08)
    readonly property color glassBounce: Qt.rgba(255, 255, 255, 0.04)
    readonly property color glassWidgetBg: Qt.rgba(0, 0, 0, 0.25)
    readonly property color glassWidgetBorder: Qt.rgba(255, 255, 255, 0.08)
    readonly property color glassHover: root.withAlpha(root.accent, 0.12)
    readonly property color glassHoverBorder: root.withAlpha(root.accent, 0.35)
    readonly property color glassActive: root.withAlpha(root.accent, 0.25)
    readonly property color glassActiveBorder: root.accent
    readonly property real glassPopupOpacity: 0.46
    // ─────────────────────────────────────────────────────────────────────────
    // Dual Alpha + Compositor Blur Architecture
    // ─────────────────────────────────────────────────────────────────────────
    property bool blurEnabled: true
    readonly property real baseOpacity: root.blurEnabled ? Appearance.baseOpacity : 1
    readonly property real elevatedOpacity: root.blurEnabled ? Appearance.elevatedOpacity : 1
    readonly property real layerOpacity: Appearance.layerOpacity
    readonly property real scrimOpacity: Appearance.scrimOpacity
    // IPC Interface for theme / blur control
    property IpcHandler ipcHandler
    // ─────────────────────────────────────────────────────────────────────────
    // Typography & Metrics Bridges (Centralized in Fonts & Appearance)
    // ─────────────────────────────────────────────────────────────────────────
    property int baseTextSize: Fonts.baseTextSize
    readonly property string fontFamily: Fonts.uiFont
    readonly property int fontSizeSmall: Fonts.sizeSmall
    readonly property int fontSizeRegular: Fonts.sizeRegular
    readonly property int fontSizeMedium: Fonts.sizeMedium
    readonly property int fontSizeLarge: Fonts.sizeLarge
    readonly property int fontSizeTitle: Fonts.sizeTitle
    readonly property int barHeight: Appearance.barHeight
    readonly property int radiusSmall: Appearance.radiusSmall
    readonly property int radiusMedium: Appearance.radiusMedium
    readonly property int radiusLarge: Appearance.radiusLarge
    readonly property int animDuration: Appearance.animDurationNormal
    property FileView blurStateFile
    property FileView colorsFile
    property FileView fallbackColorsFile
    property Process themeReaderProc
    readonly property string wallpaperPaletteStatePath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/qdeck/wallpaper-palette.json"
    property FileView wallpaperPaletteFile
    readonly property string wallpaperPaletteScript: (Quickshell.env("QS_CONFIG_PATH") || (Quickshell.env("HOME") + "/.config/quickshell")) + "/src/qdeck-wallpaper-palette.py"
    property Process wallpaperPaletteProc
    property string _lastCurrentTarget: ""
    property string _lastWallpaperTarget: ""
    property Process linkCheckProc
    property Timer symlinkWatcherTimer

    function withAlpha(colorVal, alphaVal) {
        return Qt.rgba(colorVal.r, colorVal.g, colorVal.b, alphaVal);
    }

    function wheelDeltaY(event) {
        if (!event)
            return 0;

        var ay = event.angleDelta ? Number(event.angleDelta.y || 0) : 0;
        var py = event.pixelDelta ? Number(event.pixelDelta.y || 0) * 2 : 0;
        return (Math.abs(ay) >= Math.abs(py)) ? ay : py;
    }

    function wheelDeltaX(event) {
        if (!event)
            return 0;

        var ax = event.angleDelta ? Number(event.angleDelta.x || 0) : 0;
        var px = event.pixelDelta ? Number(event.pixelDelta.x || 0) * 2 : 0;
        return (Math.abs(ax) >= Math.abs(px)) ? ax : px;
    }

    function setBlurState(enabled) {
        root.blurEnabled = enabled;
        var stateStr = enabled ? "on" : "off";
        var cmd = "mkdir -p \"$(dirname \"" + root.blurStatePath + "\")\" && printf '%s' \"" + stateStr + "\" > \"" + root.blurStatePath + "\"";
        if (enabled)
            cmd += " && hyprctl eval 'hl.layer_rule({ name = \"qdeck-blur\", match = { namespace = \"^quickshell-.*\" }, blur = true, blur_popups = true, ignore_alpha = 0.14 })' 2>/dev/null || true";
        else
            cmd += " && hyprctl eval 'hl.layer_rule({ name = \"qdeck-blur\", match = { namespace = \"^quickshell-.*\" }, blur = false, blur_popups = false })' 2>/dev/null || true";
        Quickshell.execDetached(["sh", "-c", cmd]);
    }

    function parseThemeFile(rawText) {
        var lines = String(rawText || "").split("\n");
        var map = {
        };
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (!line || line.startsWith("#") || line.startsWith(";"))
                continue;

            var eqIdx = line.indexOf("=");
            if (eqIdx < 1)
                continue;

            var key = line.slice(0, eqIdx).trim();
            var rawVal = line.slice(eqIdx + 1).trim();
            var val = "";
            var quotedMatch = rawVal.match(/^["']([^"']*)["']/);
            if (quotedMatch) {
                val = quotedMatch[1].trim();
            } else {
                var hashIdx = rawVal.indexOf("#");
                var semiIdx = rawVal.indexOf(";");
                var cutIdx = -1;
                if (hashIdx !== -1 && semiIdx !== -1)
                    cutIdx = Math.min(hashIdx, semiIdx);
                else if (hashIdx !== -1)
                    cutIdx = hashIdx;
                else if (semiIdx !== -1)
                    cutIdx = semiIdx;
                if (cutIdx !== -1)
                    val = rawVal.slice(0, cutIdx).trim();
                else
                    val = rawVal.trim();
                val = val.replace(/^['"]+|['";\s]+$/g, "").trim();
            }
            if (val)
                map[key] = val;

        }
        root._c = map;
    }

    function applyPalette(parsed) {
        if (!parsed || !parsed.accent)
            return ;

        root.wallpaperAccent = parsed.accent;
        root.wallpaperSelection = parsed.selection || "";
        root.wallpaperDominant = parsed.dominant || "";
        root.wallpaperGlassTint = parsed.glass_tint || "";
        root.wallpaperGlassCrest = parsed.glass_crest || "";
        root.wallpaperGlassBorder = parsed.glass_border || "";
        root._wp = parsed;
    }

    function updateWallpaper(targetPath) {
        var p = String(targetPath || "").trim();
        if (p.length > 0) {
            root._lastWallpaperTarget = p;
            wallpaperPaletteProc.command = ["python3", root.wallpaperPaletteScript, p];
        } else {
            wallpaperPaletteProc.command = ["python3", root.wallpaperPaletteScript];
        }
        if (!wallpaperPaletteProc.running)
            wallpaperPaletteProc.running = true;

    }

    function reloadWallpaperPalette() {
        if (root._lastWallpaperTarget && root._lastWallpaperTarget.length > 0)
            wallpaperPaletteProc.command = ["python3", root.wallpaperPaletteScript, root._lastWallpaperTarget];
        else
            wallpaperPaletteProc.command = ["python3", root.wallpaperPaletteScript];
        if (!wallpaperPaletteProc.running)
            wallpaperPaletteProc.running = true;

    }

    function reloadTheme() {
        if (!themeReaderProc.running)
            themeReaderProc.running = true;

        root.reloadWallpaperPalette();
    }

    onBaseTextSizeChanged: {
        if (Fonts.baseTextSize !== baseTextSize)
            Fonts.baseTextSize = baseTextSize;

    }
    Component.onCompleted: {
        root.reloadTheme();
        if (wallpaperPaletteFile.text()) {
            try {
                var pInit = JSON.parse(wallpaperPaletteFile.text());
                if (pInit && pInit.accent)
                    root.applyPalette(pInit);

            } catch (e) {
            }
        }
        root.reloadWallpaperPalette();
        if (colorsFile.text())
            root.parseThemeFile(colorsFile.text());
        else if (fallbackColorsFile.text())
            root.parseThemeFile(fallbackColorsFile.text());
        var rawBlur = String(blurStateFile.text() || "").trim().toLowerCase();
        if (rawBlur === "off" || rawBlur === "false" || rawBlur === "0") {
            root.blurEnabled = false;
            root.setBlurState(false);
        } else {
            root.blurEnabled = true;
            root.setBlurState(true);
        }
    }

    ipcHandler: IpcHandler {
        function reload() : string {
            root.reloadTheme();
            return "reloaded";
        }

        function reloadWallpaper() : string {
            root.reloadWallpaperPalette();
            return "reloaded-wallpaper";
        }

        function setWallpaper(path: string) : string {
            root.updateWallpaper(path);
            return "ok";
        }

        function getPalette() : string {
            return JSON.stringify(root._wp || {
            });
        }

        function toggleBlur() : string {
            root.setBlurState(!root.blurEnabled);
            return root.blurEnabled ? "on" : "off";
        }

        function setBlur(mode: string) : string {
            var m = String(mode || "").trim().toLowerCase();
            if (m === "on" || m === "true" || m === "1")
                root.setBlurState(true);
            else if (m === "off" || m === "false" || m === "0")
                root.setBlurState(false);
            return root.blurEnabled ? "on" : "off";
        }

        function getBlur() : string {
            return root.blurEnabled ? "on" : "off";
        }

        target: "theme"
    }

    blurStateFile: FileView {
        path: root.blurStatePath
        watchChanges: true
        printErrors: false
        onLoaded: {
            var raw = String(text() || "").trim().toLowerCase();
            if (raw === "off" || raw === "false" || raw === "0") {
                if (root.blurEnabled)
                    root.blurEnabled = false;

            } else if (raw === "on" || raw === "true" || raw === "1") {
                if (!root.blurEnabled)
                    root.blurEnabled = true;

            }
        }
    }

    colorsFile: FileView {
        path: root.colorsConfigPath
        watchChanges: true
        printErrors: false
        onLoaded: {
            if (text())
                root.parseThemeFile(text());

        }
    }

    fallbackColorsFile: FileView {
        path: root.localColorsPath
        watchChanges: true
        printErrors: false
        onLoaded: {
            if (!colorsFile.text() && text())
                root.parseThemeFile(text());

        }
    }

    themeReaderProc: Process {
        id: themeReaderProc

        command: ["cat", root.colorsConfigPath]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                if (text && text.trim().length > 0) {
                    root.parseThemeFile(text);
                    if (root.blurEnabled)
                        root.setBlurState(true);

                }
            }
        }

    }

    wallpaperPaletteFile: FileView {
        path: root.wallpaperPaletteStatePath
        watchChanges: true
        printErrors: false
        onLoaded: {
            var raw = String(text() || "").trim();
            if (raw.length > 0) {
                try {
                    var parsed = JSON.parse(raw);
                    if (parsed && parsed.accent)
                        root.applyPalette(parsed);

                } catch (e) {
                }
            }
        }
    }

    wallpaperPaletteProc: Process {
        id: wallpaperPaletteProc

        command: (root._lastWallpaperTarget && root._lastWallpaperTarget.length > 0) ? ["python3", root.wallpaperPaletteScript, root._lastWallpaperTarget] : ["python3", root.wallpaperPaletteScript]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var raw = String(text || "").trim();
                if (raw.length > 0) {
                    try {
                        var parsed = JSON.parse(raw);
                        if (parsed && parsed.accent)
                            root.applyPalette(parsed);

                    } catch (e) {
                    }
                }
            }
        }

    }

    linkCheckProc: Process {
        id: linkCheckProc

        command: ["sh", "-c", "readlink -f \"$HOME/.config/themes/current\" 2>/dev/null; (command -v awww >/dev/null 2>&1 && awww query 2>/dev/null | grep -oP 'currently displaying: image: \\K.*') || readlink -f \"$HOME/.config/themes/current/default.png\" 2>/dev/null"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var lines = String(text || "").trim().split("\n");
                var curTarget = (lines.length > 0) ? lines[0].trim() : "";
                var wpTarget = (lines.length > 1) ? lines[1].trim() : "";
                var changed = false;
                if (curTarget && curTarget !== root._lastCurrentTarget) {
                    root._lastCurrentTarget = curTarget;
                    changed = true;
                }
                if (wpTarget && wpTarget !== root._lastWallpaperTarget) {
                    root._lastWallpaperTarget = wpTarget;
                    changed = true;
                }
                if (changed)
                    root.reloadTheme();

            }
        }

    }

    symlinkWatcherTimer: Timer {
        interval: 1600
        running: true
        repeat: true
        onTriggered: {
            if (!linkCheckProc.running)
                linkCheckProc.running = true;

        }
    }

}
