import "../components"
import "../theme"
import "LauncherModel.js" as LauncherModel
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    readonly property string fontFamily: Fonts.uiFont
    property bool isOpen: false
    property real animProgress: 0
    property var allApps: []
    property string cachedWindows: "[]"
    property var filteredApps: []

    function open(initialQuery) {
        closeAnim.stop();
        root.isOpen = true;
        openAnim.restart();
        root.loadApps();
        if (!windowsProc.running)
            windowsProc.running = true;

        searchInput.text = (typeof initialQuery === "string") ? initialQuery : "";
        root.filterApps();
        listView.currentIndex = 0;
        Qt.callLater(function() {
            searchInput.forceActiveFocus();
        });
    }

    function close() {
        openAnim.stop();
        root.isOpen = false;
        closeAnim.restart();
        searchInput.text = "";
        listView.currentIndex = 0;
    }

    function toggle(initialQuery) {
        if (root.isOpen)
            root.close();
        else
            root.open(initialQuery);
    }

    function loadApps() {
        root.allApps = DesktopEntries.applications.values || [];
    }

    function resolveDelegateIcon(item) {
        if (!item)
            return "";

        if (item.type === "window" && item.winClass) {
            var cls = String(item.winClass).trim();
            var de = DesktopEntries.byId(cls) || DesktopEntries.heuristicLookup(cls);
            if (de && de.icon) {
                var deIcon = Quickshell.iconPath(de.icon, true);
                if (deIcon)
                    return deIcon;

            }
            var bare = cls.toLowerCase().replace(/-browser$/, "");
            return Quickshell.iconPath(cls, true) || Quickshell.iconPath(bare, true) || "";
        }
        var raw = String(item.icon || "");
        if (!raw)
            return "";

        if (raw.indexOf("image://icon/") === 0)
            return Quickshell.iconPath(raw.slice(13), true);

        return raw;
    }

    function filterApps() {
        var q = searchInput.text.trim();
        root.filteredApps = LauncherModel.buildSpotlightResults(root.allApps, root.cachedWindows, q);
        if (listView.currentIndex >= root.filteredApps.length)
            listView.currentIndex = 0;

    }

    function executeCurrentItem() {
        if (!root.filteredApps || root.filteredApps.length === 0)
            return ;

        var item = root.filteredApps[listView.currentIndex];
        if (!item)
            return ;

        if (item.type === "math") {
            Quickshell.execDetached(["wl-copy", "--trim-newline", String(item.value)]);
            Quickshell.execDetached(["qs", "ipc", "call", "osd", "trigger", "󰆏", "Copied " + item.value]);
        } else if (item.type === "window")
            Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "address:" + item.address]);
        else if (item.type === "command")
            Quickshell.execDetached(["sh", "-c", item.cmd]);
        else
            LauncherModel.launchAppEntry(item, Quickshell.execDetached);
        root.close();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Window Setup & Native Hyprland Blur Integration
    // ─────────────────────────────────────────────────────────────────────────
    visible: root.isOpen || root.animProgress > 0.001
    color: "transparent"
    // Dynamic screen binding to Hyprland focused monitor
    screen: {
        if (!Quickshell.screens || Quickshell.screens.length === 0)
            return null;

        var foc = Hyprland.focusedMonitor;
        if (foc && foc.name) {
            for (var i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i].name === foc.name)
                    return Quickshell.screens[i];

            }
        }
        return Quickshell.screens[0];
    }
    // LayerShell configuration
    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.isOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    onIsOpenChanged: {
        if (root.isOpen)
            Qt.callLater(function() {
            searchInput.forceActiveFocus();
        });

    }
    Component.onCompleted: {
        root.loadApps();
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.isOpen
        onActivated: root.close()
    }

    NumberAnimation {
        id: openAnim

        target: root
        property: "animProgress"
        from: root.animProgress
        to: 1
        duration: 210
        easing.type: Easing.OutBack
        easing.overshoot: 1.1
    }

    NumberAnimation {
        id: closeAnim

        target: root
        property: "animProgress"
        from: root.animProgress
        to: 0
        duration: 145
        easing.type: Easing.OutCubic
    }

    Process {
        id: windowsProc

        command: ["hyprctl", "clients", "-j"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.cachedWindows = String(text || "[]");
                if (root.isOpen)
                    root.filterApps();

            }
        }

    }

    // IPC interface for qdeck-launcher CLI compatibility
    IpcHandler {
        function open() : string {
            root.open("");
            return "opened";
        }

        function search(query: string) : string {
            root.open(query);
            return "searching";
        }

        function close() : string {
            root.close();
            return "closed";
        }

        function toggle() : string {
            root.toggle("");
            return "toggled";
        }

        function setMode(mode: string) : string {
            root.open("");
            return "mode-set";
        }

        target: "launcher"
    }

    // Full-screen Backdrop Scrim (Tier 2 alpha <= 0.35 -> will NOT blur)
    Rectangle {
        anchors.fill: parent
        color: Theme.withAlpha(Theme.darker_background, Theme.scrimOpacity)
        opacity: root.animProgress

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

    }

    HyprlandFocusGrab {
        active: false
        windows: [root]
        onCleared: root.close()
    }

    Connections {
        function onApplicationsChanged() {
            root.loadApps();
            root.filterApps();
        }

        target: DesktopEntries
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Main Launcher Surface (Mornye Liquid Glass Material)
    // ─────────────────────────────────────────────────────────────────────────
    GlassPanel {
        id: surface

        width: Appearance.launcherWidth
        height: Appearance.launcherHeight
        anchors.centerIn: parent
        radius: Appearance.launcherRadius
        baseColor: Theme.barBackground
        accentTint: Theme.accent
        clarity: 0.78
        rimIllumination: 0.5
        specularIntensity: 0.75
        opacity: Math.min(1, root.animProgress * 1.6)
        scale: 0.9 + (0.1 * root.animProgress)

        // Consume clicks inside card so backdrop doesn't trigger dismissal
        MouseArea {
            anchors.fill: parent
            onClicked: searchInput.forceActiveFocus()
        }

        // Main Box with padding and spacing
        Item {
            anchors.fill: parent
            anchors.margins: Appearance.launcherPadding

            // ── Inputbar Capsule ─────────────────────────────────────────────
            Rectangle {
                id: inputbar

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 44
                radius: 12
                color: Theme.withAlpha(Theme.darker_background, 0.4)
                border.width: 1
                border.color: searchInput.activeFocus ? Theme.withAlpha(Theme.accent, 0.55) : Theme.withAlpha(Theme.glassBorderColor, 0.22)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 12
                    spacing: 10

                    // Prompt glyph
                    Text {
                        id: promptGlyph

                        text: Icons.search
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: Fonts.sizeMedium
                        color: searchInput.activeFocus ? Theme.accent : Theme.muted
                        Layout.alignment: Qt.AlignVCenter

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }

                        }

                    }

                    // Search Entry
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        // Placeholder text
                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Search apps, @windows, =math, >cmd..."
                            font.family: root.fontFamily
                            font.pixelSize: Fonts.sizeRegular
                            color: Theme.muted
                            visible: searchInput.text.length === 0
                        }

                        TextInput {
                            id: searchInput

                            anchors.fill: parent
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: root.fontFamily
                            font.pixelSize: Fonts.sizeRegular
                            color: Theme.bright_foreground
                            selectionColor: Theme.selection
                            selectedTextColor: Theme.bright_foreground
                            clip: true
                            focus: true
                            onTextChanged: {
                                root.filterApps();
                                listView.currentIndex = 0;
                            }
                            Keys.onDownPressed: {
                                if (listView.count > 0) {
                                    listView.currentIndex = (listView.currentIndex + 1) % listView.count;
                                    listView.positionViewAtIndex(listView.currentIndex, ListView.Contain);
                                }
                            }
                            Keys.onUpPressed: {
                                if (listView.count > 0) {
                                    listView.currentIndex = (listView.currentIndex - 1 + listView.count) % listView.count;
                                    listView.positionViewAtIndex(listView.currentIndex, ListView.Contain);
                                }
                            }
                            Keys.onTabPressed: {
                                if (listView.count > 0) {
                                    listView.currentIndex = (listView.currentIndex + 1) % listView.count;
                                    listView.positionViewAtIndex(listView.currentIndex, ListView.Contain);
                                }
                            }
                            Keys.onBacktabPressed: {
                                if (listView.count > 0) {
                                    listView.currentIndex = (listView.currentIndex - 1 + listView.count) % listView.count;
                                    listView.positionViewAtIndex(listView.currentIndex, ListView.Contain);
                                }
                            }
                            Keys.onReturnPressed: root.executeCurrentItem()
                            Keys.onEnterPressed: root.executeCurrentItem()
                            Keys.onEscapePressed: root.close()
                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_PageDown) {
                                    if (listView.count > 0) {
                                        listView.currentIndex = Math.min(listView.count - 1, listView.currentIndex + 5);
                                        listView.positionViewAtIndex(listView.currentIndex, ListView.Contain);
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_PageUp) {
                                    if (listView.count > 0) {
                                        listView.currentIndex = Math.max(0, listView.currentIndex - 5);
                                        listView.positionViewAtIndex(listView.currentIndex, ListView.Contain);
                                    }
                                    event.accepted = true;
                                }
                            }
                        }

                    }

                    // Clear button
                    Text {
                        visible: searchInput.text.length > 0
                        text: "󰅖"
                        font.family: Icons.effectiveFont("󰅖")
                        font.pixelSize: 14
                        color: clearMouse.containsMouse ? Theme.bright_foreground : Theme.muted
                        Layout.alignment: Qt.AlignVCenter

                        MouseArea {
                            id: clearMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchInput.text = "";
                                searchInput.forceActiveFocus();
                            }
                        }

                    }

                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: 150
                    }

                }

            }

            // ── Listview ─────────────────────────────────────────────────────
            Item {
                anchors.top: inputbar.bottom
                anchors.topMargin: 12
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                ListView {
                    id: listView

                    anchors.fill: parent
                    anchors.rightMargin: scrollbar.visible ? 14 : 0
                    clip: true
                    spacing: 5
                    model: root.filteredApps

                    delegate: Rectangle {
                        id: element

                        required property var modelData
                        required property int index
                        readonly property bool isSelected: listView.currentIndex === index
                        readonly property bool isHovered: itemMouse.containsMouse

                        width: listView.width
                        height: Appearance.launcherItemHeight
                        radius: Appearance.launcherItemRadius
                        // Element normal / selected background: Refined translucent glass pill
                        color: {
                            if (isSelected)
                                return Theme.withAlpha(Theme.accent, 0.16);

                            if (isHovered)
                                return Theme.withAlpha(Theme.bright_foreground, 0.06);

                            return "transparent";
                        }
                        border.width: 1
                        border.color: {
                            if (isSelected)
                                return Theme.withAlpha(Theme.accent, 0.48);

                            if (isHovered)
                                return Theme.withAlpha(Theme.glassBorderColor, 0.14);

                            return "transparent";
                        }

                        // Left active indicator pill
                        Rectangle {
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: 16
                            radius: 1.5
                            color: Theme.accent
                            visible: element.isSelected
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 14
                            spacing: 12

                            // Element Icon container with graceful fallback badge
                            Item {
                                Layout.preferredWidth: Appearance.launcherIconSize
                                Layout.preferredHeight: Appearance.launcherIconSize
                                Layout.alignment: Qt.AlignVCenter

                                Image {
                                    id: appIconImg

                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectFit
                                    source: root.resolveDelegateIcon(modelData)
                                    sourceSize: Qt.size(Appearance.launcherIconSize * 2, Appearance.launcherIconSize * 2)
                                    visible: status === Image.Ready && String(source) !== ""
                                    smooth: true
                                    mipmap: true
                                }

                                Rectangle {
                                    id: fallbackBadge

                                    anchors.fill: parent
                                    radius: Appearance.radiusSmall + 2
                                    visible: !appIconImg.visible
                                    color: element.isSelected ? Theme.withAlpha(Theme.accent, 0.25) : Theme.withAlpha(Theme.darker_background, 0.5)
                                    border.color: element.isSelected ? Theme.accent : Theme.withAlpha(Theme.glassBorderColor, 0.2)
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: {
                                            if (modelData.glyph)
                                                return modelData.glyph;

                                            if (modelData.name && modelData.name.length > 0)
                                                return modelData.name.charAt(0).toUpperCase();

                                            return Icons.apps;
                                        }
                                        font.family: modelData.glyph ? Icons.effectiveFont(modelData.glyph) : root.fontFamily
                                        font.pixelSize: modelData.glyph ? Fonts.sizeMedium : Fonts.sizeSmall
                                        font.weight: Fonts.weightBold
                                        color: element.isSelected ? Theme.accent : Theme.muted
                                    }

                                }

                            }

                            // App Name
                            Text {
                                text: modelData.name || ""
                                font.family: root.fontFamily
                                font.pixelSize: Fonts.sizeRegular
                                font.weight: element.isSelected ? Fonts.weightBold : Fonts.weightMedium
                                color: element.isSelected ? Theme.bright_foreground : Theme.foreground
                                elide: Text.ElideRight
                                Layout.alignment: Qt.AlignVCenter
                            }

                            // Clean description bullet or secondary tag
                            Text {
                                visible: (modelData.generic || "") !== ""
                                text: "·  " + (modelData.generic || "")
                                font.family: root.fontFamily
                                font.pixelSize: Fonts.sizeSmall
                                font.weight: Fonts.weightNormal
                                color: element.isSelected ? Theme.withAlpha(Theme.bright_foreground, 0.7) : Theme.muted
                                elide: Text.ElideRight
                                Layout.alignment: Qt.AlignVCenter
                            }

                            // Spacer to ensure left alignment
                            Item {
                                Layout.fillWidth: true
                            }

                            // Subtle Type Tag (CALC / WINDOW / RUN)
                            Rectangle {
                                visible: Boolean(modelData.badge)
                                Layout.preferredHeight: 18
                                Layout.preferredWidth: badgeLbl.implicitWidth + 10
                                Layout.alignment: Qt.AlignVCenter
                                radius: 5
                                color: Theme.withAlpha(Theme.accent, 0.16)
                                border.width: 1
                                border.color: Theme.withAlpha(Theme.accent, 0.35)

                                Text {
                                    id: badgeLbl

                                    anchors.centerIn: parent
                                    text: modelData.badge || ""
                                    font.family: Fonts.monoFont
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                    color: Theme.accent
                                }

                            }

                        }

                        MouseArea {
                            id: itemMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPositionChanged: {
                                if (listView.currentIndex !== index)
                                    listView.currentIndex = index;

                            }
                            onClicked: {
                                listView.currentIndex = index;
                                root.executeCurrentItem();
                            }
                        }

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

                }

                // ── Scrollbar ────────────────────────────────────────────────
                Rectangle {
                    id: scrollbar

                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 4
                    radius: 2
                    color: Theme.withAlpha(Theme.darker_background, 0.3)
                    visible: listView.count > 8

                    Rectangle {
                        id: scrollbarHandle

                        width: parent.width
                        radius: 2
                        color: Theme.withAlpha(Theme.bright_foreground, 0.32)
                        height: Math.max(24, listView.visibleArea.heightRatio * scrollbar.height)
                        y: listView.visibleArea.yPosition * scrollbar.height
                    }

                }

            }

        }

        transform: Translate {
            y: Math.round(-12 * (1 - root.animProgress))
        }

    }

}
