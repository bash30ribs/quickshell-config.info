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

    readonly property string featureName: "clipbar"
    property ClipboardService clipboardService: null
    property bool isOpen: false
    property bool isVisibleSurface: false
    property bool isDragging: false
    property int stage: 1 // 1 = Screenshots strip only, 2 = Copied Text + Search
    property bool searchOpen: false
    property string searchQuery: ""
    property real animProgress: 0
    property real openedAtMs: 0
    property real stageChangedAtMs: 0
    property real stageCooldownUntil: 0
    property real gestureUpAccum: 0
    property real stageDownAccum: 0
    property int autoCloseMs: 5000
    property point lastActivityPos: Qt.point(-1, -1)
    readonly property bool searchFocused: searchInput.activeFocus
    readonly property var imageItems: root.clipboardService ? root.clipboardService.filteredItems("image", "") : []
    readonly property var textItems: root.clipboardService ? root.clipboardService.filteredItems("text", root.searchQuery) : []
    readonly property real targetDrawerHeight: {
        var topMargin = Appearance.clipboardPadding - 1;
        var bottomMargin = 8;
        if (root.stage === 1) {
            var headerH = 26;
            var bodyH = root.imageItems.length > 0 ? (Appearance.clipboardThumbHeight + 8) : 104;
            var trackH = root.imageItems.length > 4 ? 11 : 0;
            var handleH = 14;
            return Math.round(topMargin + headerH + 8 + 1 + 8 + bodyH + trackH + 8 + handleH + bottomMargin);
        }
        var stage2Chrome = topMargin + 32 + 8 + 1 + 8 + 8 + 14 + bottomMargin;
        if (root.textItems.length === 0)
            return 220;

        return Math.max(220, Math.min(Appearance.clipboardHeight, Math.round(stage2Chrome + textListCol.implicitHeight + 6)));
    }

    function touchActivity() {
        if (!root.isOpen)
            return ;

        idleCloseTimer.restart();
    }

    function open() {
        if (root.clipboardService)
            root.clipboardService.syncNow();

        var now = Date.now();
        root.stage = 1;
        root.searchOpen = false;
        root.searchQuery = "";
        searchInput.text = "";
        searchInput.focus = false;
        root.gestureUpAccum = 0;
        root.stageDownAccum = 0;
        root.lastActivityPos = Qt.point(-1, -1);
        if (imgStripList) {
            imgStripList.preservedX = 0;
            imgStripList.contentX = 0;
        }
        root.openedAtMs = now;
        root.stageChangedAtMs = now;
        root.stageCooldownUntil = now + 340;
        root.isVisibleSurface = true;
        root.isOpen = true;
        closeAnim.stop();
        openAnim.restart();
        idleCloseTimer.restart();
    }

    function showTextStage() {
        if (!root.isOpen)
            root.open();

        if (root.stage === 2) {
            root.touchActivity();
            return ;
        }
        var now = Date.now();
        root.stage = 2;
        root.gestureUpAccum = 0;
        root.stageDownAccum = 0;
        root.stageChangedAtMs = now;
        root.stageCooldownUntil = now + 360;
        if (textScroll)
            textScroll.contentY = 0;

        stage2FadeAnim.restart();
        root.touchActivity();
    }

    function openSearch() {
        root.searchOpen = true;
        searchInput.forceActiveFocus();
        root.touchActivity();
    }

    function closeSearch() {
        searchInput.text = "";
        searchInput.focus = false;
        root.searchQuery = "";
        root.searchOpen = false;
        root.touchActivity();
    }

    function close() {
        if (!root.isOpen && !root.isVisibleSurface)
            return ;

        idleCloseTimer.stop();
        root.lastActivityPos = Qt.point(-1, -1);
        root.gestureUpAccum = 0;
        root.stageDownAccum = 0;
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

    function handleSwipeOutwardDelta(negDelta) {
        if (!root.isOpen)
            return ;

        var now = Date.now();
        if (now - root.openedAtMs < 320 || now < root.stageCooldownUntil)
            return ;

        if (negDelta < 0) {
            root.stageDownAccum = 0;
            root.gestureUpAccum += negDelta;
            gestureDecayTimer.restart();
            if (root.gestureUpAccum <= -10) {
                root.gestureUpAccum = 0;
                root.close();
            }
        } else if (negDelta > 6) {
            root.gestureUpAccum = 0;
        }
    }

    function handleStageWheel(event, allowAdvanceToStage2) {
        var dx = Theme.wheelDeltaX(event);
        var dy = Theme.wheelDeltaY(event);
        if (dx === 0 && dy === 0) {
            event.accepted = false;
            return ;
        }
        var inwardDelta = Appearance.barIsTop ? dy : (Appearance.barIsBottom ? -dy : (Appearance.barIsLeft ? dx : -dx));
        var crossDelta = Appearance.barIsVertical ? dy : dx;
        if (inwardDelta === 0 || Math.abs(inwardDelta) < Math.abs(crossDelta) * 0.7) {
            event.accepted = false;
            return ;
        }
        var now = Date.now();
        if (now < root.stageCooldownUntil) {
            event.accepted = true;
            return ;
        }
        if (inwardDelta > 0 && allowAdvanceToStage2 && root.stage === 1) {
            if (Math.abs(inwardDelta) >= Math.abs(crossDelta) * 1.25 && (now - root.stageChangedAtMs) >= 340) {
                root.gestureUpAccum = 0;
                root.stageDownAccum += inwardDelta;
                gestureDecayTimer.restart();
                root.touchActivity();
                if (root.stageDownAccum >= 8) {
                    root.stageDownAccum = 0;
                    root.showTextStage();
                }
            }
            event.accepted = true;
            return ;
        }
        if (inwardDelta < 0) {
            event.accepted = true;
            root.handleSwipeOutwardDelta(inwardDelta);
            return ;
        }
        event.accepted = false;
    }

    function pasteCard(itemId) {
        if (!itemId || !root.clipboardService)
            return ;

        searchInput.focus = false;
        root.close();
        root.clipboardService.pasteItem(itemId);
    }

    function copyCard(itemId) {
        if (!itemId || !root.clipboardService)
            return ;

        root.touchActivity();
        root.clipboardService.copyItem(itemId);
    }

    function editCard(filePath) {
        if (!filePath || !root.clipboardService)
            return ;

        searchInput.focus = false;
        root.close();
        root.clipboardService.annotateImage(filePath);
    }

    function deleteCard(itemId) {
        if (!itemId || !root.clipboardService)
            return ;

        root.touchActivity();
        root.clipboardService.deleteItem(itemId);
    }

    onIsDraggingChanged: {
        if (!root.isDragging && root.isOpen)
            root.touchActivity();

    }
    visible: root.isVisibleSurface
    color: "transparent"
    implicitWidth: Appearance.barIsVertical ? (Appearance.clipboardWidth + 28) : Appearance.clipboardWidth
    implicitHeight: Appearance.barIsVertical ? Appearance.clipboardHeight : (Appearance.clipboardHeight + 28)
    WlrLayershell.namespace: "quickshell-clipbar"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: (root.isOpen && root.stage === 2 && (root.searchOpen || root.searchFocused)) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
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
        top: Appearance.barIsTop
        bottom: Appearance.barIsBottom
        left: Appearance.barIsLeft
        right: Appearance.barIsRight
    }

    margins {
        top: Appearance.barIsTop ? Appearance.barHeight : 0
        bottom: Appearance.barIsBottom ? Appearance.barHeight : 0
        left: Appearance.barIsLeft ? Appearance.barThickness : 0
        right: Appearance.barIsRight ? Appearance.barThickness : 0
    }

    // Crisp slide-and-scale reveal from beneath the top bar
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
                root.stage = 1;
                root.searchOpen = false;
                root.searchQuery = "";
                searchInput.text = "";
            }
        }
    }

    NumberAnimation {
        id: stage2FadeAnim

        target: stage2Container
        property: "opacity"
        from: 0.25
        to: 1
        duration: 150
        easing.type: Easing.OutCubic
    }

    Timer {
        id: gestureDecayTimer

        interval: 220
        repeat: false
        onTriggered: {
            root.gestureUpAccum = 0;
            root.stageDownAccum = 0;
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.isOpen && (root.searchOpen || root.searchFocused)
        onActivated: {
            if (root.searchQuery.length > 0 || root.searchOpen)
                root.closeSearch();
            else
                root.close();
        }
    }

    Connections {
        function onFocusedWorkspaceChanged() {
            if (root.isOpen)
                root.close();

        }

        function onRawEvent(event) {
            if (event && event.name === "activewindowv2" && root.isOpen && !root.isDragging && (Date.now() - root.openedAtMs > 280))
                root.close();

        }

        target: Hyprland
    }

    Timer {
        id: idleCloseTimer

        interval: root.autoCloseMs
        repeat: false
        onTriggered: {
            if (!root.isOpen)
                return ;

            if (root.isDragging) {
                idleCloseTimer.restart();
                return ;
            }
            root.close();
        }
    }

    IpcHandler {
        function open() : string {
            root.open();
            return "opened";
        }

        function showText() : string {
            root.showTextStage();
            return "text";
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

        target: "clipbar"
    }

    IpcHandler {
        function open() : string {
            root.open();
            return "opened";
        }

        function showText() : string {
            root.showTextStage();
            return "text";
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
            x: Appearance.barIsVertical ? (Appearance.barIsRight ? Math.round(clipViewport.width - width - 6 + ((1 - root.animProgress) * 18)) : Math.round(6 - ((1 - root.animProgress) * 18))) : Math.round((clipViewport.width - width) / 2)
            y: Appearance.barIsVertical ? Math.round((clipViewport.height - height) / 2) : (Appearance.barIsBottom ? Math.round(clipViewport.height - height - 6 + ((1 - root.animProgress) * 18)) : Math.round(6 - ((1 - root.animProgress) * 18)))
            radius: Appearance.clipboardRadius
            baseColor: Theme.barBackground
            accentTint: Theme.accent
            clarity: 0.8
            rimIllumination: 0.72
            specularIntensity: 0.9
            transformOrigin: Appearance.barIsBottom ? Item.Bottom : (Appearance.barIsLeft ? Item.Left : (Appearance.barIsRight ? Item.Right : Item.Top))
            opacity: Math.max(0, Math.min(1, root.animProgress * 3.5))
            scale: 0.97 + (0.03 * root.animProgress)

            HoverHandler {
                id: drawerActivityHover

                onPointChanged: {
                    if (!root.isOpen || !drawerActivityHover.hovered)
                        return ;

                    var p = drawerActivityHover.point.position;
                    if (root.lastActivityPos.x < 0 || Math.abs(p.x - root.lastActivityPos.x) > 1.5 || Math.abs(p.y - root.lastActivityPos.y) > 1.5) {
                        root.lastActivityPos = p;
                        root.touchActivity();
                    }
                }
            }

            // Seamless borderless liquid-glass wash (keeps composite alpha >= 0.20 across entire surface)
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: Appearance.clipboardRadius - 1
                border.width: 0
                z: -1

                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Qt.rgba(1, 1, 1, 0.045)
                    }

                    GradientStop {
                        position: 0.45
                        color: Qt.rgba(1, 1, 1, 0.015)
                    }

                    GradientStop {
                        position: 1
                        color: Theme.withAlpha(Theme.accent, 0.035)
                    }

                }

            }

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: Appearance.clipboardPadding
                anchors.rightMargin: Appearance.clipboardPadding
                anchors.topMargin: Appearance.clipboardPadding - 1
                anchors.bottomMargin: 8
                spacing: 8

                // ─────────────────────────────────────────────────────────────
                // STAGE 1: Screenshots Carousel Only
                // ─────────────────────────────────────────────────────────────
                ColumnLayout {
                    id: stage1Container

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8
                    visible: root.stage === 1

                    // Minimal Stage 1 Header (Centered Title Only)
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 26

                        MouseArea {
                            anchors.fill: parent
                            z: 100
                            acceptedButtons: Qt.NoButton
                            hoverEnabled: false
                            scrollGestureEnabled: true
                            onWheel: function(event) {
                                root.handleStageWheel(event, true);
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "Screenshots"
                            font.family: Fonts.uiFont
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: Theme.bright_foreground
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

                    // Stage 1 Empty State
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 104
                        visible: root.imageItems.length === 0

                        MouseArea {
                            anchors.fill: parent
                            z: 100
                            acceptedButtons: Qt.NoButton
                            hoverEnabled: false
                            scrollGestureEnabled: true
                            onWheel: function(event) {
                                root.handleStageWheel(event, true);
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "No screenshots yet"
                                font.family: Fonts.uiFont
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: Theme.bright_foreground
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Two-finger glide ↓ for copied text"
                                font.family: Fonts.uiFont
                                font.pixelSize: 11
                                color: Theme.muted
                            }

                        }

                    }

                    // Horizontal Screenshots Carousel + Gesture Router
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Appearance.clipboardThumbHeight + 8
                        visible: root.imageItems.length > 0

                        MouseArea {
                            id: stage1WheelArea

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
                                // Prioritize horizontal panning across the screenshot strip
                                if (Math.abs(dx) >= Math.abs(dy) * 0.65) {
                                    root.gestureUpAccum = 0;
                                    root.stageDownAccum = 0;
                                    root.touchActivity();
                                    var maxX = Math.max(0, imgStripList.contentWidth - imgStripList.width);
                                    if (maxX > 0) {
                                        var nextX = Math.max(0, Math.min(maxX, imgStripList.contentX - (dx * 0.65)));
                                        imgStripList.contentX = nextX;
                                        imgStripList.preservedX = nextX;
                                    }
                                    event.accepted = true;
                                    return ;
                                }
                                // Vertical two-finger gesture: down -> Stage 2 Text, up -> Close
                                root.handleStageWheel(event, true);
                            }
                        }

                        ListView {
                            id: imgStripList

                            property real preservedX: 0

                            anchors.fill: parent
                            orientation: ListView.Horizontal
                            spacing: 10
                            clip: true
                            interactive: false
                            cacheBuffer: 2400
                            snapMode: ListView.NoSnap
                            model: root.imageItems
                            onModelChanged: {
                                Qt.callLater(function() {
                                    if (!imgStripList || imgStripList.count <= 0)
                                        return ;

                                    var maxX = Math.max(0, imgStripList.contentWidth - imgStripList.width);
                                    imgStripList.contentX = Math.max(0, Math.min(maxX, imgStripList.preservedX));
                                });
                            }

                            delegate: Item {
                                required property var modelData
                                required property int index

                                width: Math.floor((imgStripList.width - 30) / 4)
                                height: imgStripList.height

                                ClipboardImageCard {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    height: Appearance.clipboardThumbHeight
                                    modelData: parent.modelData
                                    index: parent.index
                                    clipboardService: root.clipboardService
                                    onPasteRequested: function(id) {
                                        root.pasteCard(id);
                                    }
                                    onCopyRequested: function(id) {
                                        root.copyCard(id);
                                    }
                                    onEditRequested: function(path) {
                                        root.editCard(path);
                                    }
                                    onDeleteRequested: function(id) {
                                        root.deleteCard(id);
                                    }
                                    onDragStateChanged: function(dragging) {
                                        root.isDragging = dragging;
                                    }
                                    onCloseDrawerRequested: root.close()
                                }

                            }

                        }

                    }

                    // Slim Horizontal Strip Progress Bar when more screenshots exist off-screen
                    Item {
                        id: stripProgressTrack

                        readonly property real maxX: Math.max(0, imgStripList.contentWidth - imgStripList.width)
                        readonly property real thumbRatio: imgStripList.contentWidth > 0 ? Math.min(1, imgStripList.width / imgStripList.contentWidth) : 1

                        Layout.fillWidth: true
                        Layout.preferredHeight: 3
                        visible: root.imageItems.length > 4 && maxX > 1

                        Rectangle {
                            anchors.fill: parent
                            radius: 1.5
                            color: Theme.withAlpha(Theme.bright_foreground, 0.08)

                            Rectangle {
                                height: parent.height
                                radius: 1.5
                                width: Math.max(32, parent.width * stripProgressTrack.thumbRatio)
                                x: stripProgressTrack.maxX > 0 ? ((imgStripList.contentX / stripProgressTrack.maxX) * Math.max(0, parent.width - width)) : 0
                                color: Theme.withAlpha(Theme.accent, 0.78)
                            }

                        }

                    }

                }

                // ─────────────────────────────────────────────────────────────
                // STAGE 2: Copied Text History + Expandable Search Option
                // ─────────────────────────────────────────────────────────────
                ColumnLayout {
                    id: stage2Container

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8
                    visible: root.stage === 2

                    // Stage 2 Header (Centered Title + Search Pill in Right Corner)
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32

                        MouseArea {
                            anchors.fill: parent
                            z: 100
                            acceptedButtons: Qt.NoButton
                            hoverEnabled: false
                            scrollGestureEnabled: true
                            onWheel: function(event) {
                                root.handleStageWheel(event, false);
                            }
                        }

                        // Centered Title (hidden when search bar expands)
                        Text {
                            anchors.centerIn: parent
                            visible: !root.searchOpen
                            text: "Copied Text"
                            font.family: Fonts.uiFont
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: Theme.bright_foreground
                        }

                        // Stage 2 Search Button Pill in Right Corner
                        Rectangle {
                            visible: !root.searchOpen
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: 28
                            width: searchBtnRow.implicitWidth + 18
                            radius: 14
                            color: searchBtnMouse.containsMouse ? Theme.withAlpha(Theme.accent, 0.22) : Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1
                            border.color: searchBtnMouse.containsMouse ? Theme.withAlpha(Theme.accent, 0.55) : Qt.rgba(1, 1, 1, 0.2)

                            Row {
                                id: searchBtnRow

                                anchors.centerIn: parent
                                spacing: 5

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Icons.search
                                    font.family: Icons.effectiveFont(text)
                                    font.pixelSize: 13
                                    color: searchBtnMouse.containsMouse ? Theme.accent : Theme.foreground
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Search"
                                    font.family: Fonts.uiFont
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    color: searchBtnMouse.containsMouse ? Theme.accent : Theme.foreground
                                }

                            }

                            MouseArea {
                                id: searchBtnMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openSearch()
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

                        // Expandable Search Capsule (only shown when Search button is toggled)
                        Rectangle {
                            anchors.fill: parent
                            radius: 16
                            visible: root.searchOpen
                            color: Qt.rgba(1, 1, 1, searchInput.activeFocus ? 0.11 : 0.075)
                            border.width: 1
                            border.color: searchInput.activeFocus ? Theme.withAlpha(Theme.accent, 0.6) : Qt.rgba(1, 1, 1, 0.22)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 8
                                spacing: 8

                                Text {
                                    text: Icons.search
                                    font.family: Icons.effectiveFont(text)
                                    font.pixelSize: 14
                                    color: searchInput.activeFocus ? Theme.accent : Theme.muted
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    Text {
                                        anchors.fill: parent
                                        verticalAlignment: Text.AlignVCenter
                                        text: "Search copied text..."
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
                                        onTextChanged: {
                                            root.searchQuery = text;
                                            root.touchActivity();
                                        }
                                        Keys.onPressed: root.touchActivity()
                                        Keys.onReturnPressed: {
                                            if (root.textItems && root.textItems.length > 0)
                                                root.pasteCard(root.textItems[0].id);

                                        }
                                        Keys.onEscapePressed: root.closeSearch()
                                    }

                                }

                                GhostIconButton {
                                    glyph: Icons.close
                                    buttonSize: 22
                                    glyphSize: 12
                                    cornerRadius: 11
                                    onClicked: root.closeSearch()
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

                    // Stage 2 Empty State
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: root.textItems.length === 0

                        MouseArea {
                            anchors.fill: parent
                            z: 100
                            acceptedButtons: Qt.NoButton
                            hoverEnabled: false
                            scrollGestureEnabled: true
                            onWheel: function(event) {
                                root.handleStageWheel(event, false);
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.searchQuery.length > 0 ? "No matching clips" : "No copied text yet"
                                font.family: Fonts.uiFont
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: Theme.bright_foreground
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.searchQuery.length > 0 ? "Try a different keyword" : "Copied text, links, code, and colors appear here"
                                font.family: Fonts.uiFont
                                font.pixelSize: 11
                                color: Theme.muted
                            }

                        }

                    }

                    // Stage 2 Scrollable Text History List
                    Item {
                        id: textScrollWrap

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: root.textItems.length > 0

                        MouseArea {
                            id: textWheelArea

                            anchors.fill: parent
                            z: 100
                            acceptedButtons: Qt.NoButton
                            hoverEnabled: false
                            scrollGestureEnabled: true
                            onWheel: function(event) {
                                var dx = Theme.wheelDeltaX(event);
                                var dy = Theme.wheelDeltaY(event);
                                if (dy === 0 || Math.abs(dy) < Math.abs(dx) * 0.5) {
                                    event.accepted = false;
                                    return ;
                                }
                                var maxY = Math.max(0, textScroll.contentHeight - textScroll.height);
                                if (maxY > 0)
                                    textScroll.contentY = Math.max(0, Math.min(maxY, textScroll.contentY - (dy * 0.5)));

                                root.touchActivity();
                                event.accepted = true;
                            }
                        }

                        // Vertical scroll thumb when copied text list overflows
                        Rectangle {
                            readonly property real maxY: Math.max(0, textScroll.contentHeight - textScroll.height)
                            readonly property real ratio: textScroll.contentHeight > 0 ? Math.min(1, textScroll.height / textScroll.contentHeight) : 1

                            anchors.right: parent.right
                            anchors.rightMargin: -6
                            width: 3
                            radius: 1.5
                            color: Theme.withAlpha(Theme.bright_foreground, 0.28)
                            height: Math.max(24, textScroll.height * ratio)
                            y: maxY > 0 ? ((textScroll.contentY / maxY) * Math.max(0, textScroll.height - height)) : 0
                            visible: maxY > 1
                            z: 110
                        }

                        Flickable {
                            id: textScroll

                            anchors.fill: parent
                            clip: true
                            contentWidth: width
                            contentHeight: textListCol.implicitHeight
                            interactive: false
                            boundsBehavior: Flickable.StopAtBounds

                            ColumnLayout {
                                id: textListCol

                                width: textScroll.width
                                spacing: 5

                                Repeater {
                                    model: root.textItems

                                    delegate: ClipboardTextRow {
                                        clipboardService: root.clipboardService
                                        onPasteRequested: function(id) {
                                            root.pasteCard(id);
                                        }
                                        onCopyRequested: function(id) {
                                            root.copyCard(id);
                                        }
                                        onDeleteRequested: function(id) {
                                            root.deleteCard(id);
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

                // ─────────────────────────────────────────────────────────────
                // Tactile Pill Handle (Two-finger swipe up or click to close)
                // ─────────────────────────────────────────────────────────────
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 14

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
                            root.handleStageWheel(event, true);
                        }
                    }

                }

            }

            Behavior on height {
                enabled: root.isOpen && !openAnim.running && !closeAnim.running

                NumberAnimation {
                    duration: 165
                    easing.type: Easing.OutCubic
                }

            }

        }

    }

    mask: Region {
        item: drawerSurface
    }

}
