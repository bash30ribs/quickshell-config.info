import "../components"
import "../theme"
import "NotificationLogic.js" as NotificationLogic
import QtQuick
import QtQuick.Layouts
import Quickshell

GlassPanel {
    id: root

    property string app: ""
    property string appIcon: ""
    property string summary: ""
    property string body: ""
    property string image: ""
    property string glyph: ""
    property int urgency: 1 // 0=Low, 1=Normal, 2=Critical
    property double timestamp: 0
    property string actionsJson: "[]"
    property real progress: 1 // 1.0 -> 0.0 remaining lifetime
    property bool hasTimeout: true
    property bool isScreenshot: false
    property bool copiedFeedback: false
    property var actionList: []
    readonly property bool hovered: hoverTracker.hovered
    readonly property string smallIconSource: image.length > 0 ? (image.charAt(0) === "/" ? "file://" + image : image) : iconSource(appIcon)
    readonly property bool hasIconSource: smallIconSource.length > 0
    readonly property string sanitizedBody: NotificationLogic.sanitizeBody(body, app, appIcon)
    readonly property string styledBody: NotificationLogic.styledBody(body, app, appIcon)
    readonly property color accentColor: urgency === 2 ? Theme.red : (urgency === 0 ? Theme.muted : Theme.accent)
    readonly property string screenshotFilePath: {
        var raw = "";
        if (root.image && root.image.length > 0)
            raw = root.image;
        else if (root.appIcon && root.appIcon.length > 0)
            raw = root.appIcon;
        if (raw) {
            raw = raw.replace(/^image:\/\/icon\/*/, "/");
            raw = raw.replace(/^file:\/\//, "");
            if (raw.indexOf("/") === 0)
                return raw;

        }
        var match = root.body ? root.body.match(/Saved to\s+([^\n\r]+)/i) : null;
        if (match && match[1]) {
            var fn = match[1].trim();
            if (fn.indexOf("/") === 0)
                return fn;

            return "/home/ribs/Pictures/Screenshot/" + fn;
        }
        var pathMatch = root.body ? root.body.match(/(\/[^\s\n\r"']+\.(png|jpg|jpeg|webp))/i) : null;
        if (pathMatch && pathMatch[1])
            return pathMatch[1];

        return "";
    }
    readonly property string screenshotImageUrl: root.screenshotFilePath.length > 0 ? ("file://" + root.screenshotFilePath) : ""
    readonly property string screenshotFileName: {
        if (!root.screenshotFilePath)
            return "screenshot.png";

        var parts = root.screenshotFilePath.split("/");
        return parts[parts.length - 1] || "screenshot.png";
    }
    readonly property string screenshotMode: {
        var match = root.body ? root.body.match(/Mode:\s*([^\n\r]+)/i) : null;
        if (match && match[1]) {
            var m = match[1].trim();
            return m.charAt(0).toUpperCase() + m.slice(1);
        }
        return "Capture";
    }

    signal closeRequested()
    signal cardClicked()
    signal actionRequested(string actionId)
    signal hoverPosChanged(real relX)
    signal hoverExited()

    function iconSource(icon) {
        var value = String(icon || "").trim();
        if (value.length === 0)
            return "";

        if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0)
            return value;

        if (value.charAt(0) === "/")
            return "file://" + value;

        return Quickshell.iconPath(value, true);
    }

    function updateActionList() {
        try {
            actionList = JSON.parse(actionsJson || "[]");
        } catch (e) {
            actionList = [];
        }
    }

    Component.onCompleted: updateActionList()
    onActionsJsonChanged: updateActionList()
    implicitWidth: Appearance.notificationWidth
    implicitHeight: mainColumn.implicitHeight + (root.isScreenshot ? 34 : 20)
    radius: Appearance.notificationRadius > 0 ? Appearance.notificationRadius : 14
    baseColor: Theme.barBackground
    clip: true

    HoverHandler {
        id: hoverTracker
    }

    Timer {
        id: copyFeedbackTimer

        interval: 2200
        onTriggered: root.copiedFeedback = false
    }

    // Main clickable surface with interactive position tracking
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPositionChanged: function(mouse) {
            root.hoverPosChanged(mouse.x);
        }
        onExited: root.hoverExited()
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton)
                root.closeRequested();
            else
                root.cardClicked();
        }
    }

    // ── Corner Thread Grommets (Precision metallic rim eyelets for hanging strings) ──
    // Top-Left Grommet
    Rectangle {
        x: 28 - 7
        y: 14 - 7
        width: 14
        height: 14
        radius: 7
        visible: root.isScreenshot
        color: Qt.rgba(0.12, 0.14, 0.16, 0.65)
        border.width: 1.2
        border.color: Theme.withAlpha(Theme.bright_foreground, 0.55)
        z: 30

        Rectangle {
            anchors.centerIn: parent
            width: 6
            height: 6
            radius: 3
            color: Qt.rgba(0.04, 0.05, 0.06, 0.95)
            border.width: 0.6
            border.color: Qt.rgba(1, 1, 1, 0.25)
        }

    }

    // Top-Right Grommet
    Rectangle {
        x: parent.width - 28 - 7
        y: 14 - 7
        width: 14
        height: 14
        radius: 7
        visible: root.isScreenshot
        color: Qt.rgba(0.12, 0.14, 0.16, 0.65)
        border.width: 1.2
        border.color: Theme.withAlpha(Theme.bright_foreground, 0.55)
        z: 30

        Rectangle {
            anchors.centerIn: parent
            width: 6
            height: 6
            radius: 3
            color: Qt.rgba(0.04, 0.05, 0.06, 0.95)
            border.width: 0.6
            border.color: Qt.rgba(1, 1, 1, 0.25)
        }

    }

    ColumnLayout {
        id: mainColumn

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: root.isScreenshot ? 22 : Appearance.spacingLarge
        anchors.leftMargin: Appearance.spacingLarge + 2
        anchors.rightMargin: Appearance.spacingLarge + 2
        spacing: Appearance.spacingMedium

        // ── Standard Notification Header (Hidden for screenshots) ──
        RowLayout {
            Layout.fillWidth: true
            visible: !root.isScreenshot
            spacing: Appearance.spacingMedium

            // Icon / Glyph Slot
            Item {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter

                Image {
                    id: iconImg

                    anchors.fill: parent
                    source: root.smallIconSource
                    sourceSize.width: 44
                    sourceSize.height: 44
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    visible: root.hasIconSource && iconImg.status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: !iconImg.visible
                    text: root.glyph.length > 0 ? root.glyph : Icons.bell
                    font.family: Icons.effectiveFont(text)
                    font.pixelSize: Fonts.sizeMedium + 1
                    color: root.accentColor
                }

            }

            // App Name
            Text {
                Layout.fillWidth: true
                text: (root.app.length > 0 ? root.app : "System").toUpperCase()
                font.family: Fonts.uiFont
                font.pixelSize: Fonts.sizeXs + 1
                font.weight: Fonts.weightBold
                color: Theme.muted
                elide: Text.ElideRight
            }

            // Close Button
            Rectangle {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                radius: 10
                color: closeBtnArea.containsMouse ? Theme.lighter_background : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: Icons.close
                    font.family: Icons.effectiveFont(text)
                    font.pixelSize: Fonts.sizeSmall + 1
                    color: closeBtnArea.containsMouse ? Theme.red : Theme.muted
                }

                MouseArea {
                    id: closeBtnArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }

            }

        }

        // ── Screenshot Dedicated Header Row ──
        RowLayout {
            Layout.fillWidth: true
            visible: root.isScreenshot
            spacing: 0

            Item {
                Layout.fillWidth: true
            }

            // Centered Frosted Capsule (Badge + Integrated Close)
            Rectangle {
                Layout.preferredHeight: 26
                Layout.preferredWidth: shotHeaderRow.implicitWidth + 24
                radius: 13
                color: Theme.withAlpha(Theme.foreground, 0.08)
                border.width: 1
                border.color: Theme.withAlpha(Theme.bright_foreground, 0.16)

                Row {
                    id: shotHeaderRow

                    anchors.centerIn: parent
                    spacing: 7

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.camera
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: 11
                        color: Theme.accent
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "SCREENSHOT"
                        font.family: Fonts.uiFont
                        font.pixelSize: 10
                        font.weight: Fonts.weightBold
                        font.letterSpacing: 1.1
                        color: Theme.bright_foreground
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "•"
                        font.family: Fonts.uiFont
                        font.pixelSize: 10
                        color: Theme.muted
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.screenshotMode
                        font.family: Fonts.uiFont
                        font.pixelSize: 10
                        color: Theme.muted
                    }

                    // Divider
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: 12
                        color: Theme.withAlpha(Theme.bright_foreground, 0.16)
                    }

                    // Integrated Dismiss Cross
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        radius: 8
                        color: shotCloseArea.containsMouse ? Theme.withAlpha(Theme.red, 0.25) : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: Icons.close
                            font.family: Icons.effectiveFont(text)
                            font.pixelSize: 10
                            color: shotCloseArea.containsMouse ? Theme.red : Theme.muted
                        }

                        MouseArea {
                            id: shotCloseArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeRequested()
                        }

                    }

                }

            }

            Item {
                Layout.fillWidth: true
            }

        }

        // Standard Summary Title (Hidden for screenshots)
        Text {
            Layout.fillWidth: true
            visible: !root.isScreenshot && root.summary.length > 0
            text: root.summary
            font.family: Fonts.uiFont
            font.pixelSize: Fonts.sizeRegular + 1
            font.weight: Fonts.weightBold
            color: Theme.foreground
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            maximumLineCount: 2
        }

        // Standard Body Text (Hidden for screenshots)
        Text {
            Layout.fillWidth: true
            visible: !root.isScreenshot && root.sanitizedBody.length > 0
            text: root.styledBody
            textFormat: Text.StyledText
            font.family: Fonts.uiFont
            font.pixelSize: Fonts.sizeRegular
            color: Theme.foreground
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            maximumLineCount: 4
        }

        // ── Rich Hero Screenshot Preview Box ──
        Rectangle {
            id: screenshotPreviewBox

            Layout.fillWidth: true
            Layout.preferredHeight: 168
            radius: 11
            color: Qt.rgba(0.06, 0.08, 0.1, 0.7)
            clip: true
            visible: root.isScreenshot
            border.width: 1
            border.color: shotMouseArea.containsMouse ? Theme.withAlpha(Theme.accent, 0.45) : Theme.withAlpha(Theme.bright_foreground, 0.18)

            // Image Thumbnail
            Image {
                id: shotThumb

                anchors.fill: parent
                source: root.screenshotImageUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
                mipmap: true
                visible: root.screenshotImageUrl.length > 0 && shotThumb.status === Image.Ready
                scale: shotMouseArea.containsMouse ? 1.018 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutQuad
                    }

                }

            }

            // Fallback placeholder when image is loading or path unavailable
            Column {
                anchors.centerIn: parent
                spacing: 8
                visible: !shotThumb.visible

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Icons.camera
                    font.family: Icons.effectiveFont(text)
                    font.pixelSize: 32
                    color: Theme.withAlpha(Theme.bright_foreground, 0.35)
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Screenshot Preview"
                    font.family: Fonts.uiFont
                    font.pixelSize: Fonts.sizeSmall
                    color: Theme.muted
                }

            }

            // Subtle dark hover sheen overlay
            Rectangle {
                anchors.fill: parent
                radius: 11
                color: shotMouseArea.containsMouse ? Qt.rgba(0, 0, 0, 0.28) : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: 140
                    }

                }

            }

            // Center Floating "View Fullscreen" Pill
            Rectangle {
                anchors.centerIn: parent
                width: viewPillRow.implicitWidth + 22
                height: 28
                radius: 14
                color: Qt.rgba(0.08, 0.1, 0.12, 0.78)
                border.width: 1
                border.color: Theme.withAlpha(Theme.bright_foreground, 0.3)
                opacity: (shotMouseArea.containsMouse && shotThumb.visible) ? 1 : 0

                Row {
                    id: viewPillRow

                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.openInNew
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: 11
                        color: Theme.bright_foreground
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "View Fullscreen"
                        font.family: Fonts.uiFont
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: Theme.bright_foreground
                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }

                }

            }

            MouseArea {
                id: shotMouseArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.screenshotFilePath)
                        Quickshell.execDetached(["xdg-open", root.screenshotFilePath]);

                }
            }

            Behavior on border.color {
                ColorAnimation {
                    duration: 150
                }

            }

        }

        // ── Screenshot Metadata & Status Row ──
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: -2
            visible: root.isScreenshot
            spacing: 8

            // Filename label
            Row {
                Layout.fillWidth: true
                spacing: 6
                Layout.alignment: Qt.AlignVCenter

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.photo
                    font.family: Icons.effectiveFont(text)
                    font.pixelSize: 11
                    color: Theme.muted
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.screenshotFileName
                    font.family: Fonts.uiFont
                    font.pixelSize: Fonts.sizeXs + 1
                    color: Theme.muted
                    elide: Text.ElideMiddle
                    width: Math.min(implicitWidth, 220)
                }

            }

            // Saved & Copied badge pill
            Rectangle {
                Layout.preferredHeight: 20
                Layout.preferredWidth: savedBadgeRow.implicitWidth + 14
                radius: 10
                color: Theme.withAlpha(Theme.green, 0.12)
                border.width: 1
                border.color: Theme.withAlpha(Theme.green, 0.28)

                Row {
                    id: savedBadgeRow

                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.check
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: 10
                        color: Theme.green
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Saved & Copied"
                        font.family: Fonts.uiFont
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: Theme.green
                    }

                }

            }

        }

        // ── Screenshot Quick Action Buttons Row ──
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            visible: root.isScreenshot
            spacing: 8

            // Open Action Pill
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                radius: 9
                color: openMouse.containsMouse ? Theme.withAlpha(Theme.accent, 0.26) : Theme.withAlpha(Theme.foreground, 0.08)
                border.width: 1
                border.color: openMouse.containsMouse ? Theme.accent : Theme.withAlpha(Theme.bright_foreground, 0.16)

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.openInNew
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: 12
                        color: Theme.bright_foreground
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Open"
                        font.family: Fonts.uiFont
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: Theme.bright_foreground
                    }

                }

                MouseArea {
                    id: openMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.screenshotFilePath)
                            Quickshell.execDetached(["xdg-open", root.screenshotFilePath]);

                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }

                }

            }

            // Annotate Action Pill
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                radius: 9
                color: editMouse.containsMouse ? Theme.withAlpha(Theme.cyan, 0.26) : Theme.withAlpha(Theme.foreground, 0.08)
                border.width: 1
                border.color: editMouse.containsMouse ? Theme.cyan : Theme.withAlpha(Theme.bright_foreground, 0.16)

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.editBrush
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: 12
                        color: Theme.bright_foreground
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Annotate"
                        font.family: Fonts.uiFont
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: Theme.bright_foreground
                    }

                }

                MouseArea {
                    id: editMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.screenshotFilePath) {
                            Quickshell.execDetached(["swappy", "-f", root.screenshotFilePath]);
                            root.closeRequested();
                        }
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }

                }

            }

            // Copy Image Action Pill with Dynamic Confirmation Feedback
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                radius: 9
                color: root.copiedFeedback ? Theme.withAlpha(Theme.green, 0.25) : (copyMouse.containsMouse ? Theme.withAlpha(Theme.green, 0.22) : Theme.withAlpha(Theme.foreground, 0.08))
                border.width: 1
                border.color: root.copiedFeedback ? Theme.green : (copyMouse.containsMouse ? Theme.green : Theme.withAlpha(Theme.bright_foreground, 0.16))

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.copiedFeedback ? Icons.check : Icons.copy
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: 12
                        color: root.copiedFeedback ? Theme.green : Theme.bright_foreground
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.copiedFeedback ? "Copied ✓" : "Copy"
                        font.family: Fonts.uiFont
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: root.copiedFeedback ? Theme.green : Theme.bright_foreground
                    }

                }

                MouseArea {
                    id: copyMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.screenshotFilePath) {
                            Quickshell.execDetached(["sh", "-c", "wl-copy --type image/png < '" + root.screenshotFilePath + "'"]);
                            root.copiedFeedback = true;
                            copyFeedbackTimer.restart();
                        }
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }

                }

            }

        }

        // Standard Actions Row (if any actions are defined)
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Appearance.spacingSmall
            visible: !root.isScreenshot && root.actionList.length > 0
            spacing: Appearance.spacingMedium

            Repeater {
                model: root.actionList

                delegate: Rectangle {
                    required property var modelData

                    Layout.preferredHeight: 26
                    Layout.preferredWidth: actionLabel.implicitWidth + 20
                    radius: Appearance.radiusSmall + 2
                    color: actionMouseArea.containsMouse ? Theme.lighter_background : Theme.selection
                    border.color: Theme.selection
                    border.width: Appearance.borderWidthThin

                    Text {
                        id: actionLabel

                        anchors.centerIn: parent
                        text: modelData.text || modelData.id
                        font.family: Fonts.uiFont
                        font.pixelSize: Fonts.sizeSmall
                        font.weight: Fonts.weightBold
                        color: Theme.foreground
                    }

                    MouseArea {
                        id: actionMouseArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.actionRequested(modelData.id)
                    }

                }

            }

        }

    }

}
