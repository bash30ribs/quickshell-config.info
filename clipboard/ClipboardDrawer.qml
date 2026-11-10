import "../components"
import "../services"
import "../theme"
import QtQuick
import QtQuick.Effects
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

        if (Date.now() - root.openedAtMs < 240)
            return ;

        if (dy < 0) {
            root.gestureUpAccum += dy;
            gestureDecayTimer.restart();
            if (root.gestureUpAccum <= -14) {
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
        top: Appearance.barHeight + 4
    }

    // Smooth critically-damped slide reveal from beneath the bar
    SpringAnimation {
        id: openSpring

        target: root
        property: "animProgress"
        to: 1
        spring: 5.4
        damping: 0.56
        epsilon: 0.002
    }

    NumberAnimation {
        id: closeAnim

        target: root
        property: "animProgress"
        to: 0
        duration: 185
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

    // Clipped viewport so drawer slides out cleanly from beneath the bar
    Item {
        id: clipViewport

        anchors.fill: parent
        clip: true

        GlassPanel {
            id: drawerSurface

            width: Appearance.clipboardWidth
            height: Appearance.clipboardHeight
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round((root.animProgress - 1) * (height + 16))
            radius: Appearance.clipboardRadius
            baseColor: Theme.barBackground
            accentTint: Theme.accent
            clarity: 0.72
            rimIllumination: 0.34
            specularIntensity: 0.42
            transformOrigin: Item.Top
            opacity: Math.max(0, Math.min(1, root.animProgress * 1.45))
            scale: 0.96 + 0.04 * Math.min(1.02, root.animProgress)

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: Appearance.clipboardPadding
                anchors.rightMargin: Appearance.clipboardPadding
                anchors.topMargin: Appearance.clipboardPadding - 2
                anchors.bottomMargin: 8
                spacing: 10

                // ─────────────────────────────────────────────────────────────
                // Unified Toolbar (Segmented Filters · Search · Ghost Actions)
                // ─────────────────────────────────────────────────────────────
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        target: null
                        onWheel: function(event) {
                            var dy = Theme.wheelDeltaY(event);
                            if (dy < 0)
                                root.handleSwipeUpDelta(dy);

                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: 10

                        // Quiet Segmented Switcher
                        Rectangle {
                            id: filterTrack

                            Layout.preferredHeight: 30
                            Layout.preferredWidth: filterRow.implicitWidth + 6
                            radius: 8
                            color: Theme.withAlpha(Theme.darker_background, 0.44)
                            border.width: 1
                            border.color: Theme.withAlpha(Theme.bright_foreground, 0.08)

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
                                height: 24
                                radius: 6
                                color: Theme.withAlpha(Theme.lighter_background, 0.82)
                                border.width: 1
                                border.color: Theme.withAlpha(Theme.bright_foreground, 0.1)
                                x: activeItem ? (activeItem.x + 3) : 3
                                width: activeItem ? activeItem.width : 44

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
                                        height: 24

                                        Text {
                                            id: tabLbl

                                            anchors.centerIn: parent
                                            text: parent.modelData.label
                                            font.family: Fonts.uiFont
                                            font.pixelSize: 11
                                            font.weight: parent.isCurrent ? Font.DemiBold : Font.Normal
                                            color: parent.isCurrent ? Theme.bright_foreground : (tMouse.containsMouse ? Theme.foreground : Theme.muted)

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

                        // Integrated Search Field
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            radius: 8
                            color: Theme.withAlpha(Theme.darker_background, searchInput.activeFocus ? 0.52 : 0.34)
                            border.width: 1
                            border.color: searchInput.activeFocus ? Theme.withAlpha(Theme.accent, 0.48) : Theme.withAlpha(Theme.bright_foreground, 0.07)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 8
                                spacing: 7

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
                                        text: "Search clipboard..."
                                        font.family: Fonts.uiFont
                                        font.pixelSize: 12
                                        color: Theme.withAlpha(Theme.foreground, 0.45)
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
                                    buttonSize: 20
                                    glyphSize: 12
                                    onClicked: {
                                        searchInput.text = "";
                                        searchInput.focus = false;
                                    }
                                }

                            }

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: 120
                                }

                            }

                        }

                        // Quiet Vertical Separator
                        Rectangle {
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 16
                            color: Theme.withAlpha(Theme.bright_foreground, 0.1)
                        }

                        // Compact Borderless Ghost Actions
                        Row {
                            spacing: 2

                            GhostIconButton {
                                glyph: Icons.camera
                                onClicked: {
                                    root.close();
                                    if (root.clipboardService)
                                        root.clipboardService.captureSnap("region");

                                }
                            }

                            GhostIconButton {
                                glyph: Icons.pin
                                active: root.stayPinnedOpen
                                onClicked: root.stayPinnedOpen = !root.stayPinnedOpen
                            }

                            GhostIconButton {
                                glyph: Icons.clearSweep
                                destructive: true
                                onClicked: {
                                    if (root.clipboardService)
                                        root.clipboardService.clearUnpinned();

                                }
                            }

                            GhostIconButton {
                                glyph: Icons.chevronUp
                                glyphSize: 16
                                onClicked: root.close()
                            }

                        }

                    }

                }

                // Hairline Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.withAlpha(Theme.bright_foreground, 0.07)
                }

                // ─────────────────────────────────────────────────────────────
                // Empty State
                // ─────────────────────────────────────────────────────────────
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.totalCount === 0

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        target: null
                        onWheel: function(event) {
                            var dy = Theme.wheelDeltaY(event);
                            if (dy < 0)
                                root.handleSwipeUpDelta(dy);

                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Icons.clipboard
                            font.family: Icons.effectiveFont(text)
                            font.pixelSize: 26
                            color: Theme.withAlpha(Theme.muted, 0.65)
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.searchQuery.length > 0 ? "No matching entries" : "Clipboard is empty"
                            font.family: Fonts.uiFont
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: Theme.withAlpha(Theme.bright_foreground, 0.82)
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.searchQuery.length > 0 ? "Try another keyword or clear filters" : "Copied text and screenshots appear here"
                            font.family: Fonts.uiFont
                            font.pixelSize: 11
                            color: Theme.muted
                        }

                    }

                }

                // ─────────────────────────────────────────────────────────────
                // Content Area (Screenshots Strip/Grid + Clean History List)
                // ─────────────────────────────────────────────────────────────
                Flickable {
                    id: mainScroll

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.totalCount > 0
                    clip: true
                    contentWidth: width
                    contentHeight: contentColumn.implicitHeight
                    interactive: false
                    boundsBehavior: Flickable.StopAtBounds

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        target: null
                        onWheel: function(event) {
                            var dy = Theme.wheelDeltaY(event);
                            if (dy === 0)
                                return ;

                            var maxY = Math.max(0, mainScroll.contentHeight - mainScroll.height);
                            if (maxY <= 0) {
                                if (dy < 0)
                                    root.handleSwipeUpDelta(dy);

                                return ;
                            }
                            mainScroll.contentY = Math.max(0, Math.min(maxY, mainScroll.contentY - (dy * 0.45)));
                        }
                    }

                    ColumnLayout {
                        id: contentColumn

                        width: mainScroll.width
                        spacing: 14

                        // Section 1: Screenshots
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 7
                            visible: root.imageItems.length > 0

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: "Screenshots"
                                    font.family: Fonts.uiFont
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: Theme.withAlpha(Theme.bright_foreground, 0.68)
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: String(root.imageItems.length)
                                    font.family: Fonts.uiFont
                                    font.pixelSize: 11
                                    color: Theme.muted
                                }

                            }

                            Loader {
                                id: imageLayoutLoader

                                Layout.fillWidth: true
                                Layout.preferredHeight: (root.filterMode === "image") ? Math.max(118, Math.ceil(root.imageItems.length / 4) * 118) : Appearance.clipboardThumbHeight
                                sourceComponent: (root.filterMode === "image") ? imageGridComp : imageStripComp
                            }

                        }

                        // Section 2: Text & Snippet History (Clean Hairline List)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 7
                            visible: root.textItems.length > 0

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: root.filterMode === "pinned" ? "Pinned" : "History"
                                    font.family: Fonts.uiFont
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: Theme.withAlpha(Theme.bright_foreground, 0.68)
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: String(root.textItems.length)
                                    font.family: Fonts.uiFont
                                    font.pixelSize: 11
                                    color: Theme.muted
                                }

                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: textListCol.implicitHeight
                                radius: 10
                                color: Theme.withAlpha(Theme.darker_background, 0.34)
                                border.width: 1
                                border.color: Theme.withAlpha(Theme.bright_foreground, 0.08)
                                clip: true

                                ColumnLayout {
                                    id: textListCol

                                    width: parent.width
                                    spacing: 0

                                    Repeater {
                                        model: root.textItems

                                        delegate: Item {
                                            id: rowRoot

                                            required property var modelData
                                            required property int index
                                            readonly property bool showDivider: index < (root.textItems.length - 1)
                                            readonly property bool isCopiedNow: root.clipboardService && root.clipboardService.copiedFeedbackId === modelData.id

                                            Layout.fillWidth: true
                                            Layout.preferredHeight: Math.max(42, Math.min(62, textPreviewLabel.implicitHeight + 18))

                                            Item {
                                                id: textDragPayload

                                                Drag.active: textDragHandler.active
                                                Drag.dragType: Drag.Automatic
                                                Drag.supportedActions: Qt.CopyAction
                                                Drag.hotSpot: Qt.point(24, 16)
                                                Drag.mimeData: {
                                                    "text/plain": rowRoot.modelData.text || ""
                                                }
                                                Drag.onDragStarted: root.isDragging = true
                                                Drag.onDragFinished: function(dropAction) {
                                                    root.isDragging = false;
                                                    if (dropAction !== Qt.IgnoreAction && !root.stayPinnedOpen)
                                                        root.close();

                                                }
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                color: {
                                                    if (rowRoot.isCopiedNow)
                                                        return Theme.withAlpha(Theme.green, 0.12);

                                                    if (textDragHandler.active)
                                                        return Theme.withAlpha(Theme.accent, 0.14);

                                                    if (rowHover.hovered)
                                                        return Theme.withAlpha(Theme.bright_foreground, 0.055);

                                                    return "transparent";
                                                }

                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: 100
                                                    }

                                                }

                                            }

                                            // Interaction Hitbox Behind Right-Aligned Action Icons
                                            Item {
                                                anchors.fill: parent

                                                HoverHandler {
                                                    id: rowHover
                                                }

                                                DragHandler {
                                                    id: textDragHandler

                                                    target: null
                                                    dragThreshold: 8
                                                }

                                                TapHandler {
                                                    onTapped: root.pasteCard(rowRoot.modelData.id)
                                                }

                                            }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 12
                                                anchors.rightMargin: 10
                                                spacing: 10

                                                // Type Indicator / Color Swatch Dot
                                                Item {
                                                    Layout.preferredWidth: 16
                                                    Layout.preferredHeight: 16
                                                    Layout.alignment: Qt.AlignVCenter

                                                    Rectangle {
                                                        visible: Boolean(rowRoot.modelData.isColor)
                                                        anchors.centerIn: parent
                                                        width: 14
                                                        height: 14
                                                        radius: 7
                                                        color: rowRoot.modelData.colorHex || "transparent"
                                                        border.width: 1
                                                        border.color: Theme.withAlpha(Theme.bright_foreground, 0.28)
                                                    }

                                                    Text {
                                                        visible: !rowRoot.modelData.isColor
                                                        anchors.centerIn: parent
                                                        text: rowRoot.modelData.isUrl ? Icons.linkIcon : (rowRoot.modelData.isCode ? Icons.codeIcon : Icons.textDoc)
                                                        font.family: Icons.effectiveFont(text)
                                                        font.pixelSize: 14
                                                        color: rowHover.hovered ? Theme.accent : Theme.muted
                                                    }

                                                }

                                                // Snippet Content
                                                Text {
                                                    id: textPreviewLabel

                                                    Layout.fillWidth: true
                                                    text: rowRoot.modelData.preview || rowRoot.modelData.text || ""
                                                    font.family: (rowRoot.modelData.isCode || rowRoot.modelData.isColor) ? Fonts.monoFont : Fonts.uiFont
                                                    font.pixelSize: 12
                                                    color: Theme.bright_foreground
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 2
                                                    wrapMode: Text.WrapAnywhere
                                                }

                                                // Right-Aligned Quiet Metadata OR Hover Action Cluster
                                                Item {
                                                    Layout.preferredWidth: Math.max(metaCluster.implicitWidth, hoverActionRow.implicitWidth)
                                                    Layout.preferredHeight: 24
                                                    Layout.alignment: Qt.AlignVCenter
                                                    z: 10

                                                    // Rest State: Multi-line pill, pin mark, relative time
                                                    Row {
                                                        id: metaCluster

                                                        anchors.right: parent.right
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        spacing: 7
                                                        visible: !rowHover.hovered && !rowRoot.isCopiedNow

                                                        Text {
                                                            visible: (rowRoot.modelData.lineCount || 1) > 1
                                                            text: rowRoot.modelData.lineCount + "L"
                                                            font.family: Fonts.monoFont
                                                            font.pixelSize: 10
                                                            color: Theme.withAlpha(Theme.muted, 0.85)
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }

                                                        Text {
                                                            visible: Boolean(rowRoot.modelData.pinned)
                                                            text: Icons.pin
                                                            font.family: Icons.effectiveFont(text)
                                                            font.pixelSize: 11
                                                            color: Theme.accent
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }

                                                        Text {
                                                            text: root.clipboardService ? root.clipboardService.formatRelativeTime(rowRoot.modelData.timestamp) : ""
                                                            font.family: Fonts.uiFont
                                                            font.pixelSize: 11
                                                            color: Theme.muted
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }

                                                    }

                                                    // Copied State
                                                    Text {
                                                        anchors.right: parent.right
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        visible: rowRoot.isCopiedNow
                                                        text: "Copied"
                                                        font.family: Fonts.uiFont
                                                        font.pixelSize: 11
                                                        font.weight: Font.DemiBold
                                                        color: Theme.green
                                                    }

                                                    // Hover State: Quiet Borderless Actions
                                                    Row {
                                                        id: hoverActionRow

                                                        anchors.right: parent.right
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        spacing: 2
                                                        visible: rowHover.hovered && !rowRoot.isCopiedNow

                                                        GhostIconButton {
                                                            glyph: Icons.copy
                                                            buttonSize: 24
                                                            glyphSize: 13
                                                            cornerRadius: 6
                                                            onClicked: root.copyCard(rowRoot.modelData.id)
                                                        }

                                                        GhostIconButton {
                                                            glyph: Icons.pin
                                                            buttonSize: 24
                                                            glyphSize: 13
                                                            cornerRadius: 6
                                                            active: Boolean(rowRoot.modelData.pinned)
                                                            onClicked: {
                                                                if (root.clipboardService)
                                                                    root.clipboardService.togglePin(rowRoot.modelData.id);

                                                            }
                                                        }

                                                        GhostIconButton {
                                                            glyph: Icons.trash
                                                            buttonSize: 24
                                                            glyphSize: 13
                                                            cornerRadius: 6
                                                            destructive: true
                                                            onClicked: {
                                                                if (root.clipboardService)
                                                                    root.clipboardService.deleteItem(rowRoot.modelData.id);

                                                            }
                                                        }

                                                    }

                                                }

                                            }

                                            // Hairline Row Divider
                                            Rectangle {
                                                visible: rowRoot.showDivider
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.leftMargin: 38
                                                anchors.bottom: parent.bottom
                                                height: 1
                                                color: Theme.withAlpha(Theme.bright_foreground, 0.055)
                                            }

                                        }

                                    }

                                }

                            }

                        }

                    }

                }

                // ─────────────────────────────────────────────────────────────
                // Minimal Bottom Handle (Swipe up or click to collapse)
                // ─────────────────────────────────────────────────────────────
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 8

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        target: null
                        onWheel: function(event) {
                            var dy = Theme.wheelDeltaY(event);
                            if (dy < 0)
                                root.handleSwipeUpDelta(dy);

                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: grabMouse.containsMouse ? 40 : 30
                        height: 3
                        radius: 1.5
                        color: grabMouse.containsMouse ? Theme.withAlpha(Theme.bright_foreground, 0.6) : Theme.withAlpha(Theme.bright_foreground, 0.2)

                        Behavior on width {
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
            snapMode: ListView.SnapToItem
            model: root.imageItems

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                target: null
                onWheel: function(event) {
                    var dx = Theme.wheelDeltaX(event);
                    var dy = Theme.wheelDeltaY(event);
                    if (Math.abs(dx) > Math.abs(dy) && dx !== 0) {
                        var maxX = Math.max(0, imgStripList.contentWidth - imgStripList.width);
                        if (maxX > 0) {
                            imgStripList.contentX = Math.max(0, Math.min(maxX, imgStripList.contentX - (dx * 0.45)));
                            return ;
                        }
                    }
                    // Let vertical wheel pass cleanly to mainScroll / drawer dismissal
                    event.accepted = false;
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
            cellHeight: 116
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

    // ─────────────────────────────────────────────────────────────────────────
    // Gallery-Grade Image Thumbnail Delegate (Clean at Rest · HUD on Hover)
    // ─────────────────────────────────────────────────────────────────────────
    component ImageCardDelegate: Item {
        id: imgCard

        required property var modelData
        required property int index
        readonly property bool isCopiedNow: root.clipboardService && root.clipboardService.copiedFeedbackId === modelData.id

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
            radius: 10
            color: Theme.withAlpha(Theme.darker_background, 0.72)
            clip: true
            scale: imgDragHandler.active ? 0.96 : (imgCardHover.hovered ? 1.015 : 1)

            Rectangle {
                id: thumbMask

                anchors.fill: parent
                radius: 10
                color: "black"
                layer.enabled: true
                visible: false
            }

            Image {
                anchors.fill: parent
                source: imgCard.modelData.thumbPath ? ("file://" + imgCard.modelData.thumbPath) : (imgCard.modelData.path ? ("file://" + imgCard.modelData.path) : "")
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
                mipmap: true
                sourceSize: Qt.size(340, 220)
                layer.enabled: true

                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: thumbMask
                }

            }

            // Crisp Topmost Rounded Hairline Frame
            Rectangle {
                anchors.fill: parent
                radius: 10
                color: "transparent"
                border.width: 1
                border.color: imgCard.isCopiedNow ? Theme.green : (imgCardHover.hovered ? Theme.withAlpha(Theme.accent, 0.7) : (imgCard.modelData.pinned ? Theme.withAlpha(Theme.accent, 0.4) : Theme.withAlpha(Theme.bright_foreground, 0.1)))
                z: 20

                Behavior on border.color {
                    ColorAnimation {
                        duration: 120
                    }

                }

            }

            // Body Interaction Layer (Hover, Wayland DnD, Click-to-Paste)
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

            // Quiet Pinned Marker (Visible at rest ONLY if pinned)
            Rectangle {
                visible: Boolean(imgCard.modelData.pinned) && !imgCardHover.hovered
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 6
                width: 18
                height: 18
                radius: 9
                color: Qt.rgba(0, 0, 0, 0.56)

                Text {
                    anchors.centerIn: parent
                    text: Icons.pin
                    font.family: Icons.effectiveFont(text)
                    font.pixelSize: 10
                    color: Theme.accent
                }

            }

            // Hover-Only Top-Right Frosted Floating Action Bar
            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 6
                height: 24
                width: imgActionRow.implicitWidth + 6
                radius: 12
                color: Qt.rgba(16, 18, 22, 0.78)
                border.width: 1
                border.color: Theme.withAlpha(Theme.bright_foreground, 0.14)
                opacity: imgCardHover.hovered ? 1 : 0
                visible: opacity > 0.01
                z: 10

                Row {
                    id: imgActionRow

                    anchors.centerIn: parent
                    spacing: 1

                    GhostIconButton {
                        glyph: Icons.copy
                        buttonSize: 20
                        glyphSize: 11
                        cornerRadius: 10
                        darkSurface: true
                        onClicked: root.copyCard(imgCard.modelData.id)
                    }

                    GhostIconButton {
                        glyph: Icons.editBrush
                        buttonSize: 20
                        glyphSize: 11
                        cornerRadius: 10
                        darkSurface: true
                        onClicked: {
                            if (root.clipboardService)
                                root.clipboardService.annotateImage(imgCard.modelData.path);

                        }
                    }

                    GhostIconButton {
                        glyph: Icons.pin
                        buttonSize: 20
                        glyphSize: 11
                        cornerRadius: 10
                        active: Boolean(imgCard.modelData.pinned)
                        darkSurface: true
                        onClicked: {
                            if (root.clipboardService)
                                root.clipboardService.togglePin(imgCard.modelData.id);

                        }
                    }

                    GhostIconButton {
                        glyph: Icons.trash
                        buttonSize: 20
                        glyphSize: 11
                        cornerRadius: 10
                        destructive: true
                        darkSurface: true
                        onClicked: {
                            if (root.clipboardService)
                                root.clipboardService.deleteItem(imgCard.modelData.id);

                        }
                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
                    }

                }

            }

            // Hover-Only Subtle Bottom Scrim & Technical Caption
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 28
                opacity: imgCardHover.hovered ? 1 : 0
                visible: opacity > 0.01

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 7
                    anchors.rightMargin: 7
                    anchors.bottomMargin: 5
                    text: {
                        var parts = [];
                        if (imgCard.modelData.width > 0)
                            parts.push(imgCard.modelData.width + "×" + imgCard.modelData.height);

                        if (root.clipboardService) {
                            var tm = root.clipboardService.formatRelativeTime(imgCard.modelData.timestamp);
                            var sz = root.clipboardService.formatSize(imgCard.modelData.sizeBytes);
                            if (tm)
                                parts.push(tm);

                            if (sz)
                                parts.push(sz);

                        }
                        return parts.join(" · ");
                    }
                    font.family: Fonts.uiFont
                    font.pixelSize: 10
                    color: Theme.withAlpha(Theme.bright_foreground, 0.9)
                    elide: Text.ElideRight
                }

                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: "transparent"
                    }

                    GradientStop {
                        position: 1
                        color: Qt.rgba(0, 0, 0, 0.72)
                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
                    }

                }

            }

            // Restrained Copied Toast
            Rectangle {
                anchors.centerIn: parent
                height: 24
                width: copiedLabel.implicitWidth + 18
                radius: 12
                color: Qt.rgba(16, 20, 20, 0.86)
                border.width: 1
                border.color: Theme.withAlpha(Theme.green, 0.7)
                visible: imgCard.isCopiedNow
                z: 15

                Text {
                    id: copiedLabel

                    anchors.centerIn: parent
                    text: "Copied"
                    font.family: Fonts.uiFont
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: Theme.green
                }

            }

            Behavior on scale {
                NumberAnimation {
                    duration: 130
                    easing.type: Easing.OutCubic
                }

            }

        }

    }

}
