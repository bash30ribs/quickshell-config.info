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
    readonly property real targetDrawerHeight: {
        var chrome = (Appearance.clipboardPadding * 2) + 34 + 1 + 10 + 18 + 8;
        if (root.totalCount === 0)
            return 220;

        var bodyH = contentColumn.implicitHeight + 12;
        return Math.max(220, Math.min(Appearance.clipboardHeight, Math.round(chrome + bodyH)));
    }

    function open() {
        if (root.clipboardService)
            root.clipboardService.syncNow();

        root.gestureUpAccum = 0;
        root.openedAtMs = Date.now();
        root.isVisibleSurface = true;
        root.isOpen = true;
        closeAnim.stop();
        openAnim.restart();
    }

    function close() {
        if (!root.isOpen && !root.isVisibleSurface)
            return ;

        root.gestureUpAccum = 0;
        searchInput.focus = false;
        root.isOpen = false;
        openAnim.stop();
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

        if (Date.now() - root.openedAtMs < 320)
            return ;

        if (dy < 0) {
            root.gestureUpAccum += dy;
            gestureDecayTimer.restart();
            if (root.gestureUpAccum <= -10) {
                root.gestureUpAccum = 0;
                root.close();
            }
        } else if (dy > 6) {
            root.gestureUpAccum = 0;
        }
    }

    function handleUpWheel(event) {
        var dy = Theme.wheelDeltaY(event);
        if (dy < 0) {
            event.accepted = true;
            root.handleSwipeUpDelta(dy);
        } else {
            event.accepted = false;
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

    onFilterModeChanged: {
        if (mainScroll)
            mainScroll.contentY = 0;

    }
    visible: root.isVisibleSurface
    color: "transparent"
    implicitWidth: Appearance.clipboardWidth
    implicitHeight: Appearance.clipboardHeight + 28
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
        top: Appearance.barHeight
    }

    // Crisp, non-sluggish fluid slide-and-scale reveal from beneath the bar
    NumberAnimation {
        id: openAnim

        target: root
        property: "animProgress"
        to: 1
        duration: 145
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: closeAnim

        target: root
        property: "animProgress"
        to: 0
        duration: 110
        easing.type: Easing.OutQuad
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

        interval: 220
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

    // Clipped viewport so drawer emerges cleanly from just beneath the bar
    Item {
        id: clipViewport

        anchors.fill: parent
        clip: true

        GlassPanel {
            id: drawerSurface

            width: Appearance.clipboardWidth
            height: root.targetDrawerHeight
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(6 - ((1 - root.animProgress) * 18))
            radius: Appearance.clipboardRadius
            baseColor: Theme.barBackground
            accentTint: Theme.accent
            clarity: 0.78
            rimIllumination: 0.5
            specularIntensity: 0.75
            transformOrigin: Item.Top
            opacity: Math.max(0, Math.min(1, root.animProgress * 2.5))
            scale: 0.97 + (0.03 * root.animProgress)

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: Appearance.clipboardPadding
                anchors.rightMargin: Appearance.clipboardPadding
                anchors.topMargin: Appearance.clipboardPadding - 1
                anchors.bottomMargin: 8
                spacing: 10

                // ─────────────────────────────────────────────────────────────
                // Unified Pill Header (Accent Filter Track · Search · Actions)
                // ─────────────────────────────────────────────────────────────
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34

                    MouseArea {
                        anchors.fill: parent
                        z: 100
                        acceptedButtons: Qt.NoButton
                        hoverEnabled: false
                        scrollGestureEnabled: true
                        onWheel: function(event) {
                            root.handleUpWheel(event);
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: 10

                        // Accent Pill Segmented Filter Switcher (Matches PowerMenu)
                        Rectangle {
                            id: filterTrack

                            Layout.preferredHeight: 34
                            Layout.preferredWidth: filterRow.implicitWidth + 6
                            radius: 17
                            color: Theme.withAlpha(Theme.darker_background, 0.46)
                            border.width: 1
                            border.color: Theme.withAlpha(Theme.glassBorderColor, 0.22)

                            Rectangle {
                                id: activeTabIndicator

                                readonly property int activeIndex: {
                                    if (root.filterMode === "image")
                                        return 1;

                                    if (root.filterMode === "text")
                                        return 2;

                                    if (root.filterMode === "pinned")
                                        return 3;

                                    return 0;
                                }
                                readonly property var activeItem: filterRepeater.itemAt(activeIndex)

                                y: 3
                                height: 28
                                radius: 14
                                color: Theme.accent
                                x: activeItem ? (activeItem.x + 3) : 3
                                width: activeItem ? activeItem.width : 46

                                Behavior on x {
                                    NumberAnimation {
                                        duration: 180
                                        easing.type: Easing.OutCubic
                                    }

                                }

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 150
                                        easing.type: Easing.OutCubic
                                    }

                                }

                            }

                            Row {
                                id: filterRow

                                anchors.left: parent.left
                                anchors.leftMargin: 3
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 0

                                Repeater {
                                    id: filterRepeater

                                    model: [{
                                        "label": "All",
                                        "modeValue": "all"
                                    }, {
                                        "label": "Images",
                                        "modeValue": "image"
                                    }, {
                                        "label": "Text",
                                        "modeValue": "text"
                                    }, {
                                        "label": "Pinned",
                                        "modeValue": "pinned"
                                    }]

                                    delegate: Item {
                                        required property var modelData
                                        readonly property bool isCurrent: root.filterMode === modelData.modeValue

                                        width: tabLbl.implicitWidth + 22
                                        height: 28

                                        Text {
                                            id: tabLbl

                                            anchors.centerIn: parent
                                            text: parent.modelData.label
                                            font.family: Fonts.uiFont
                                            font.pixelSize: 11
                                            font.weight: parent.isCurrent ? Font.Bold : Font.Medium
                                            color: parent.isCurrent ? Theme.darker_background : (tMouse.containsMouse ? Theme.bright_foreground : Theme.foreground)

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: 120
                                                }

                                            }

                                        }

                                        MouseArea {
                                            id: tMouse

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.filterMode = parent.modelData.modeValue
                                        }

                                    }

                                }

                            }

                        }

                        // Integrated Liquid Glass Search Capsule (Matches AppLauncher)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            radius: 17
                            color: Theme.withAlpha(Theme.darker_background, searchInput.activeFocus ? 0.54 : 0.38)
                            border.width: 1
                            border.color: searchInput.activeFocus ? Theme.withAlpha(Theme.accent, 0.58) : Theme.withAlpha(Theme.glassBorderColor, 0.2)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 13
                                anchors.rightMargin: 10
                                spacing: 8

                                Text {
                                    text: Icons.search
                                    font.family: Icons.effectiveFont(text)
                                    font.pixelSize: 14
                                    color: searchInput.activeFocus ? Theme.accent : Theme.muted

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 130
                                        }

                                    }

                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    Text {
                                        anchors.fill: parent
                                        verticalAlignment: Text.AlignVCenter
                                        text: "Search clipboard..."
                                        font.family: Fonts.uiFont
                                        font.pixelSize: 12
                                        color: Theme.withAlpha(Theme.foreground, 0.48)
                                        visible: searchInput.text.length === 0
                                    }

                                    TextInput {
                                        id: searchInput

                                        anchors.fill: parent
                                        verticalAlignment: TextInput.AlignVCenter
                                        font.family: Fonts.uiFont
                                        font.pixelSize: 12
                                        color: Theme.bright_foreground
                                        selectionColor: Theme.selection
                                        selectedTextColor: Theme.bright_foreground
                                        clip: true
                                        onTextChanged: root.searchQuery = text
                                        Keys.onReturnPressed: {
                                            if (root.filteredAll && root.filteredAll.length > 0)
                                                root.pasteCard(root.filteredAll[0].id);

                                        }
                                        Keys.onEscapePressed: root.close()
                                    }

                                }

                                GhostIconButton {
                                    visible: searchInput.text.length > 0
                                    glyph: Icons.close
                                    buttonSize: 22
                                    glyphSize: 12
                                    cornerRadius: 11
                                    onClicked: {
                                        searchInput.text = "";
                                        searchInput.focus = false;
                                    }
                                }

                            }

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: 130
                                }

                            }

                        }

                        // Action Pill Capsule
                        Rectangle {
                            Layout.preferredHeight: 34
                            Layout.preferredWidth: actionRow.implicitWidth + 8
                            radius: 17
                            color: Theme.withAlpha(Theme.darker_background, 0.42)
                            border.width: 1
                            border.color: Theme.withAlpha(Theme.glassBorderColor, 0.18)

                            Row {
                                id: actionRow

                                anchors.centerIn: parent
                                spacing: 2

                                GhostIconButton {
                                    glyph: Icons.camera
                                    buttonSize: 28
                                    glyphSize: 14
                                    cornerRadius: 14
                                    onClicked: {
                                        root.close();
                                        if (root.clipboardService)
                                            root.clipboardService.captureSnap("region");

                                    }
                                }

                                GhostIconButton {
                                    glyph: Icons.pin
                                    buttonSize: 28
                                    glyphSize: 14
                                    cornerRadius: 14
                                    active: root.stayPinnedOpen
                                    onClicked: root.stayPinnedOpen = !root.stayPinnedOpen
                                }

                                GhostIconButton {
                                    glyph: Icons.clearSweep
                                    buttonSize: 28
                                    glyphSize: 14
                                    cornerRadius: 14
                                    destructive: true
                                    onClicked: {
                                        if (root.clipboardService)
                                            root.clipboardService.clearUnpinned();

                                    }
                                }

                                GhostIconButton {
                                    glyph: Icons.chevronUp
                                    buttonSize: 28
                                    glyphSize: 16
                                    cornerRadius: 14
                                    onClicked: root.close()
                                }

                            }

                        }

                    }

                }

                // Subtle Luminous Horizontal Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1

                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop {
                            position: 0
                            color: "transparent"
                        }

                        GradientStop {
                            position: 0.15
                            color: Theme.withAlpha(Theme.bright_foreground, 0.1)
                        }

                        GradientStop {
                            position: 0.85
                            color: Theme.withAlpha(Theme.bright_foreground, 0.1)
                        }

                        GradientStop {
                            position: 1
                            color: "transparent"
                        }

                    }

                }

                // ─────────────────────────────────────────────────────────────
                // Empty State
                // ─────────────────────────────────────────────────────────────
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.totalCount === 0

                    MouseArea {
                        anchors.fill: parent
                        z: 100
                        acceptedButtons: Qt.NoButton
                        hoverEnabled: false
                        scrollGestureEnabled: true
                        onWheel: function(event) {
                            root.handleUpWheel(event);
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 42
                            height: 42
                            radius: 14
                            color: Theme.withAlpha(Theme.accent, 0.12)
                            border.width: 1
                            border.color: Theme.withAlpha(Theme.accent, 0.25)

                            Text {
                                anchors.centerIn: parent
                                text: Icons.clipboard
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: 20
                                color: Theme.accent
                            }

                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.searchQuery.length > 0 ? "No matching entries" : "Clipboard is empty"
                            font.family: Fonts.uiFont
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: Theme.bright_foreground
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.searchQuery.length > 0 ? "Try another keyword or clear filters" : "Screenshots and copied clips appear right here"
                            font.family: Fonts.uiFont
                            font.pixelSize: 11
                            color: Theme.muted
                        }

                    }

                }

                // ─────────────────────────────────────────────────────────────
                // Content Area (Screenshots Strip/Grid + Floating Pill History)
                // ─────────────────────────────────────────────────────────────
                Item {
                    id: mainScrollWrap

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.totalCount > 0

                    MouseArea {
                        id: mainWheelArea

                        anchors.fill: parent
                        z: 100
                        acceptedButtons: Qt.NoButton
                        hoverEnabled: false
                        scrollGestureEnabled: true
                        onWheel: function(event) {
                            var dx = Theme.wheelDeltaX(event);
                            var dy = Theme.wheelDeltaY(event);
                            if (dx === 0 && dy === 0) {
                                event.accepted = false;
                                return ;
                            }
                            if (root.filterMode !== "image" && imageLayoutLoader.item) {
                                var p = mainWheelArea.mapToItem(imageLayoutLoader, event.x, event.y);
                                if (p.y >= 0 && p.y <= imageLayoutLoader.height && p.x >= 0 && p.x <= imageLayoutLoader.width) {
                                    var strip = imageLayoutLoader.item;
                                    var maxX = Math.max(0, strip.contentWidth - strip.width);
                                    if (maxX > 0) {
                                        var stripDelta = (Math.abs(dx) >= Math.abs(dy)) ? dx : dy;
                                        var nextX = Math.max(0, Math.min(maxX, strip.contentX - (stripDelta * 0.55)));
                                        if (Math.abs(nextX - strip.contentX) > 0.01) {
                                            strip.contentX = nextX;
                                            event.accepted = true;
                                            return ;
                                        }
                                        // If horizontal gesture reached strip edge, absorb cleanly instead of closing drawer
                                        if (Math.abs(dx) >= Math.abs(dy)) {
                                            event.accepted = true;
                                            return ;
                                        }
                                    }
                                }
                            }
                            if (dy === 0 || Math.abs(dy) < Math.abs(dx) * 0.5) {
                                event.accepted = false;
                                return ;
                            }
                            var maxY = Math.max(0, mainScroll.contentHeight - mainScroll.height);
                            if (maxY > 0)
                                mainScroll.contentY = Math.max(0, Math.min(maxY, mainScroll.contentY - (dy * 0.5)));

                            event.accepted = true;
                        }
                    }

                    // Subtle vertical scroll thumb when content exceeds viewport
                    Rectangle {
                        readonly property real maxY: Math.max(0, mainScroll.contentHeight - mainScroll.height)
                        readonly property real ratio: mainScroll.contentHeight > 0 ? Math.min(1, mainScroll.height / mainScroll.contentHeight) : 1

                        anchors.right: parent.right
                        anchors.rightMargin: -6
                        width: 3
                        radius: 1.5
                        color: Theme.withAlpha(Theme.bright_foreground, 0.28)
                        height: Math.max(24, mainScroll.height * ratio)
                        y: maxY > 0 ? ((mainScroll.contentY / maxY) * Math.max(0, mainScroll.height - height)) : 0
                        visible: maxY > 1
                        z: 110
                    }

                    Flickable {
                        id: mainScroll

                        anchors.fill: parent
                        clip: true
                        contentWidth: width
                        contentHeight: contentColumn.implicitHeight
                        interactive: false
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: contentColumn

                            width: mainScroll.width
                            spacing: 14

                            // Section 1: Screenshots Gallery
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                visible: root.imageItems.length > 0

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Rectangle {
                                        width: 6
                                        height: 6
                                        radius: 3
                                        color: Theme.accent
                                    }

                                    Text {
                                        text: "Screenshots"
                                        font.family: Fonts.uiFont
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        color: Theme.bright_foreground
                                    }

                                    Rectangle {
                                        height: 17
                                        width: imgCountLbl.implicitWidth + 12
                                        radius: 8
                                        color: Theme.withAlpha(Theme.accent, 0.16)
                                        border.width: 1
                                        border.color: Theme.withAlpha(Theme.accent, 0.28)

                                        Text {
                                            id: imgCountLbl

                                            anchors.centerIn: parent
                                            text: String(root.imageItems.length)
                                            font.family: Fonts.monoFont
                                            font.pixelSize: 10
                                            font.weight: Font.DemiBold
                                            color: Theme.accent
                                        }

                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: "Click to paste · Drag to drop"
                                        font.family: Fonts.uiFont
                                        font.pixelSize: 10
                                        color: Theme.withAlpha(Theme.muted, 0.85)
                                    }

                                    Rectangle {
                                        visible: root.filterMode !== "image" && root.imageItems.length > 4
                                        height: 18
                                        width: viewAllLbl.implicitWidth + 12
                                        radius: 9
                                        color: viewAllMouse.containsMouse ? Theme.withAlpha(Theme.accent, 0.2) : Theme.withAlpha(Theme.bright_foreground, 0.07)
                                        border.width: 1
                                        border.color: viewAllMouse.containsMouse ? Theme.withAlpha(Theme.accent, 0.45) : Theme.withAlpha(Theme.bright_foreground, 0.1)

                                        Text {
                                            id: viewAllLbl

                                            anchors.centerIn: parent
                                            text: "View all"
                                            font.family: Fonts.uiFont
                                            font.pixelSize: 10
                                            font.weight: Font.Medium
                                            color: viewAllMouse.containsMouse ? Theme.accent : Theme.foreground
                                        }

                                        MouseArea {
                                            id: viewAllMouse

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.filterMode = "image"
                                        }

                                    }

                                }

                                Loader {
                                    id: imageLayoutLoader

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: (root.filterMode === "image") ? Math.max(114, Math.ceil(root.imageItems.length / 4) * 114) : Appearance.clipboardThumbHeight
                                    sourceComponent: (root.filterMode === "image") ? imageGridComp : imageStripComp
                                }

                                // Horizontal strip scroll progress bar when more screenshots exist off-screen
                                Item {
                                    id: stripProgressTrack

                                    readonly property var stripItem: imageLayoutLoader.item
                                    readonly property real maxX: (stripItem && root.filterMode !== "image") ? Math.max(0, stripItem.contentWidth - stripItem.width) : 0
                                    readonly property real thumbRatio: (stripItem && stripItem.contentWidth > 0) ? Math.min(1, stripItem.width / stripItem.contentWidth) : 1

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 3
                                    visible: root.filterMode !== "image" && maxX > 1

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 1.5
                                        color: Theme.withAlpha(Theme.bright_foreground, 0.07)

                                        Rectangle {
                                            height: parent.height
                                            radius: 1.5
                                            width: Math.max(28, parent.width * stripProgressTrack.thumbRatio)
                                            x: stripProgressTrack.maxX > 0 ? ((stripProgressTrack.stripItem.contentX / stripProgressTrack.maxX) * Math.max(0, parent.width - width)) : 0
                                            color: Theme.withAlpha(Theme.accent, 0.72)
                                        }

                                    }

                                }

                            }

                            // Section 2: Floating Text & Snippet Pill Rows
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                visible: root.textItems.length > 0

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Rectangle {
                                        width: 6
                                        height: 6
                                        radius: 3
                                        color: Theme.cyan
                                    }

                                    Text {
                                        text: root.filterMode === "pinned" ? "Pinned Clips" : "Recent Clips"
                                        font.family: Fonts.uiFont
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        color: Theme.bright_foreground
                                    }

                                    Rectangle {
                                        height: 17
                                        width: txtCountLbl.implicitWidth + 12
                                        radius: 8
                                        color: Theme.withAlpha(Theme.bright_foreground, 0.08)
                                        border.width: 1
                                        border.color: Theme.withAlpha(Theme.bright_foreground, 0.1)

                                        Text {
                                            id: txtCountLbl

                                            anchors.centerIn: parent
                                            text: String(root.textItems.length)
                                            font.family: Fonts.monoFont
                                            font.pixelSize: 10
                                            font.weight: Font.DemiBold
                                            color: Theme.foreground
                                        }

                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                }

                                ColumnLayout {
                                    id: textListCol

                                    Layout.fillWidth: true
                                    spacing: 5

                                    Repeater {
                                        model: root.textItems

                                        delegate: ClipboardTextRow {
                                            clipboardService: root.clipboardService
                                            stayPinnedOpen: root.stayPinnedOpen
                                            onPasteRequested: function(id) {
                                                root.pasteCard(id);
                                            }
                                            onCopyRequested: function(id) {
                                                root.copyCard(id);
                                            }
                                            onDragStateChanged: function(dragging) {
                                                root.isDragging = dragging;
                                            }
                                            onCloseDrawerRequested: root.close()
                                        }

                                    }

                                }

                            }

                        }

                    }

                }

                // ─────────────────────────────────────────────────────────────
                // Tactile Pill Handle (Two-finger swipe up or click to close)
                // ─────────────────────────────────────────────────────────────
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 8

                    Rectangle {
                        anchors.centerIn: parent
                        width: grabMouse.containsMouse ? 52 : 34
                        height: 3
                        radius: 2
                        color: grabMouse.containsMouse ? Theme.accent : Theme.withAlpha(Theme.bright_foreground, 0.24)

                        Behavior on width {
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutCubic
                            }

                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 140
                            }

                        }

                    }

                    MouseArea {
                        id: grabMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        scrollGestureEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                        onWheel: function(event) {
                            root.handleUpWheel(event);
                        }
                    }

                }

            }

            Behavior on height {
                enabled: root.isOpen && !openAnim.running && !closeAnim.running

                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }

            }

        }

    }

    // ─────────────────────────────────────────────────────────────────────────
    // Screenshot Strip & Grid Containers
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
            snapMode: ListView.NoSnap
            model: root.imageItems

            delegate: ClipboardImageCard {
                width: Math.floor((imgStripList.width - 30) / 4)
                height: Appearance.clipboardThumbHeight
                clipboardService: root.clipboardService
                stayPinnedOpen: root.stayPinnedOpen
                onPasteRequested: function(id) {
                    root.pasteCard(id);
                }
                onCopyRequested: function(id) {
                    root.copyCard(id);
                }
                onDragStateChanged: function(dragging) {
                    root.isDragging = dragging;
                }
                onCloseDrawerRequested: root.close()
            }

        }

    }

    Component {
        id: imageGridComp

        GridView {
            id: imgGrid

            cellWidth: Math.floor((width - 2) / 4)
            cellHeight: 114
            clip: true
            interactive: false
            cacheBuffer: 2400
            model: root.imageItems

            delegate: Item {
                required property var modelData
                required property int index

                width: imgGrid.cellWidth
                height: imgGrid.cellHeight

                ClipboardImageCard {
                    anchors.fill: parent
                    anchors.margins: 4
                    modelData: parent.modelData
                    index: parent.index
                    clipboardService: root.clipboardService
                    stayPinnedOpen: root.stayPinnedOpen
                    onPasteRequested: function(id) {
                        root.pasteCard(id);
                    }
                    onCopyRequested: function(id) {
                        root.copyCard(id);
                    }
                    onDragStateChanged: function(dragging) {
                        root.isDragging = dragging;
                    }
                    onCloseDrawerRequested: root.close()
                }

            }

        }

    }

    mask: Region {
        item: drawerSurface
    }

}
