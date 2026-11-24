import "../components"
import "../services"
import "../theme"
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: root

    required property Item anchorItem
    property var anchorWindow: null
    property MediaController controller: null
    property AudioService audioService: null
    property bool open: false
    property int contentWidth: Appearance.mediaIslandWidth
    property int contentHeight: Appearance.mediaIslandHeight
    property double lastClearedTime: 0
    // High-resolution App icon mapping for whichever app is currently playing audio
    readonly property string appIconSource: {
        if (!root.controller || !root.controller.activePlayer)
            return "";

        var p = root.controller.activePlayer;
        var entry = (p.desktopEntry || "").toLowerCase();
        var ident = (p.identity || "").toLowerCase();
        var dbus = (p.dbusName || "").toLowerCase();
        var all = entry + " " + ident + " " + dbus;
        // 1. Try direct DesktopEntries lookup
        if (p.desktopEntry) {
            var de = DesktopEntries.byId(p.desktopEntry);
            if (de && de.icon) {
                var p1 = Quickshell.iconPath(de.icon, true);
                if (p1 && p1 !== "")
                    return p1;

            }
        }
        var deGuess = DesktopEntries.heuristicLookup(p.desktopEntry || p.identity || "");
        if (deGuess && deGuess.icon) {
            var p2 = Quickshell.iconPath(deGuess.icon, true);
            if (p2 && p2 !== "")
                return p2;

        }
        // 2. Comprehensive player-specific high-res icon search
        var candidates = [];
        if (all.indexOf("spotify") !== -1)
            candidates = ["spotify-launcher", "spotify", "spotify-client"];
        else if (all.indexOf("brave") !== -1)
            candidates = ["brave-origin", "brave-browser", "brave", "brave-bin"];
        else if (all.indexOf("zen") !== -1)
            candidates = ["zen-browser", "zen"];
        else if (all.indexOf("firefox") !== -1)
            candidates = ["firefox", "firefox-developer-edition", "firefox-nightly"];
        else if (all.indexOf("chromium") !== -1)
            candidates = ["chromium", "chromium-browser"];
        else if (all.indexOf("chrome") !== -1)
            candidates = ["google-chrome", "google-chrome-stable", "chrome"];
        else if (all.indexOf("vlc") !== -1)
            candidates = ["vlc"];
        else if (all.indexOf("mpv") !== -1)
            candidates = ["mpv"];
        else if (all.indexOf("cider") !== -1)
            candidates = ["cider"];
        else if (all.indexOf("amberol") !== -1)
            candidates = ["io.bassi.Amberol", "amberol"];
        else if (all.indexOf("youtube") !== -1)
            candidates = ["com.github.th_ch.youtube_music", "youtube-music", "youtubemusic"];
        else if (all.indexOf("discord") !== -1)
            candidates = ["discord"];
        else if (all.indexOf("audacious") !== -1)
            candidates = ["audacious"];
        else if (all.indexOf("rhythmbox") !== -1)
            candidates = ["rhythmbox"];
        else if (all.indexOf("elisa") !== -1)
            candidates = ["elisa"];
        else if (p.desktopEntry)
            candidates = [p.desktopEntry];
        for (var i = 0; i < candidates.length; i++) {
            var path = Quickshell.iconPath(candidates[i], true);
            if (path && path !== "")
                return path;

        }
        return "";
    }
    readonly property string appGlyph: {
        if (!root.controller || !root.controller.activePlayer)
            return "󰝚";

        var p = root.controller.activePlayer;
        var s = ((p.identity || "") + " " + (p.desktopEntry || "") + " " + (p.dbusName || "")).toLowerCase();
        if (s.indexOf("spotify") !== -1)
            return "󰓋";

        if (s.indexOf("brave") !== -1)
            return "󰖠";

        if (s.indexOf("firefox") !== -1)
            return "󰈹";

        if (s.indexOf("chrome") !== -1 || s.indexOf("chromium") !== -1)
            return "󰊹";

        if (s.indexOf("youtube") !== -1)
            return "󰗃";

        if (s.indexOf("vlc") !== -1)
            return "󰖀";

        if (s.indexOf("mpv") !== -1)
            return "󰕼";

        return "󰝚";
    }
    readonly property color appGlyphColor: {
        if (!root.controller || !root.controller.activePlayer)
            return Theme.foreground;

        var p = root.controller.activePlayer;
        var s = ((p.identity || "") + " " + (p.desktopEntry || "") + " " + (p.dbusName || "")).toLowerCase();
        if (s.indexOf("spotify") !== -1)
            return Theme.green;

        if (s.indexOf("brave") !== -1)
            return Theme.orange;

        if (s.indexOf("firefox") !== -1)
            return Theme.bright_yellow;

        if (s.indexOf("chrome") !== -1 || s.indexOf("chromium") !== -1)
            return Theme.blue;

        if (s.indexOf("youtube") !== -1)
            return Theme.red;

        if (s.indexOf("vlc") !== -1)
            return Theme.orange;

        return Theme.foreground;
    }
    readonly property color appBadgeBg: Theme.dark_background
    // Interactive scrubbing state
    property bool isDraggingSeek: false
    property real dragProgress: 0
    // Bouncy morph transition (State A -> State B)
    property real animProgress: 0
    readonly property point popupPos: {
        var _ = root.open;
        var _e = Appearance.barEdge;
        return Appearance.computeBarPopupPos(root.anchorItem, root.contentWidth, root.contentHeight, 10, root.width, root.height);
    }
    readonly property real cardX: popupPos.x
    readonly property real cardY: popupPos.y

    function toggle() {
        if (Date.now() - root.lastClearedTime < 250) {
            root.open = false;
            return ;
        }
        root.open = !root.open;
    }

    function getAnchorWindow() {
        if (root.anchorWindow)
            return root.anchorWindow;

        if (root.anchorItem && root.anchorItem.window)
            return root.anchorItem.window;

        if (root.anchorItem && root.anchorItem.QsWindow && root.anchorItem.QsWindow.window)
            return root.anchorItem.QsWindow.window;

        return null;
    }

    onOpenChanged: {
        if (root.open) {
            closeAnim.stop();
            openAnim.restart();
            grabDelayTimer.restart();
        } else {
            grabDelayTimer.stop();
            focusGrab.active = false;
            openAnim.stop();
            closeAnim.restart();
        }
    }
    visible: open || animProgress > 0.001
    color: "transparent"
    screen: (root.anchorItem && root.anchorItem.QsWindow && root.anchorItem.QsWindow.window) ? root.anchorItem.QsWindow.window.screen : null
    WlrLayershell.namespace: "quickshell-surface"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    NumberAnimation {
        id: openAnim

        target: root
        property: "animProgress"
        from: root.animProgress
        to: 1
        duration: 340
        easing.type: Easing.OutBack
        easing.overshoot: 1.22
    }

    NumberAnimation {
        id: closeAnim

        target: root
        property: "animProgress"
        from: root.animProgress
        to: 0
        duration: 180
        easing.type: Easing.OutCubic
    }

    Connections {
        function onCloseBarPopups() {
            root.open = false;
        }

        target: Appearance
    }

    Timer {
        id: grabDelayTimer

        interval: 150
        onTriggered: {
            if (root.open)
                focusGrab.active = true;

        }
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    HyprlandFocusGrab {
        id: focusGrab

        active: false
        windows: [root]
        onCleared: {
            root.lastClearedTime = Date.now();
            root.open = false;
        }
    }

    // Dismiss when clicking outside the card
    MouseArea {
        anchors.fill: parent
        onClicked: {
            root.lastClearedTime = Date.now();
            root.open = false;
        }
    }

    // Outer Frosted Container (Pixel-perfect ColorOS / Dynamic Island Live Alert card)
    GlassPanel {
        id: cardRect

        x: Math.round(root.cardX)
        y: Math.round(root.cardY)
        width: root.contentWidth
        height: root.contentHeight
        radius: Appearance.mediaIslandRadius
        baseColor: Theme.barBackground
        transformOrigin: Appearance.barIsBottom ? Item.Bottom : (Appearance.barIsRight ? Item.Right : (Appearance.barIsLeft ? Item.Left : Item.Top))
        scale: 0.82 + (0.18 * root.animProgress)
        opacity: Math.min(1, root.animProgress * 1.5)

        // Deep obsidian optical backing prevents translucent window bleed-through
        Rectangle {
            anchors.fill: parent
            radius: cardRect.radius
            color: Qt.rgba(0.04, 0.06, 0.09, 0.9)
            z: -1
        }

        MouseArea {
            anchors.fill: parent
            propagateComposedEvents: true
            onClicked: function(mouse) {
                mouse.accepted = false;
            }
        }

        // Main Horizontal Layout: Left = Album Art Thumbnail, Right = Media Column
        Row {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14
            opacity: Math.min(1, Math.max(0, (root.animProgress - 0.08) * 1.25))

            // 1. Album Artwork Thumbnail (Strictly Rounded Corners using MultiEffect Mask)
            Item {
                id: albumCoverBox

                width: 104
                height: 104
                anchors.verticalCenter: parent.verticalCenter
                scale: coverMouse.pressed ? 0.96 : (coverMouse.containsMouse ? 1.02 : 1)

                // Mask defining sharp rounded corners (Squircle 14px)
                Rectangle {
                    id: albumCoverMask

                    anchors.fill: parent
                    radius: 14
                    color: "black"
                    layer.enabled: true
                    visible: false
                }

                // Underlying fallback when no artwork is available
                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: Qt.rgba(0.08, 0.11, 0.16, 0.9)
                    border.color: Theme.withAlpha(Theme.glassBorderColor, 0.25)
                    border.width: 1
                    visible: !coverImg.visible

                    Text {
                        anchors.centerIn: parent
                        text: "󰝚"
                        font.family: Icons.effectiveFont("󰝚")
                        font.pixelSize: Fonts.scale(36)
                        color: Theme.muted
                    }

                }

                // Album Artwork with anti-aliased rounded corner mask
                Image {
                    id: coverImg

                    anchors.fill: parent
                    source: root.controller ? root.controller.artUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                    layer.enabled: true

                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: albumCoverMask
                    }

                }

                // Razor-crisp outline over rounded album art
                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: "transparent"
                    border.color: coverMouse.containsMouse ? Theme.withAlpha(Theme.accent, 0.5) : Theme.withAlpha(Theme.glassBorderColor, 0.3)
                    border.width: 1
                    z: 10
                }

                // Play / Pause overlay glyph on hover
                Rectangle {
                    anchors.centerIn: parent
                    width: 38
                    height: 38
                    radius: 19
                    color: Qt.rgba(0, 0, 0, 0.55)
                    visible: coverMouse.containsMouse
                    opacity: coverMouse.containsMouse ? 1 : 0
                    z: 12

                    Text {
                        anchors.centerIn: parent
                        text: root.controller && root.controller.isPlaying ? "󰏤" : "󰐊"
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: Fonts.scale(18)
                        color: Theme.bright_foreground
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 120
                        }

                    }

                }

                MouseArea {
                    id: coverMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    z: 15
                    onClicked: {
                        if (root.controller)
                            root.controller.togglePlay();

                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }

                }

            }

            // 2. Right Side Column: Title/Artist + App Icon, Progress groove, Playback Controls
            Column {
                id: rightMediaCol

                width: parent.width - albumCoverBox.width - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // --- TOP ROW: Track Info + App Icon (in which audio is playing) ---
                Row {
                    width: parent.width
                    spacing: 8

                    Column {
                        width: parent.width - appIconBox.width - parent.spacing
                        spacing: 2
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            width: parent.width
                            text: root.controller && root.controller.title ? root.controller.title : "No Media"
                            font.family: Fonts.uiFont
                            font.pixelSize: Fonts.sizeMedium
                            font.weight: Fonts.weightBold
                            color: Theme.bright_foreground
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Text {
                            width: parent.width
                            text: root.controller && root.controller.artist ? root.controller.artist : "Unknown Artist"
                            font.family: Fonts.uiFont
                            font.pixelSize: Fonts.sizeSmall
                            color: Theme.muted
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                    }

                    // App Icon in which audio is playing (Top Right)
                    Item {
                        id: appIconBox

                        width: 28
                        height: 28
                        anchors.verticalCenter: parent.verticalCenter

                        // Squircle container with native clipping
                        Rectangle {
                            id: appIconBg

                            anchors.fill: parent
                            radius: 8
                            clip: true
                            color: root.appBadgeBg
                            border.color: Theme.withAlpha(Theme.glassBorderColor, 0.25)
                            border.width: 1

                            // High-res desktop app icon (anti-aliased, mipmapped)
                            Image {
                                id: appIconImg

                                anchors.fill: parent
                                anchors.margins: 4
                                source: root.appIconSource
                                fillMode: Image.PreserveAspectFit
                                sourceSize.width: 64
                                sourceSize.height: 64
                                mipmap: true
                                smooth: true
                                asynchronous: true
                                visible: root.appIconSource !== "" && status === Image.Ready
                            }

                            // Fallback branded glyph if icon image is not found
                            Text {
                                anchors.centerIn: parent
                                text: root.appGlyph
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: Fonts.scale(16)
                                color: root.appGlyphColor
                                visible: !appIconImg.visible
                            }

                        }

                    }

                }

                // --- MIDDLE ROW: Progress Groove Line & Timestamps ---
                Column {
                    width: parent.width
                    spacing: 3

                    Item {
                        id: progressGrooveArea

                        readonly property real curProgress: root.isDraggingSeek ? root.dragProgress : (root.controller ? root.controller.progress : 0)

                        width: parent.width
                        height: 12

                        // Groove line background
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 3.5
                            radius: 1.75
                            color: Theme.withAlpha(Theme.foreground, 0.15)
                        }

                        // Played active progress
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            width: Math.max(0, Math.min(parent.width, parent.width * progressGrooveArea.curProgress))
                            height: 3.5
                            radius: 1.75
                            color: Theme.accent
                        }

                        // Playback Knob / Scrubber Head
                        Rectangle {
                            id: scrubHead

                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(parent.width - width, parent.width * progressGrooveArea.curProgress - width / 2))
                            width: (seekMouse.containsMouse || root.isDraggingSeek) ? 12 : 9
                            height: width
                            radius: width / 2
                            color: Theme.bright_foreground
                            border.color: Theme.accent
                            border.width: 1.5

                            Behavior on width {
                                NumberAnimation {
                                    duration: 120
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                        MouseArea {
                            id: seekMouse

                            function updateFromMouse(mouseX) {
                                var pct = Math.max(0, Math.min(1, mouseX / width));
                                root.dragProgress = pct;
                            }

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: function(mouse) {
                                root.isDraggingSeek = true;
                                updateFromMouse(mouse.x);
                            }
                            onPositionChanged: function(mouse) {
                                if (root.isDraggingSeek)
                                    updateFromMouse(mouse.x);

                            }
                            onReleased: function(mouse) {
                                if (root.isDraggingSeek) {
                                    updateFromMouse(mouse.x);
                                    if (root.controller && root.controller.length > 0)
                                        root.controller.seekTo(root.dragProgress * root.controller.length);

                                    root.isDraggingSeek = false;
                                }
                            }
                        }

                    }

                    // Elapsed & Total Timestamps
                    Item {
                        width: parent.width
                        height: 12

                        Text {
                            anchors.left: parent.left
                            text: root.controller ? root.controller.formatTime(root.isDraggingSeek ? (root.dragProgress * root.controller.length) : root.controller.position) : "00:00"
                            font.family: Fonts.monoFont
                            font.pixelSize: Fonts.scale(9.5)
                            color: Theme.muted
                        }

                        Text {
                            anchors.right: parent.right
                            text: root.controller ? root.controller.formatTime(root.controller.length) : "00:00"
                            font.family: Fonts.monoFont
                            font.pixelSize: Fonts.scale(9.5)
                            color: Theme.muted
                        }

                    }

                }

                // --- BOTTOM ROW: Tactile Glass Controls (Previous | Play/Pause | Next) ---
                Item {
                    width: parent.width
                    height: 38

                    Row {
                        anchors.centerIn: parent
                        spacing: 24

                        // 1. Previous Button (Circular Glass Pill)
                        Item {
                            width: 32
                            height: 32
                            anchors.verticalCenter: parent.verticalCenter
                            scale: prevMouse.pressed ? 0.92 : (prevMouse.containsMouse ? 1.06 : 1)

                            Rectangle {
                                anchors.fill: parent
                                radius: 16
                                color: prevMouse.pressed ? Theme.withAlpha(Theme.foreground, 0.16) : (prevMouse.containsMouse ? Theme.withAlpha(Theme.foreground, 0.08) : "transparent")
                                border.color: prevMouse.containsMouse ? Theme.withAlpha(Theme.glassBorderColor, 0.35) : "transparent"
                                border.width: 1

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }

                                }

                            }

                            Text {
                                anchors.centerIn: parent
                                text: "󰒮"
                                font.family: Icons.effectiveFont("󰒮")
                                font.pixelSize: Fonts.scale(16)
                                color: root.controller && root.controller.canGoPrevious ? (prevMouse.containsMouse ? Theme.bright_foreground : Theme.foreground) : Theme.muted

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }

                                }

                            }

                            MouseArea {
                                id: prevMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.controller)
                                        root.controller.previous();

                                }
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: prevMouse.pressed ? 70 : 180
                                    easing.type: prevMouse.pressed ? Easing.OutQuad : Easing.OutBack
                                    easing.overshoot: 1.25
                                }

                            }

                        }

                        // 2. Central Play / Pause Hero Button
                        Item {
                            width: 38
                            height: 38
                            anchors.verticalCenter: parent.verticalCenter
                            scale: playMouse.pressed ? 0.92 : (playMouse.containsMouse ? 1.08 : 1)

                            Rectangle {
                                anchors.fill: parent
                                radius: 19
                                color: playMouse.pressed ? Theme.withAlpha(Theme.accent, 0.38) : (playMouse.containsMouse ? Theme.withAlpha(Theme.accent, 0.26) : Theme.withAlpha(Theme.accent, 0.16))
                                border.color: playMouse.containsMouse ? Theme.accent : Theme.withAlpha(Theme.accent, 0.6)
                                border.width: 1.5

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }

                                }

                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: 120
                                    }

                                }

                            }

                            Text {
                                anchors.centerIn: parent
                                text: root.controller && root.controller.isPlaying ? "󰏤" : "󰐊"
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: Fonts.scale(18)
                                color: Theme.bright_foreground
                            }

                            MouseArea {
                                id: playMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.controller)
                                        root.controller.togglePlay();

                                }
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: playMouse.pressed ? 70 : 200
                                    easing.type: playMouse.pressed ? Easing.OutQuad : Easing.OutBack
                                    easing.overshoot: 1.3
                                }

                            }

                        }

                        // 3. Next Button (Circular Glass Pill)
                        Item {
                            width: 32
                            height: 32
                            anchors.verticalCenter: parent.verticalCenter
                            scale: nextMouse.pressed ? 0.92 : (nextMouse.containsMouse ? 1.06 : 1)

                            Rectangle {
                                anchors.fill: parent
                                radius: 16
                                color: nextMouse.pressed ? Theme.withAlpha(Theme.foreground, 0.16) : (nextMouse.containsMouse ? Theme.withAlpha(Theme.foreground, 0.08) : "transparent")
                                border.color: nextMouse.containsMouse ? Theme.withAlpha(Theme.glassBorderColor, 0.35) : "transparent"
                                border.width: 1

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }

                                }

                            }

                            Text {
                                anchors.centerIn: parent
                                text: "󰒭"
                                font.family: Icons.effectiveFont("󰒭")
                                font.pixelSize: Fonts.scale(16)
                                color: root.controller && root.controller.canGoNext ? (nextMouse.containsMouse ? Theme.bright_foreground : Theme.foreground) : Theme.muted

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }

                                }

                            }

                            MouseArea {
                                id: nextMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.controller)
                                        root.controller.next();

                                }
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: nextMouse.pressed ? 70 : 180
                                    easing.type: nextMouse.pressed ? Easing.OutQuad : Easing.OutBack
                                    easing.overshoot: 1.25
                                }

                            }

                        }

                    }

                }

            }

        }

        transform: Translate {
            y: Appearance.barIsTop ? Math.round(-18 * (1 - root.animProgress)) : (Appearance.barIsBottom ? Math.round(18 * (1 - root.animProgress)) : 0)
            x: Appearance.barIsLeft ? Math.round(-18 * (1 - root.animProgress)) : (Appearance.barIsRight ? Math.round(18 * (1 - root.animProgress)) : 0)
        }

    }

}
