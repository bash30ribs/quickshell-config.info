import "../components"
import "../services"
import "../theme"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property ClipboardService clipboardService: null
    property bool isOpen: false
    property bool isVisibleSurface: false
    property bool isDragging: false
    property bool stayPinnedOpen: false
    property string filterMode: "all" // "all" | "image" | "text" | "pinned"
    property string searchQuery: ""
    property real animProgress: 0
    property real openedAtMs: 0
    property real gestureUpAccum: 0
    readonly property bool searchFocused: searchInput.activeFocus
    readonly property var filteredAll: root.clipboardService ? root.clipboardService.filteredItems(root.filterMode, root.searchQuery) : []
    readonly property var imageItems: {
        var list = root.filteredAll || [];
        var out = [];
        for (var i = 0; i < list.length; i++) {
            if (list[i].type === "image")
                out.push(list[i]);

        }
        return out;
    }
    readonly property var textItems: {
        var list = root.filteredAll || [];
        var out = [];
        for (var i = 0; i < list.length; i++) {
            if (list[i].type === "text")
                out.push(list[i]);

        }
        return out;
    }
    readonly property int totalCount: root.filteredAll ? root.filteredAll.length : 0

    function open() {
        if (root.clipboardService)
            root.clipboardService.syncNow();

        root.gestureUpAccum = 0;
        root.openedAtMs = Date.now();
        root.isVisibleSurface = true;
        root.isOpen = true;
        closeAnim.stop();
        openSpring.restart();
    }

    function close() {
        if (!root.isOpen && !root.isVisibleSurface)
            return ;

        root.gestureUpAccum = 0;
        searchInput.focus = false;
        root.isOpen = false;
        openSpring.stop();
        closeAnim.restart();
    }

    function toggle() {
        if (root.isOpen)
            root.close();
        else
            root.open();
    }

    function handleSwipeUpDelta(dy) {
        if (!root.isOpen)
            return ;

        // Prevent accidental reverse bounce right after pull-down opens
        if (Date.now() - root.openedAtMs < 280)
            return ;

        if (dy < 0) {
            root.gestureUpAccum += dy;
            gestureDecayTimer.restart();
            if (root.gestureUpAccum <= -24) {
                root.gestureUpAccum = 0;
                root.close();
            }
        } else if (dy > 6) {
            root.gestureUpAccum = 0;
        }
    }

    function pasteCard(itemId) {
        if (!itemId || !root.clipboardService)
            return ;

        searchInput.focus = false;
        if (!root.stayPinnedOpen)
            root.close();

        root.clipboardService.pasteItem(itemId);
    }

    function copyCard(itemId) {
        if (!itemId || !root.clipboardService)
            return ;

        root.clipboardService.copyItem(itemId);
    }

    visible: root.isVisibleSurface
    color: "transparent"
    implicitWidth: Appearance.clipboardWidth
    implicitHeight: Appearance.clipboardHeight + 36
    WlrLayershell.namespace: "quickshell-clipboard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: (root.isOpen && root.searchFocused) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
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

    anchors {
        top: true
    }

    margins {
        top: Appearance.barHeight + 4
    }

    // Flexy Spring Pull-Down Animation (AGENTS.md spring spec + elastic reveal)
    SpringAnimation {
        id: openSpring

        target: root
        property: "animProgress"
        to: 1
        spring: 4.8
        damping: 0.42
        epsilon: 0.002
    }

    NumberAnimation {
        id: closeAnim

        target: root
        property: "animProgress"
        to: 0
        duration: 210
        easing.type: Easing.InCubic
        onFinished: {
            if (!root.isOpen) {
                root.isVisibleSurface = false;
                root.searchQuery = "";
                searchInput.text = "";
            }
        }
    }

    Timer {
        id: gestureDecayTimer

        interval: 180
        repeat: false
        onTriggered: {
            root.gestureUpAccum = 0;
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.isOpen && root.searchFocused
        onActivated: root.close()
    }

    Connections {
        function onFocusedWorkspaceChanged() {
            if (root.isOpen && !root.stayPinnedOpen)
                root.close();

        }

        function onRawEvent(event) {
            if (event && event.name === "activewindowv2" && root.isOpen && !root.stayPinnedOpen && !root.isDragging && (Date.now() - root.openedAtMs > 280))
                root.close();

        }

        target: Hyprland
    }

    IpcHandler {
        function open() : string {
            root.open();
            return "opened";
        }

        function close() : string {
            root.close();
            return "closed";
        }

        function toggle() : string {
            root.toggle();
            return root.isOpen ? "opened" : "closed";
        }

        function refresh() : string {
            if (root.clipboardService)
                root.clipboardService.syncNow();

            return "ok";
        }

        target: "clipboard"
    }

    // Clipped slide-down viewport so drawer glides smoothly out from under the bar
    Item {
        id: clipViewport

        anchors.fill: parent
        clip: true

        GlassPanel {
            id: drawerSurface

            width: Appearance.clipboardWidth
            height: Appearance.clipboardHeight
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round((root.animProgress - 1) * (height + 20))
            radius: Appearance.clipboardRadius
            baseColor: Theme.barBackground
            accentTint: Theme.accent
            clarity: 0.78
            rimIllumination: 0.52
            specularIntensity: 0.76
            transformOrigin: Item.Top
            opacity: Math.max(0, Math.min(1, root.animProgress * 1.4))
            scale: 0.94 + 0.06 * Math.min(1.05, root.animProgress)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Appearance.clipboardPadding
                spacing: 10

                // ─────────────────────────────────────────────────────────────
                // Top Header Bar (Filter Pills, Search Capsule, Snap & Actions)
                // Also responds directly to 2-finger glide up to dismiss
                // ─────────────────────────────────────────────────────────────
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34

                    WheelHandler {
                        target: null
                        onWheel: function(event) {
                            if (event.angleDelta.y < 0)
                                root.handleSwipeUpDelta(event.angleDelta.y);

                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: 10

                        // Segmented Filter Pill Track (All | SS | Text | Pinned)
                        Rectangle {
                            id: filterTrack

                            Layout.preferredHeight: 30
                            Layout.preferredWidth: filterRow.implicitWidth + 8
                            radius: 15
                            color: Theme.withAlpha(Theme.darker_background, 0.55)
                            border.width: 1
                            border.color: Theme.withAlpha(Theme.glassBorderColor, 0.22)

                            Rectangle {
                                id: activeFilterPill

                                y: 3
                                height: 24
                                radius: 12
                                color: Theme.accent
                                x: {
                                    if (root.filterMode === "all")
                                        return 4;

                                    if (root.filterMode === "image")
                                        return tabAll.width + 4;

                                    if (root.filterMode === "text")
                                        return tabAll.width + tabImg.width + 4;

                                    return tabAll.width + tabImg.width + tabTxt.width + 4;
                                }
                                width: {
                                    if (root.filterMode === "all")
                                        return tabAll.width;

                                    if (root.filterMode === "image")
                                        return tabImg.width;

                                    if (root.filterMode === "text")
                                        return tabTxt.width;

                                    return tabPin.width;
                                }

                                Behavior on x {
                                    NumberAnimation {
                                        duration: 210
                                        easing.type: Easing.OutBack
                                        easing.overshoot: 1.15
                                    }

                                }

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 160
                                        easing.type: Easing.OutCubic
                                    }

                                }

                            }

                            Row {
                                id: filterRow

                                anchors.left: parent.left
                                anchors.leftMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 0

                                // Tab 1: All
                                Item {
                                    id: tabAll

                                    width: rowAll.implicitWidth + 16
                                    height: 24

                                    Row {
                                        id: rowAll

                                        anchors.centerIn: parent
                                        spacing: 4

                                        Text {
                                            text: Icons.clipboard
                                            font.family: Icons.effectiveFont(text)
                                            font.pixelSize: 12
                                            color: (root.filterMode === "all") ? Theme.darker_background : (mAll.containsMouse ? Theme.bright_foreground : Theme.foreground)
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: "All"
                                            font.family: Fonts.uiFont
                                            font.pixelSize: 11
                                            font.bold: root.filterMode === "all"
                                            color: (root.filterMode === "all") ? Theme.darker_background : (mAll.containsMouse ? Theme.bright_foreground : Theme.foreground)
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                    }

                                    MouseArea {
                                        id: mAll

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.filterMode = "all"
                                    }

                                }

                                // Tab 2: Images / Screenshots
                                Item {
                                    id: tabImg

                                    width: rowImg.implicitWidth + 16
                                    height: 24

                                    Row {
                                        id: rowImg

                                        anchors.centerIn: parent
                                        spacing: 4

                                        Text {
                                            text: Icons.photo
                                            font.family: Icons.effectiveFont(text)
                                            font.pixelSize: 12
                                            color: (root.filterMode === "image") ? Theme.darker_background : (mImg.containsMouse ? Theme.bright_foreground : Theme.foreground)
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: "SS (" + (root.clipboardService ? root.clipboardService.imageCount : 0) + ")"
                                            font.family: Fonts.uiFont
                                            font.pixelSize: 11
                                            font.bold: root.filterMode === "image"
                                            color: (root.filterMode === "image") ? Theme.darker_background : (mImg.containsMouse ? Theme.bright_foreground : Theme.foreground)
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                    }

                                    MouseArea {
                                        id: mImg

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.filterMode = "image"
                                    }

                                }

                                // Tab 3: Text
                                Item {
                                    id: tabTxt

                                    width: rowTxt.implicitWidth + 16
                                    height: 24

                                    Row {
                                        id: rowTxt

                                        anchors.centerIn: parent
                                        spacing: 4

                                        Text {
                                            text: Icons.textDoc
                                            font.family: Icons.effectiveFont(text)
                                            font.pixelSize: 12
                                            color: (root.filterMode === "text") ? Theme.darker_background : (mTxt.containsMouse ? Theme.bright_foreground : Theme.foreground)
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: "Text (" + (root.clipboardService ? root.clipboardService.textCount : 0) + ")"
                                            font.family: Fonts.uiFont
                                            font.pixelSize: 11
                                            font.bold: root.filterMode === "text"
                                            color: (root.filterMode === "text") ? Theme.darker_background : (mTxt.containsMouse ? Theme.bright_foreground : Theme.foreground)
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                    }

                                    MouseArea {
                                        id: mTxt

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.filterMode = "text"
                                    }

                                }

                                // Tab 4: Pinned
                                Item {
                                    id: tabPin

                                    width: rowPin.implicitWidth + 16
                                    height: 24

                                    Row {
                                        id: rowPin

                                        anchors.centerIn: parent
                                        spacing: 4

                                        Text {
                                            text: Icons.pin
                                            font.family: Icons.effectiveFont(text)
                                            font.pixelSize: 12
                                            color: (root.filterMode === "pinned") ? Theme.darker_background : (mPin.containsMouse ? Theme.bright_foreground : Theme.foreground)
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: "Pinned"
                                            font.family: Fonts.uiFont
                                            font.pixelSize: 11
                                            font.bold: root.filterMode === "pinned"
                                            color: (root.filterMode === "pinned") ? Theme.darker_background : (mPin.containsMouse ? Theme.bright_foreground : Theme.foreground)
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                    }

                                    MouseArea {
                                        id: mPin

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.filterMode = "pinned"
                                    }

                                }

                            }

                        }

                        // Compact Search Capsule
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            radius: 15
                            color: Theme.withAlpha(Theme.darker_background, 0.45)
                            border.width: 1
                            border.color: searchInput.activeFocus ? Theme.withAlpha(Theme.accent, 0.55) : Theme.withAlpha(Theme.glassBorderColor, 0.2)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 8
                                spacing: 6

                                Text {
                                    text: Icons.search
                                    font.family: Icons.effectiveFont(text)
                                    font.pixelSize: 13
                                    color: searchInput.activeFocus ? Theme.accent : Theme.muted
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    Text {
                                        anchors.fill: parent
                                        verticalAlignment: Text.AlignVCenter
                                        text: "Search clips or screenshots..."
                                        font.family: Fonts.uiFont
                                        font.pixelSize: 11
                                        color: Theme.muted
                                        visible: searchInput.text.length === 0
                                    }

                                    TextInput {
                                        id: searchInput

                                        anchors.fill: parent
                                        verticalAlignment: TextInput.AlignVCenter
                                        font.family: Fonts.uiFont
                                        font.pixelSize: 11
                                        color: Theme.bright_foreground
                                        selectionColor: Theme.selection
                                        selectedTextColor: Theme.bright_foreground
                                        clip: true
                                        onTextChanged: root.searchQuery = text
                                    }

                                }

                                Text {
                                    text: Icons.close
                                    font.family: Icons.effectiveFont(text)
                                    font.pixelSize: 12
                                    color: clearQueryMouse.containsMouse ? Theme.foreground : Theme.muted
                                    visible: searchInput.text.length > 0

                                    MouseArea {
                                        id: clearQueryMouse

                                        anchors.fill: parent
                                        anchors.margins: -4
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            searchInput.text = "";
                                            searchInput.focus = false;
                                        }
                                    }

                                }

                            }

                        }

                        // Quick Snap Button (Region Screenshot directly into Clipboard)
                        Rectangle {
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: snapRow.implicitWidth + 16
                            radius: 15
                            color: snapMouse.containsMouse ? Theme.withAlpha(Theme.accent, 0.22) : Theme.withAlpha(Theme.darker_background, 0.45)
                            border.width: 1
                            border.color: snapMouse.containsMouse ? Theme.withAlpha(Theme.accent, 0.55) : Theme.withAlpha(Theme.glassBorderColor, 0.22)

                            Row {
                                id: snapRow

                                anchors.centerIn: parent
                                spacing: 5

                                Text {
                                    text: Icons.camera
                                    font.family: Icons.effectiveFont(text)
                                    font.pixelSize: 13
                                    color: Theme.accent
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "Snap"
                                    font.family: Fonts.uiFont
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: Theme.bright_foreground
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                            }

                            MouseArea {
                                id: snapMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.close();
                                    if (root.clipboardService)
                                        root.clipboardService.captureSnap("region");

                                }
                            }

                        }

                        // Lock / Pin Drawer Open Toggle (handy for multi-drag workflow)
                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            radius: 15
                            color: root.stayPinnedOpen ? Theme.withAlpha(Theme.accent, 0.25) : (stayMouse.containsMouse ? Theme.withAlpha(Theme.lighter_background, 0.45) : Theme.withAlpha(Theme.darker_background, 0.45))
                            border.width: 1
                            border.color: root.stayPinnedOpen ? Theme.withAlpha(Theme.accent, 0.6) : Theme.withAlpha(Theme.glassBorderColor, 0.22)

                            Text {
                                anchors.centerIn: parent
                                text: Icons.pin
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: 13
                                color: root.stayPinnedOpen ? Theme.accent : Theme.foreground
                            }

                            MouseArea {
                                id: stayMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.stayPinnedOpen = !root.stayPinnedOpen
                            }

                        }

                        // Clear Unpinned Button
                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            radius: 15
                            color: clearMouse.containsMouse ? Theme.withAlpha(Theme.urgent, 0.24) : Theme.withAlpha(Theme.darker_background, 0.45)
                            border.width: 1
                            border.color: clearMouse.containsMouse ? Theme.withAlpha(Theme.urgent, 0.55) : Theme.withAlpha(Theme.glassBorderColor, 0.22)

                            Text {
                                anchors.centerIn: parent
                                text: Icons.clearSweep
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: 13
                                color: clearMouse.containsMouse ? Theme.urgent : Theme.muted
                            }

                            MouseArea {
                                id: clearMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.clipboardService)
                                        root.clipboardService.clearUnpinned();

                                }
                            }

                        }

                        // Glide-up / Close Button
                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            radius: 15
                            color: closeBtnMouse.containsMouse ? Theme.withAlpha(Theme.lighter_background, 0.55) : Theme.withAlpha(Theme.darker_background, 0.45)
                            border.width: 1
                            border.color: Theme.withAlpha(Theme.glassBorderColor, 0.22)

                            Text {
                                anchors.centerIn: parent
                                text: Icons.chevronUp
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: 16
                                color: Theme.foreground
                            }

                            MouseArea {
                                id: closeBtnMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.close()
                            }

                        }

                    }

                }

                // Hairline Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.withAlpha(Theme.glassBorderColor, 0.22)
                }

                // ─────────────────────────────────────────────────────────────
                // Empty State when no items match
                // ─────────────────────────────────────────────────────────────
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.totalCount === 0

                    WheelHandler {
                        target: null
                        onWheel: function(event) {
                            if (event.angleDelta.y < 0)
                                root.handleSwipeUpDelta(event.angleDelta.y);

                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Icons.clipboard
                            font.family: Icons.effectiveFont(text)
                            font.pixelSize: 34
                            color: Theme.muted
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.searchQuery.length > 0 ? "No matching clips found" : "Clipboard & Screenshot Drawer Ready"
                            font.family: Fonts.uiFont
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: Theme.foreground
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Copy text, capture screenshots, or click Snap — glide two fingers up on the bar to hide"
                            font.family: Fonts.uiFont
                            font.pixelSize: 11
                            color: Theme.muted
                        }

                    }

                }

                // ─────────────────────────────────────────────────────────────
                // Main Content Body (Horizontal SS Gallery + Text Clips)
                // ─────────────────────────────────────────────────────────────
                Flickable {
                    id: mainScroll

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.totalCount > 0
                    clip: true
                    contentWidth: width
                    contentHeight: contentColumn.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    // Overscroll UP past top of drawer closes smoothly on 2-finger glide up!
                    WheelHandler {
                        target: null
                        onWheel: function(event) {
                            if (event.angleDelta.y < 0 && mainScroll.contentY <= 2)
                                root.handleSwipeUpDelta(event.angleDelta.y);
                            else if (event.angleDelta.y !== 0)
                                mainScroll.flick(0, event.angleDelta.y * 5.5);
                        }
                    }

                    ColumnLayout {
                        id: contentColumn

                        width: mainScroll.width
                        spacing: 12

                        // ─────────────────────────────────────────────────────
                        // Section 1: Screenshots & Images Strip / Grid
                        // ─────────────────────────────────────────────────────
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: root.imageItems.length > 0

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: "SCREENSHOTS & IMAGES"
                                    font.family: Fonts.uiFont
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    font.letterSpacing: 1.1
                                    color: Theme.muted
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                Row {
                                    spacing: 4

                                    Text {
                                        text: "Click to paste  ·  Drag onto any app  ·"
                                        font.family: Fonts.uiFont
                                        font.pixelSize: 10
                                        color: Theme.withAlpha(Theme.foreground, 0.55)
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: Icons.copy
                                        font.family: Icons.effectiveFont(text)
                                        font.pixelSize: 11
                                        color: Theme.withAlpha(Theme.accent, 0.8)
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: "to re-copy"
                                        font.family: Fonts.uiFont
                                        font.pixelSize: 10
                                        color: Theme.withAlpha(Theme.foreground, 0.55)
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                }

                            }

                            // In "all" mode: crisp horizontal scrollable strip; in "image" mode: 4-col gallery grid!
                            Loader {
                                id: imageLayoutLoader

                                Layout.fillWidth: true
                                Layout.preferredHeight: (root.filterMode === "image") ? Math.max(132, Math.ceil(root.imageItems.length / 4) * 130) : (Appearance.clipboardThumbHeight + 10)
                                sourceComponent: (root.filterMode === "image") ? imageGridComp : imageStripComp
                            }

                        }

                        // ─────────────────────────────────────────────────────
                        // Section 2: Text & Code Snippets List
                        // ─────────────────────────────────────────────────────
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: root.textItems.length > 0

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: "TEXT, URLS & SNIPPETS"
                                    font.family: Fonts.uiFont
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    font.letterSpacing: 1.1
                                    color: Theme.muted
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: root.textItems.length + " clips"
                                    font.family: Fonts.uiFont
                                    font.pixelSize: 10
                                    color: Theme.withAlpha(Theme.foreground, 0.55)
                                }

                            }

                            Repeater {
                                model: root.textItems

                                delegate: Item {
                                    id: textCardRoot

                                    required property var modelData
                                    required property int index
                                    readonly property bool isCopiedNow: root.clipboardService && root.clipboardService.copiedFeedbackId === modelData.id

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Math.max(54, Math.min(82, textPreviewLabel.implicitHeight + 28))

                                    // Wayland Drag & Drop Payload for Text
                                    Item {
                                        id: textDragPayload

                                        Drag.active: textDragHandler.active
                                        Drag.dragType: Drag.Automatic
                                        Drag.supportedActions: Qt.CopyAction
                                        Drag.hotSpot: Qt.point(24, 16)
                                        Drag.mimeData: {
                                            "text/plain": textCardRoot.modelData.text || ""
                                        }
                                        Drag.onDragStarted: root.isDragging = true
                                        Drag.onDragFinished: function(dropAction) {
                                            root.isDragging = false;
                                            if (dropAction !== Qt.IgnoreAction && !root.stayPinnedOpen)
                                                root.close();

                                        }
                                    }

                                    Rectangle {
                                        id: textCardBg

                                        anchors.fill: parent
                                        radius: 12
                                        color: textCardRoot.isCopiedNow ? Theme.withAlpha(Theme.green, 0.16) : (textCardHover.hovered ? Theme.withAlpha(Theme.accent, 0.14) : Theme.withAlpha(Theme.darker_background, 0.42))
                                        border.width: 1
                                        border.color: textCardRoot.isCopiedNow ? Theme.withAlpha(Theme.green, 0.65) : (textCardHover.hovered ? Theme.withAlpha(Theme.accent, 0.45) : (textCardRoot.modelData.pinned ? Theme.withAlpha(Theme.accent, 0.35) : Theme.withAlpha(Theme.glassBorderColor, 0.18)))
                                        scale: textDragHandler.active ? 0.97 : (textCardHover.hovered ? 1.008 : 1)

                                        // Main body hitbox behind action buttons
                                        Item {
                                            anchors.fill: parent

                                            HoverHandler {
                                                id: textCardHover
                                            }

                                            DragHandler {
                                                id: textDragHandler

                                                target: null
                                                dragThreshold: 8
                                            }

                                            TapHandler {
                                                onTapped: root.pasteCard(textCardRoot.modelData.id)
                                            }

                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 10
                                            spacing: 10

                                            // Drag Grip & Kind Badge / Color Swatch
                                            Row {
                                                spacing: 6
                                                Layout.alignment: Qt.AlignVCenter

                                                Text {
                                                    text: Icons.dragGrip
                                                    font.family: Icons.effectiveFont(text)
                                                    font.pixelSize: 14
                                                    color: textCardHover.hovered ? Theme.accent : Theme.withAlpha(Theme.muted, 0.65)
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                Rectangle {
                                                    width: 26
                                                    height: 26
                                                    radius: 8
                                                    color: textCardRoot.modelData.isColor ? textCardRoot.modelData.colorHex : Theme.withAlpha(Theme.accent, 0.15)
                                                    border.width: 1
                                                    border.color: Theme.withAlpha(Theme.glassBorderColor, 0.3)
                                                    anchors.verticalCenter: parent.verticalCenter

                                                    Text {
                                                        visible: !textCardRoot.modelData.isColor
                                                        anchors.centerIn: parent
                                                        text: textCardRoot.modelData.isUrl ? Icons.linkIcon : (textCardRoot.modelData.isCode ? Icons.codeIcon : Icons.textDoc)
                                                        font.family: Icons.effectiveFont(text)
                                                        font.pixelSize: 13
                                                        color: Theme.accent
                                                    }

                                                }

                                            }

                                            // Text Preview & Metadata
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2

                                                Text {
                                                    id: textPreviewLabel

                                                    Layout.fillWidth: true
                                                    text: textCardRoot.modelData.preview || textCardRoot.modelData.text || ""
                                                    font.family: textCardRoot.modelData.isCode ? Fonts.monoFont : Fonts.uiFont
                                                    font.pixelSize: 12
                                                    color: Theme.bright_foreground
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 2
                                                    wrapMode: Text.WrapAnywhere
                                                }

                                                Row {
                                                    spacing: 8

                                                    Text {
                                                        text: root.clipboardService ? root.clipboardService.formatRelativeTime(textCardRoot.modelData.timestamp) : ""
                                                        font.family: Fonts.uiFont
                                                        font.pixelSize: 10
                                                        color: Theme.muted
                                                    }

                                                    Text {
                                                        visible: (textCardRoot.modelData.lineCount || 1) > 1
                                                        text: "• " + textCardRoot.modelData.lineCount + " lines"
                                                        font.family: Fonts.uiFont
                                                        font.pixelSize: 10
                                                        color: Theme.muted
                                                    }

                                                    Text {
                                                        visible: textCardRoot.modelData.isColor
                                                        text: "• Color Swatch"
                                                        font.family: Fonts.uiFont
                                                        font.pixelSize: 10
                                                        color: Theme.accent
                                                    }

                                                    Text {
                                                        visible: textCardRoot.isCopiedNow
                                                        text: "• Copied ✓"
                                                        font.family: Fonts.uiFont
                                                        font.pixelSize: 10
                                                        font.bold: true
                                                        color: Theme.green
                                                    }

                                                }

                                            }

                                            // Inline Action Pill Buttons (Copy Again, Pin, Delete)
                                            Row {
                                                spacing: 4
                                                z: 10
                                                Layout.alignment: Qt.AlignVCenter

                                                // Copy Again Button
                                                Rectangle {
                                                    width: 26
                                                    height: 26
                                                    radius: 8
                                                    color: txtCopyMouse.containsMouse ? Theme.withAlpha(Theme.accent, 0.24) : Theme.withAlpha(Theme.darker_background, 0.5)
                                                    border.width: 1
                                                    border.color: txtCopyMouse.containsMouse ? Theme.withAlpha(Theme.accent, 0.5) : "transparent"

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: textCardRoot.isCopiedNow ? Icons.check : Icons.copy
                                                        font.family: Icons.effectiveFont(text)
                                                        font.pixelSize: 13
                                                        color: textCardRoot.isCopiedNow ? Theme.green : Theme.foreground
                                                    }

                                                    MouseArea {
                                                        id: txtCopyMouse

                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.copyCard(textCardRoot.modelData.id)
                                                    }

                                                }

                                                // Pin Button
                                                Rectangle {
                                                    width: 26
                                                    height: 26
                                                    radius: 8
                                                    color: textCardRoot.modelData.pinned ? Theme.withAlpha(Theme.accent, 0.22) : (txtPinMouse.containsMouse ? Theme.withAlpha(Theme.lighter_background, 0.5) : Theme.withAlpha(Theme.darker_background, 0.5))

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: Icons.pin
                                                        font.family: Icons.effectiveFont(text)
                                                        font.pixelSize: 13
                                                        color: textCardRoot.modelData.pinned ? Theme.accent : Theme.muted
                                                    }

                                                    MouseArea {
                                                        id: txtPinMouse

                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            if (root.clipboardService)
                                                                root.clipboardService.togglePin(textCardRoot.modelData.id);

                                                        }
                                                    }

                                                }

                                                // Delete Button
                                                Rectangle {
                                                    width: 26
                                                    height: 26
                                                    radius: 8
                                                    color: txtDelMouse.containsMouse ? Theme.withAlpha(Theme.urgent, 0.24) : Theme.withAlpha(Theme.darker_background, 0.5)

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: Icons.trash
                                                        font.family: Icons.effectiveFont(text)
                                                        font.pixelSize: 13
                                                        color: txtDelMouse.containsMouse ? Theme.urgent : Theme.muted
                                                    }

                                                    MouseArea {
                                                        id: txtDelMouse

                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            if (root.clipboardService)
                                                                root.clipboardService.deleteItem(textCardRoot.modelData.id);

                                                        }
                                                    }

                                                }

                                            }

                                        }

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: 140
                                                easing.type: Easing.OutCubic
                                            }

                                        }

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 140
                                            }

                                        }

                                    }

                                }

                            }

                        }

                    }

                }

                // ─────────────────────────────────────────────────────────────
                // Bottom Glide-Up Grabber Handle (Interactive visual affordance)
                // ─────────────────────────────────────────────────────────────
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 10

                    WheelHandler {
                        target: null
                        onWheel: function(event) {
                            if (event.angleDelta.y < 0)
                                root.handleSwipeUpDelta(event.angleDelta.y);

                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: grabMouse.containsMouse ? 58 : 42
                        height: 4
                        radius: 2
                        color: grabMouse.containsMouse ? Theme.accent : Theme.withAlpha(Theme.foreground, 0.35)

                        Behavior on width {
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutCubic
                            }

                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }

                        }

                    }

                    MouseArea {
                        id: grabMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }

                }

            }

        }

    }

    // ─────────────────────────────────────────────────────────────────────────
    // Reusable Screenshot Card Component Templates
    // ─────────────────────────────────────────────────────────────────────────
    Component {
        id: imageStripComp

        ListView {
            id: imgStripList

            orientation: ListView.Horizontal
            spacing: 10
            clip: true
            interactive: false
            cacheBuffer: 2400
            snapMode: ListView.SnapToItem
            model: root.imageItems

            WheelHandler {
                target: null
                onWheel: function(event) {
                    if (Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y))
                        imgStripList.flick(event.angleDelta.x * 6, 0);
                    else if (event.angleDelta.y < 0 && mainScroll.contentY <= 2)
                        root.handleSwipeUpDelta(event.angleDelta.y);
                    else if (event.angleDelta.y !== 0)
                        imgStripList.flick(event.angleDelta.y * 5, 0);
                }
            }

            delegate: ImageCardDelegate {
                width: Math.floor((imgStripList.width - 30) / 4)
                height: Appearance.clipboardThumbHeight
            }

        }

    }

    Component {
        id: imageGridComp

        GridView {
            id: imgGrid

            cellWidth: Math.floor((width - 2) / 4)
            cellHeight: 128
            clip: true
            interactive: false
            cacheBuffer: 2400
            model: root.imageItems

            delegate: Item {
                required property var modelData
                required property int index

                width: imgGrid.cellWidth
                height: imgGrid.cellHeight

                ImageCardDelegate {
                    anchors.fill: parent
                    anchors.margins: 4
                    modelData: parent.modelData
                    index: parent.index
                }

            }

        }

    }

    // Inline Component for Screenshot/Image Card (Click-to-Paste + Copy + Edit + Pin + Drag&Drop)
    component ImageCardDelegate: Item {
        id: imgCard

        required property var modelData
        required property int index
        readonly property bool isCopiedNow: root.clipboardService && root.clipboardService.copiedFeedbackId === modelData.id

        // Wayland External Drag & Drop Payload (Carries file URI & thumbnail pixmap)
        Item {
            id: imgDragPayload

            Drag.active: imgDragHandler.active
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction
            Drag.hotSpot: Qt.point(80, 50)
            Drag.imageSource: imgCard.modelData.thumbPath ? ("file://" + imgCard.modelData.thumbPath) : (imgCard.modelData.path ? ("file://" + imgCard.modelData.path) : "")
            Drag.imageSourceSize: Qt.size(160, 100)
            Drag.mimeData: {
                "text/uri-list": "file://" + (imgCard.modelData.path || "") + "\r\n",
                "text/plain": imgCard.modelData.path || ""
            }
            Drag.onDragStarted: root.isDragging = true
            Drag.onDragFinished: function(dropAction) {
                root.isDragging = false;
                if (dropAction !== Qt.IgnoreAction && !root.stayPinnedOpen)
                    root.close();

            }
        }

        Rectangle {
            id: imgCardFrame

            anchors.fill: parent
            radius: 13
            color: Theme.withAlpha(Theme.darker_background, 0.72)
            clip: true
            border.width: imgCard.isCopiedNow || imgCardHover.hovered || imgCard.modelData.pinned ? 2 : 1
            border.color: imgCard.isCopiedNow ? Theme.green : (imgCardHover.hovered ? Theme.accent : (imgCard.modelData.pinned ? Theme.withAlpha(Theme.accent, 0.55) : Theme.withAlpha(Theme.glassBorderColor, 0.25)))
            scale: imgDragHandler.active ? 0.96 : (imgCardHover.hovered ? 1.022 : 1)

            // Thumbnail Image Preview
            Image {
                anchors.fill: parent
                anchors.margins: 1
                source: imgCard.modelData.thumbPath ? ("file://" + imgCard.modelData.thumbPath) : (imgCard.modelData.path ? ("file://" + imgCard.modelData.path) : "")
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
                mipmap: true
                sourceSize: Qt.size(320, 200)
            }

            // Subtle dark bottom gradient scrim for badge readability
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 44

                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: "transparent"
                    }

                    GradientStop {
                        position: 1
                        color: Qt.rgba(0, 0, 0, 0.78)
                    }

                }

            }

            // Card Body Interaction Layer (Behind Action Buttons)
            Item {
                anchors.fill: parent

                HoverHandler {
                    id: imgCardHover
                }

                DragHandler {
                    id: imgDragHandler

                    target: null
                    dragThreshold: 8
                }

                TapHandler {
                    onTapped: root.pasteCard(imgCard.modelData.id)
                }

            }

            // Top-Left Drag Grip + Resolution Badge
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 6
                height: 20
                width: metaRow.implicitWidth + 10
                radius: 10
                color: Qt.rgba(0, 0, 0, 0.65)
                border.width: 1
                border.color: Theme.withAlpha(Theme.glassBorderColor, 0.25)

                Row {
                    id: metaRow

                    anchors.centerIn: parent
                    spacing: 3

                    Text {
                        text: Icons.dragGrip
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: 11
                        color: imgCardHover.hovered ? Theme.accent : Theme.bright_foreground
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: (imgCard.modelData.width > 0) ? (imgCard.modelData.width + "×" + imgCard.modelData.height) : "IMG"
                        font.family: Fonts.uiFont
                        font.pixelSize: 9
                        font.bold: true
                        color: Theme.bright_foreground
                        anchors.verticalCenter: parent.verticalCenter
                    }

                }

            }

            // "Copied ✓" Flash Badge
            Rectangle {
                anchors.centerIn: parent
                height: 26
                width: copiedLabelRow.implicitWidth + 18
                radius: 13
                color: Theme.green
                visible: imgCard.isCopiedNow
                z: 15

                Row {
                    id: copiedLabelRow

                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: Icons.check
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: 13
                        color: Theme.darker_background
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "Copied"
                        font.family: Fonts.uiFont
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.darker_background
                        anchors.verticalCenter: parent.verticalCenter
                    }

                }

            }

            // Top-Right Action Pill Cluster (Copy, Edit in Swappy, Pin, Delete)
            Row {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 6
                spacing: 4
                z: 10
                opacity: (imgCardHover.hovered || imgCard.modelData.pinned) ? 1 : 0.72

                // Copy Again
                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
                    color: imgCopyM.containsMouse ? Theme.accent : Qt.rgba(0, 0, 0, 0.68)

                    Text {
                        anchors.centerIn: parent
                        text: Icons.copy
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: 11
                        color: imgCopyM.containsMouse ? Theme.darker_background : Theme.bright_foreground
                    }

                    MouseArea {
                        id: imgCopyM

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.copyCard(imgCard.modelData.id)
                    }

                }

                // Annotate / Edit in Swappy
                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
                    visible: imgCardHover.hovered
                    color: imgEditM.containsMouse ? Theme.accent : Qt.rgba(0, 0, 0, 0.68)

                    Text {
                        anchors.centerIn: parent
                        text: Icons.editBrush
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: 11
                        color: imgEditM.containsMouse ? Theme.darker_background : Theme.bright_foreground
                    }

                    MouseArea {
                        id: imgEditM

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.clipboardService)
                                root.clipboardService.annotateImage(imgCard.modelData.path);

                        }
                    }

                }

                // Pin
                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
                    color: imgCard.modelData.pinned ? Theme.accent : (imgPinM.containsMouse ? Theme.lighter_background : Qt.rgba(0, 0, 0, 0.68))

                    Text {
                        anchors.centerIn: parent
                        text: Icons.pin
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: 11
                        color: imgCard.modelData.pinned ? Theme.darker_background : Theme.bright_foreground
                    }

                    MouseArea {
                        id: imgPinM

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.clipboardService)
                                root.clipboardService.togglePin(imgCard.modelData.id);

                        }
                    }

                }

                // Delete
                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
                    visible: imgCardHover.hovered
                    color: imgDelM.containsMouse ? Theme.urgent : Qt.rgba(0, 0, 0, 0.68)

                    Text {
                        anchors.centerIn: parent
                        text: Icons.trash
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: 11
                        color: Theme.bright_foreground
                    }

                    MouseArea {
                        id: imgDelM

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.clipboardService)
                                root.clipboardService.deleteItem(imgCard.modelData.id);

                        }
                    }

                }

            }

            // Bottom Footer Caption (Timestamp / Click to Paste hint)
            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 7

                Text {
                    text: imgCardHover.hovered ? "Click to paste" : (root.clipboardService ? root.clipboardService.formatRelativeTime(imgCard.modelData.timestamp) : "")
                    font.family: Fonts.uiFont
                    font.pixelSize: 10
                    font.bold: imgCardHover.hovered
                    color: imgCardHover.hovered ? Theme.accent : Theme.bright_foreground
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: root.clipboardService ? root.clipboardService.formatSize(imgCard.modelData.sizeBytes) : ""
                    font.family: Fonts.uiFont
                    font.pixelSize: 9
                    color: Theme.withAlpha(Theme.bright_foreground, 0.78)
                }

            }

            Behavior on scale {
                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }

            }

        }

    }

}
