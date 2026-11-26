import "../components"
import "../services"
import "../theme"
import QtQuick
import QtQuick.Dialogs
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
    property int stage: 1 // 1 = Screenshots (ss), 2 = Text, 3 = Files
    property bool searchOpen: false
    property string searchQuery: ""
    property bool newNoteOpen: false
    property real animProgress: 0
    property real openedAtMs: 0
    property real stageChangedAtMs: 0
    property real stageCooldownUntil: 0
    property real gestureUpAccum: 0
    property real stageDownAccum: 0
    property int autoCloseMs: 3500
    property point lastActivityPos: Qt.point(-1, -1)
    readonly property bool searchFocused: searchInput.activeFocus || noteInput.activeFocus
    readonly property var imageItems: root.clipboardService ? root.clipboardService.filteredItems("image", "") : []
    readonly property var textItems: root.clipboardService ? root.clipboardService.filteredItems("text", root.searchQuery) : []
    readonly property var fileItems: root.clipboardService ? root.clipboardService.filteredItems("file", root.searchQuery) : []
    readonly property real targetDrawerHeight: {
        var topMargin = Appearance.clipboardPadding - 1;
        var bottomMargin = 8;
        var headerH = 34;
        if (root.stage === 1) {
            var bodyH = root.imageItems.length > 0 ? (Appearance.clipboardThumbHeight + 8) : 104;
            var trackH = root.imageItems.length > 4 ? 11 : 0;
            var handleH = 14;
            return Math.round(topMargin + headerH + 8 + 1 + 8 + bodyH + trackH + 8 + handleH + bottomMargin);
        }
        var stageChrome = topMargin + headerH + 8 + 1 + 8 + 8 + 14 + bottomMargin;
        if (root.stage === 2) {
            var noteH = root.newNoteOpen ? 46 : 0;
            if (root.textItems.length === 0 && !root.newNoteOpen)
                return 240;

            return Math.max(240, Math.min(Appearance.clipboardHeight, Math.round(stageChrome + textListCol.implicitHeight + noteH + 6)));
        }
        // Stage 3: Files
        if (root.fileItems.length === 0)
            return 240;

        return Math.max(240, Math.min(Appearance.clipboardHeight, Math.round(stageChrome + filesListCol.implicitHeight + 6)));
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
        root.newNoteOpen = false;
        searchInput.text = "";
        searchInput.focus = false;
        noteInput.text = "";
        root.gestureUpAccum = 0;
        root.stageDownAccum = 0;
        root.lastActivityPos = Qt.point(-1, -1);
        if (imgStripList) {
            imgStripList.preservedX = 0;
            imgStripList.contentX = 0;
        }
        root.openedAtMs = now;
        root.stageChangedAtMs = now;
        root.stageCooldownUntil = now + 220;
        root.isVisibleSurface = true;
        root.isOpen = true;
        closeAnim.stop();
        openAnim.restart();
        idleCloseTimer.restart();
    }

    function showScreenshotsStage() {
        if (!root.isOpen)
            root.open();

        if (root.stage === 1) {
            root.touchActivity();
            return ;
        }
        var now = Date.now();
        root.stage = 1;
        root.gestureUpAccum = 0;
        root.stageDownAccum = 0;
        root.stageChangedAtMs = now;
        root.stageCooldownUntil = now + 240;
        stage1FadeAnim.restart();
        root.touchActivity();
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
        root.stageCooldownUntil = now + 240;
        if (textScroll)
            textScroll.contentY = 0;

        stage2FadeAnim.restart();
        root.touchActivity();
    }

    function showFilesStage() {
        if (!root.isOpen)
            root.open();

        if (root.stage === 3) {
            root.touchActivity();
            return ;
        }
        var now = Date.now();
        root.stage = 3;
        root.gestureUpAccum = 0;
        root.stageDownAccum = 0;
        root.stageChangedAtMs = now;
        root.stageCooldownUntil = now + 240;
        if (filesScroll)
            filesScroll.contentY = 0;

        stage3FadeAnim.restart();
        root.touchActivity();
    }

    function stepBackOrClose() {
        if (!root.isOpen)
            return ;

        if (root.stage === 3)
            root.showTextStage();
        else if (root.stage === 2)
            root.showScreenshotsStage();
        else
            root.close();
    }

    function closeAtOnce() {
        root.close();
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

    function toggleNewNote() {
        root.newNoteOpen = !root.newNoteOpen;
        if (root.newNoteOpen) {
            noteInput.forceActiveFocus();
        } else {
            noteInput.text = "";
            noteInput.focus = false;
        }
        root.touchActivity();
    }

    function submitNewNote() {
        var t = noteInput.text.trim();
        if (t.length > 0 && root.clipboardService)
            root.clipboardService.addText(t);

        noteInput.text = "";
        root.newNoteOpen = false;
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
        noteInput.focus = false;
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
        if (now - root.openedAtMs < 200 || now < root.stageCooldownUntil)
            return ;

        if (negDelta < 0) {
            root.stageDownAccum = 0;
            root.gestureUpAccum += negDelta;
            gestureDecayTimer.restart();
            if (root.gestureUpAccum <= -7) {
                root.gestureUpAccum = 0;
                root.stepBackOrClose();
            }
        } else if (negDelta > 5) {
            root.gestureUpAccum = 0;
        }
    }

    function handleStageWheel(event, allowAdvance) {
        var dx = Theme.wheelDeltaX(event);
        var dy = Theme.wheelDeltaY(event);
        if (dx === 0 && dy === 0) {
            event.accepted = false;
            return ;
        }
        var inwardDelta = Appearance.barIsTop ? dy : (Appearance.barIsBottom ? -dy : (Appearance.barIsLeft ? dx : -dx));
        var crossDelta = Appearance.barIsVertical ? dy : dx;
        if (inwardDelta === 0 || Math.abs(inwardDelta) < Math.abs(crossDelta) * 0.65) {
            event.accepted = false;
            return ;
        }
        var now = Date.now();
        if (now < root.stageCooldownUntil) {
            event.accepted = true;
            return ;
        }
        if (inwardDelta > 0 && allowAdvance) {
            if (Math.abs(inwardDelta) >= Math.abs(crossDelta) * 0.85 && (now - root.stageChangedAtMs) >= 200) {
                root.gestureUpAccum = 0;
                root.stageDownAccum += inwardDelta;
                gestureDecayTimer.restart();
                root.touchActivity();
                if (root.stageDownAccum >= 4) {
                    root.stageDownAccum = 0;
                    if (root.stage === 1)
                        root.showTextStage();
                    else if (root.stage === 2)
                        root.showFilesStage();
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
        noteInput.focus = false;
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
        noteInput.focus = false;
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
    WlrLayershell.keyboardFocus: (root.isOpen && (root.stage === 2 || root.stage === 3) && (root.searchOpen || root.searchFocused || root.newNoteOpen)) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
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

    // Spring drop-and-scale reveal from beneath the active docked bar
    NumberAnimation {
        id: openAnim

        target: root
        property: "animProgress"
        to: 1
        duration: 280
        easing.type: Easing.OutBack
        easing.overshoot: 1.08
    }

    NumberAnimation {
        id: closeAnim

        target: root
        property: "animProgress"
        to: 0
        duration: 180
        easing.type: Easing.OutCubic
        onFinished: {
            if (!root.isOpen) {
                root.isVisibleSurface = false;
                root.stage = 1;
                root.searchOpen = false;
                root.searchQuery = "";
                root.newNoteOpen = false;
                searchInput.text = "";
                noteInput.text = "";
            }
        }
    }

    NumberAnimation {
        id: stage1FadeAnim

        target: stage1Container
        property: "opacity"
        from: 0.25
        to: 1
        duration: 150
        easing.type: Easing.OutCubic
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

    NumberAnimation {
        id: stage3FadeAnim

        target: stage3Container
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
        enabled: root.isOpen
        onActivated: {
            if (root.newNoteOpen)
                root.toggleNewNote();
            else if (root.searchQuery.length > 0 || root.searchOpen)
                root.closeSearch();
            else
                root.stepBackOrClose();
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

            if (root.isDragging || root.searchFocused || root.newNoteOpen) {
                idleCloseTimer.restart();
                return ;
            }
            root.close();
        }
    }

    // Native Wayland FileDialog for storing any file into drawer
    FileDialog {
        id: fileDialog

        title: "Select file to store in drawer"
        onAccepted: {
            var raw = selectedFile.toString();
            var path = raw.replace(/^file:\/\//, "");
            path = decodeURIComponent(path);
            if (root.clipboardService)
                root.clipboardService.addFile(path);

            root.touchActivity();
        }
    }

    IpcHandler {
        function open() : string {
            root.open();
            return "opened";
        }

        function showScreenshots() : string {
            root.showScreenshotsStage();
            return "screenshots";
        }

        function showText() : string {
            root.showTextStage();
            return "text";
        }

        function showFiles() : string {
            root.showFilesStage();
            return "files";
        }

        function stepBack() : string {
            root.stepBackOrClose();
            return "ok";
        }

        function closeAtOnce() : string {
            root.closeAtOnce();
            return "closed";
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

        function showScreenshots() : string {
            root.showScreenshotsStage();
            return "screenshots";
        }

        function showText() : string {
            root.showTextStage();
            return "text";
        }

        function showFiles() : string {
            root.showFilesStage();
            return "files";
        }

        function stepBack() : string {
            root.stepBackOrClose();
            return "ok";
        }

        function closeAtOnce() : string {
            root.closeAtOnce();
            return "closed";
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
            x: Appearance.barIsVertical ? (Appearance.barIsRight ? Math.round(clipViewport.width - width - 6 + ((1 - root.animProgress) * 26)) : Math.round(6 - ((1 - root.animProgress) * 26))) : Math.round((clipViewport.width - width) / 2)
            y: Appearance.barIsVertical ? Math.round((clipViewport.height - height) / 2) : (Appearance.barIsBottom ? Math.round(clipViewport.height - height - 6 + ((1 - root.animProgress) * 26)) : Math.round(6 - ((1 - root.animProgress) * 26)))
            radius: Appearance.clipboardRadius
            baseColor: Theme.barBackground
            accentTint: Theme.accent
            clarity: 0.8
            rimIllumination: 0.72
            specularIntensity: 0.9
            transformOrigin: Appearance.barIsBottom ? Item.Bottom : (Appearance.barIsLeft ? Item.Left : (Appearance.barIsRight ? Item.Right : Item.Top))
            opacity: Math.max(0, Math.min(1, root.animProgress * 3.8))
            scale: 0.955 + (0.045 * root.animProgress)

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

            // Fallback wheel gesture handler
            MouseArea {
                anchors.fill: parent
                z: 0
                acceptedButtons: Qt.NoButton
                hoverEnabled: false
                scrollGestureEnabled: true
                onWheel: function(event) {
                    root.handleStageWheel(event, root.stage < 3);
                }
            }

            // Two-finger touch gesture
            DragHandler {
                id: drawerTwoFingerDrag

                acceptedDevices: PointerDevice.TouchScreen
                minimumPointCount: 2
                maximumPointCount: 2
                target: null
                xAxis.enabled: Appearance.barIsVertical
                yAxis.enabled: Appearance.barIsHorizontal
                onTranslationChanged: {
                    if (!root.isOpen || Date.now() < root.stageCooldownUntil)
                        return ;

                    var inward = Appearance.barIsTop ? translation.y : (Appearance.barIsBottom ? -translation.y : (Appearance.barIsLeft ? translation.x : -translation.x));
                    if (inward >= 18) {
                        if (root.stage === 1)
                            root.showTextStage();
                        else if (root.stage === 2)
                            root.showFilesStage();
                    } else if (inward <= -18) {
                        root.stepBackOrClose();
                    }
                }
            }

            // Three-finger swipe up gesture: closes back up at once
            DragHandler {
                id: drawerThreeFingerDrag

                acceptedDevices: PointerDevice.TouchScreen | PointerDevice.TouchPad
                minimumPointCount: 3
                maximumPointCount: 3
                target: null
                xAxis.enabled: Appearance.barIsVertical
                yAxis.enabled: Appearance.barIsHorizontal
                onTranslationChanged: {
                    if (!root.isOpen)
                        return ;

                    var inward = Appearance.barIsTop ? translation.y : (Appearance.barIsBottom ? -translation.y : (Appearance.barIsLeft ? translation.x : -translation.x));
                    if (inward <= -12)
                        root.closeAtOnce();

                }
            }

            // Seamless borderless liquid-glass wash
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
                // UNIFIED TOP NAVIGATION BAR (Segmented Tabs: SS, Text, File)
                // ─────────────────────────────────────────────────────────────
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34

                    MouseArea {
                        anchors.fill: parent
                        z: 50
                        acceptedButtons: Qt.NoButton
                        hoverEnabled: false
                        scrollGestureEnabled: true
                        onWheel: function(event) {
                            root.handleStageWheel(event, root.stage < 3);
                        }
                    }

                    // Left: Unified Segmented Pill Tabs [ 📷 Screenshots | 📄 Text | 📁 Files ]
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        height: 30
                        width: segmentedTabsRow.implicitWidth + 4
                        radius: 15
                        color: Qt.rgba(14, 16, 20, 0.6)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.14)
                        z: 60

                        Row {
                            id: segmentedTabsRow

                            anchors.centerIn: parent
                            spacing: 2

                            // Segment 1: Screenshots (SS)
                            Rectangle {
                                height: 26
                                width: 36
                                radius: 13
                                color: root.stage === 1 ? Theme.withAlpha(Theme.accent, 0.28) : (ssTabMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                                border.width: root.stage === 1 ? 1 : 0
                                border.color: root.stage === 1 ? Theme.withAlpha(Theme.accent, 0.65) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: Icons.camera
                                    font.family: Icons.effectiveFont(text)
                                    font.pixelSize: 13
                                    color: root.stage === 1 ? Theme.accent : (ssTabMouse.containsMouse ? Theme.bright_foreground : Qt.rgba(1, 1, 1, 0.5))
                                }

                                MouseArea {
                                    id: ssTabMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.showScreenshotsStage()
                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }

                                }

                            }

                            // Segment 2: Text
                            Rectangle {
                                height: 26
                                width: 36
                                radius: 13
                                color: root.stage === 2 ? Theme.withAlpha(Theme.accent, 0.28) : (txtTabMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                                border.width: root.stage === 2 ? 1 : 0
                                border.color: root.stage === 2 ? Theme.withAlpha(Theme.accent, 0.65) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: Icons.textDoc
                                    font.family: Icons.effectiveFont(text)
                                    font.pixelSize: 13
                                    color: root.stage === 2 ? Theme.accent : (txtTabMouse.containsMouse ? Theme.bright_foreground : Qt.rgba(1, 1, 1, 0.5))
                                }

                                MouseArea {
                                    id: txtTabMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.showTextStage()
                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }

                                }

                            }

                            // Segment 3: Files
                            Rectangle {
                                height: 26
                                width: 36
                                radius: 13
                                color: root.stage === 3 ? Theme.withAlpha(Theme.accent, 0.28) : (fileTabMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                                border.width: root.stage === 3 ? 1 : 0
                                border.color: root.stage === 3 ? Theme.withAlpha(Theme.accent, 0.65) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: Icons.folder
                                    font.family: Icons.effectiveFont(text)
                                    font.pixelSize: 13
                                    color: root.stage === 3 ? Theme.accent : (fileTabMouse.containsMouse ? Theme.bright_foreground : Qt.rgba(1, 1, 1, 0.5))
                                }

                                MouseArea {
                                    id: fileTabMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.showFilesStage()
                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }

                                }

                            }

                        }

                    }

                    // Right: Context-sensitive Action Buttons (Minimal Icon Controls)
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        z: 60

                        // In Stage 1: Snap button
                        Rectangle {
                            visible: root.stage === 1
                            height: 28
                            width: 28
                            radius: 14
                            color: snapBtnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1
                            border.color: snapBtnMouse.containsMouse ? Theme.withAlpha(Theme.accent, 0.6) : Qt.rgba(1, 1, 1, 0.14)

                            Text {
                                anchors.centerIn: parent
                                text: Icons.camera
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: 13
                                color: Theme.accent
                            }

                            MouseArea {
                                id: snapBtnMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.clipboardService)
                                        root.clipboardService.captureSnap("region");

                                }
                            }

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: 120
                                }

                            }

                        }

                        // In Stage 2: Add Note button
                        Rectangle {
                            visible: root.stage === 2 && !root.searchOpen
                            height: 28
                            width: 28
                            radius: 14
                            color: root.newNoteOpen ? Theme.withAlpha(Theme.accent, 0.3) : (noteBtnMouse.containsMouse ? Theme.withAlpha(Theme.accent, 0.2) : Qt.rgba(1, 1, 1, 0.08))
                            border.width: 1
                            border.color: root.newNoteOpen ? Theme.accent : Qt.rgba(1, 1, 1, 0.2)

                            Text {
                                anchors.centerIn: parent
                                text: root.newNoteOpen ? Icons.close : Icons.editBrush
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: 13
                                color: Theme.accent
                            }

                            MouseArea {
                                id: noteBtnMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleNewNote()
                            }

                        }

                        // In Stage 3: Add File button
                        Rectangle {
                            visible: root.stage === 3 && !root.searchOpen
                            height: 28
                            width: 28
                            radius: 14
                            color: addFileBtnMouse.containsMouse ? Theme.withAlpha(Theme.accent, 0.25) : Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1
                            border.color: addFileBtnMouse.containsMouse ? Theme.withAlpha(Theme.accent, 0.6) : Qt.rgba(1, 1, 1, 0.2)

                            Text {
                                anchors.centerIn: parent
                                text: Icons.fileAdd
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: 14
                                color: Theme.accent
                            }

                            MouseArea {
                                id: addFileBtnMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: fileDialog.open()
                            }

                        }

                        // Search Button (Stages 2 & 3)
                        Rectangle {
                            visible: (root.stage === 2 || root.stage === 3) && !root.searchOpen
                            height: 28
                            width: 28
                            radius: 14
                            color: searchBtnMouse.containsMouse ? Theme.withAlpha(Theme.accent, 0.22) : Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1
                            border.color: searchBtnMouse.containsMouse ? Theme.withAlpha(Theme.accent, 0.55) : Qt.rgba(1, 1, 1, 0.2)

                            Text {
                                anchors.centerIn: parent
                                text: Icons.search
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: 13
                                color: searchBtnMouse.containsMouse ? Theme.accent : Theme.foreground
                            }

                            MouseArea {
                                id: searchBtnMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openSearch()
                            }

                        }

                        // Clear unpinned button
                        GhostIconButton {
                            glyph: Icons.clearSweep
                            buttonSize: 28
                            glyphSize: 14
                            destructive: true
                            onClicked: {
                                if (root.clipboardService)
                                    root.clipboardService.clearUnpinned();

                            }
                        }

                    }

                    // Expandable Search Capsule (shown across stages 2 & 3 when search is open)
                    Rectangle {
                        anchors.fill: parent
                        radius: 16
                        visible: root.searchOpen
                        z: 70
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
                                    text: root.stage === 3 ? "Search stored files..." : "Search copied text..."
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
                                        if (root.stage === 2 && root.textItems && root.textItems.length > 0)
                                            root.pasteCard(root.textItems[0].id);
                                        else if (root.stage === 3 && root.fileItems && root.fileItems.length > 0)
                                            root.pasteCard(root.fileItems[0].id);
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

                // ─────────────────────────────────────────────────────────────
                // STAGE 1: Screenshots Carousel Only
                // ─────────────────────────────────────────────────────────────
                ColumnLayout {
                    id: stage1Container

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8
                    visible: root.stage === 1

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
                                text: "Two-finger glide ↓ for text & files, or click Snap"
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
                                var maxX = Math.max(0, imgStripList.contentWidth - imgStripList.width);
                                var inward = Appearance.barIsTop ? dy : (Appearance.barIsBottom ? -dy : (Appearance.barIsLeft ? dx : -dx));
                                if (Appearance.barIsHorizontal) {
                                    if (maxX > 0 && Math.abs(dx) > Math.abs(dy) * 1.15) {
                                        root.gestureUpAccum = 0;
                                        root.stageDownAccum = 0;
                                        root.touchActivity();
                                        var nextX = Math.max(0, Math.min(maxX, imgStripList.contentX - (dx * 0.65)));
                                        imgStripList.contentX = nextX;
                                        imgStripList.preservedX = nextX;
                                        event.accepted = true;
                                        return ;
                                    }
                                } else {
                                    if (maxX > 0 && Math.abs(dy) > Math.abs(dx) * 1.15) {
                                        root.gestureUpAccum = 0;
                                        root.stageDownAccum = 0;
                                        root.touchActivity();
                                        var nextXV = Math.max(0, Math.min(maxX, imgStripList.contentX - (dy * 0.65)));
                                        imgStripList.contentX = nextXV;
                                        imgStripList.preservedX = nextXV;
                                        event.accepted = true;
                                        return ;
                                    }
                                }
                                // Inward glide -> Stage 2, outward -> Close
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
                            cacheBuffer: 600
                            snapMode: ListView.NoSnap
                            model: (root.isVisibleSurface && root.stage === 1) ? root.imageItems : []
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

                    // Slim Horizontal Strip Progress Bar
                    Item {
                        id: stripProgressTrack

                        readonly property real maxX: Math.max(0, imgStripList.contentWidth - imgStripList.width)
                        readonly property real thumbRatio: imgStripList.contentWidth > 0 ? Math.min(1, imgStripList.width / imgStripList.contentWidth) : 1

                        Layout.fillWidth: true
                        Layout.preferredHeight: 2
                        visible: root.imageItems.length > 4 && maxX > 1

                        Rectangle {
                            anchors.fill: parent
                            radius: 1
                            color: Qt.rgba(1, 1, 1, 0.08)

                            Rectangle {
                                height: parent.height
                                radius: 1
                                width: Math.max(32, parent.width * stripProgressTrack.thumbRatio)
                                x: stripProgressTrack.maxX > 0 ? ((imgStripList.contentX / stripProgressTrack.maxX) * Math.max(0, parent.width - width)) : 0
                                color: Theme.withAlpha(Theme.accent, 0.6)
                            }

                        }

                    }

                }

                // ─────────────────────────────────────────────────────────────
                // STAGE 2: Copied Text History + Note Input
                // ─────────────────────────────────────────────────────────────
                ColumnLayout {
                    id: stage2Container

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8
                    visible: root.stage === 2

                    // Inline New Note Creator Bar (if opened)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: 12
                        visible: root.newNoteOpen
                        color: Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1
                        border.color: Theme.withAlpha(Theme.accent, 0.5)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 8
                            spacing: 8

                            TextInput {
                                id: noteInput

                                Layout.fillWidth: true
                                verticalAlignment: TextInput.AlignVCenter
                                font.family: Fonts.uiFont
                                font.pixelSize: 12
                                color: Theme.bright_foreground
                                selectionColor: Theme.selection
                                clip: true
                                Keys.onReturnPressed: root.submitNewNote()
                                Keys.onEscapePressed: root.toggleNewNote()
                            }

                            GhostIconButton {
                                glyph: Icons.check
                                buttonSize: 26
                                glyphSize: 13
                                active: true
                                onClicked: root.submitNewNote()
                            }

                        }

                    }

                    // Stage 2 Empty State
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: root.textItems.length === 0 && !root.newNoteOpen

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
                                text: root.searchQuery.length > 0 ? "No matching clips" : "No copied text yet"
                                font.family: Fonts.uiFont
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: Theme.bright_foreground
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.searchQuery.length > 0 ? "Try a different keyword" : "Click '+ Note' or copy text in any app to store here"
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
                                var inward = Appearance.barIsTop ? dy : (Appearance.barIsBottom ? -dy : (Appearance.barIsLeft ? dx : -dx));
                                if (maxY > 0 && ((inward > 0 && textScroll.contentY < maxY) || (inward < 0 && textScroll.contentY > 0))) {
                                    textScroll.contentY = Math.max(0, Math.min(maxY, textScroll.contentY - (dy * 0.5)));
                                    root.touchActivity();
                                    event.accepted = true;
                                    return ;
                                }
                                root.handleStageWheel(event, true);
                            }
                        }

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
                                    model: (root.isVisibleSurface && root.stage === 2) ? root.textItems : []

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
                // STAGE 3: Stored Files Shelf
                // ─────────────────────────────────────────────────────────────
                ColumnLayout {
                    id: stage3Container

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8
                    visible: root.stage === 3

                    // Stage 3 Empty State
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: root.fileItems.length === 0

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
                            spacing: 8

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.searchQuery.length > 0 ? "No matching files" : "No files stored yet"
                                font.family: Fonts.uiFont
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: Theme.bright_foreground
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.searchQuery.length > 0 ? "Try a different search term" : "Click '+ Add File' to store any document, code, archive, or media"
                                font.family: Fonts.uiFont
                                font.pixelSize: 11
                                color: Theme.muted
                            }

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                height: 30
                                width: emptyAddFileRow.implicitWidth + 20
                                radius: 15
                                color: emptyAddMouse.containsMouse ? Theme.withAlpha(Theme.accent, 0.3) : Theme.withAlpha(Theme.accent, 0.18)
                                border.width: 1
                                border.color: Theme.accent

                                Row {
                                    id: emptyAddFileRow

                                    anchors.centerIn: parent
                                    spacing: 5

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: Icons.fileAdd
                                        font.family: Icons.effectiveFont(text)
                                        font.pixelSize: 14
                                        color: Theme.accent
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Choose File to Store"
                                        font.family: Fonts.uiFont
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        color: Theme.bright_foreground
                                    }

                                }

                                MouseArea {
                                    id: emptyAddMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: fileDialog.open()
                                }

                            }

                        }

                    }

                    // Stage 3 Scrollable Stored Files List
                    Item {
                        id: filesScrollWrap

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: root.fileItems.length > 0

                        MouseArea {
                            id: filesWheelArea

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
                                var maxY = Math.max(0, filesScroll.contentHeight - filesScroll.height);
                                var inward = Appearance.barIsTop ? dy : (Appearance.barIsBottom ? -dy : (Appearance.barIsLeft ? dx : -dx));
                                if (maxY > 0 && ((inward > 0 && filesScroll.contentY < maxY) || (inward < 0 && filesScroll.contentY > 0))) {
                                    filesScroll.contentY = Math.max(0, Math.min(maxY, filesScroll.contentY - (dy * 0.5)));
                                    root.touchActivity();
                                    event.accepted = true;
                                    return ;
                                }
                                root.handleStageWheel(event, false);
                            }
                        }

                        Rectangle {
                            readonly property real maxY: Math.max(0, filesScroll.contentHeight - filesScroll.height)
                            readonly property real ratio: filesScroll.contentHeight > 0 ? Math.min(1, filesScroll.height / filesScroll.contentHeight) : 1

                            anchors.right: parent.right
                            anchors.rightMargin: -6
                            width: 3
                            radius: 1.5
                            color: Theme.withAlpha(Theme.bright_foreground, 0.28)
                            height: Math.max(24, filesScroll.height * ratio)
                            y: maxY > 0 ? ((filesScroll.contentY / maxY) * Math.max(0, filesScroll.height - height)) : 0
                            visible: maxY > 1
                            z: 110
                        }

                        Flickable {
                            id: filesScroll

                            anchors.fill: parent
                            clip: true
                            contentWidth: width
                            contentHeight: filesListCol.implicitHeight
                            interactive: false
                            boundsBehavior: Flickable.StopAtBounds

                            ColumnLayout {
                                id: filesListCol

                                width: filesScroll.width
                                spacing: 5

                                Repeater {
                                    model: (root.isVisibleSurface && root.stage === 3) ? root.fileItems : []

                                    delegate: ClipboardFileRow {
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
                // Tactile Pill Handle (Swipe up to step back / click to close)
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
                        onClicked: root.stepBackOrClose()
                        onWheel: function(event) {
                            root.handleStageWheel(event, root.stage < 3);
                        }
                    }

                }

            }

            Behavior on height {
                enabled: root.isOpen && !openAnim.running && !closeAnim.running

                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.06
                }

            }

        }

    }

    mask: Region {
        item: drawerSurface
    }

}
