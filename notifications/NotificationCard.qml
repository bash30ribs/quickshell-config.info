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
            // Strip quickshell icon provider prefix if present
            raw = raw.replace(/^image:\/\/icon\/*/, "/");
            raw = raw.replace(/^file:\/\//, "");
            if (raw.indexOf("/") === 0)
                return raw;

        }
        // Fallback: parse filename from body text and search in ~/Pictures/Screenshot
        var match = root.body ? root.body.match(/Saved to\s+([^\n\r]+)/i) : null;
        if (match && match[1])
            return "/home/ribs/Pictures/Screenshot/" + match[1].trim();

        return "";
    }
    readonly property string screenshotImageUrl: root.screenshotFilePath.length > 0 ? ("file://" + root.screenshotFilePath) : ""
    property var actionList: []

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
    implicitHeight: mainColumn.implicitHeight + 20
    radius: Appearance.notificationRadius > 0 ? Appearance.notificationRadius : 14
    baseColor: Theme.barBackground
    clip: true

    HoverHandler {
        id: hoverTracker
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

    // ── Corner Thread Eyelets (Visible when attached to hanging threads) ──
    // Top-Left Eyelet
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 8
        anchors.leftMargin: 20
        width: 14
        height: 14
        radius: 7
        visible: root.isScreenshot
        color: "transparent"
        border.width: 1.5
        border.color: Theme.withAlpha(Theme.bright_foreground, 0.65)
        z: 30

        Rectangle {
            anchors.centerIn: parent
            width: 6
            height: 6
            radius: 3
            color: Qt.rgba(0, 0, 0, 0.8)
        }

        Rectangle {
            anchors.centerIn: parent
            width: 7
            height: 3
            radius: 1.5
            color: Theme.accent
        }

    }

    // Top-Right Eyelet
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 8
        anchors.rightMargin: 20
        width: 14
        height: 14
        radius: 7
        visible: root.isScreenshot
        color: "transparent"
        border.width: 1.5
        border.color: Theme.withAlpha(Theme.bright_foreground, 0.65)
        z: 30

        Rectangle {
            anchors.centerIn: parent
            width: 6
            height: 6
            radius: 3
            color: Qt.rgba(0, 0, 0, 0.8)
        }

        Rectangle {
            anchors.centerIn: parent
            width: 7
            height: 3
            radius: 1.5
            color: Theme.accent
        }

    }

    ColumnLayout {
        id: mainColumn

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: Appearance.spacingLarge
        anchors.leftMargin: Appearance.spacingLarge + 2
        anchors.rightMargin: Appearance.spacingLarge + 2
        spacing: Appearance.spacingMedium

        // Top Row: App Icon/Glyph, App Name, Close Button
        RowLayout {
            Layout.fillWidth: true
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

        // Summary Title
        Text {
            Layout.fillWidth: true
            visible: root.summary.length > 0
            text: root.summary
            font.family: Fonts.uiFont
            font.pixelSize: Fonts.sizeRegular + 1
            font.weight: Fonts.weightBold
            color: Theme.foreground
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            maximumLineCount: 2
        }

        // Body Text
        Text {
            Layout.fillWidth: true
            visible: root.sanitizedBody.length > 0
            text: root.styledBody
            textFormat: Text.StyledText
            font.family: Fonts.uiFont
            font.pixelSize: Fonts.sizeRegular
            color: Theme.foreground
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            maximumLineCount: 4
        }

        // ── Rich Screenshot Thumbnail Preview ──
        Rectangle {
            id: screenshotPreviewBox

            Layout.fillWidth: true
            Layout.preferredHeight: 136
            radius: 10
            color: Qt.rgba(0, 0, 0, 0.4)
            clip: true
            visible: root.isScreenshot && root.screenshotImageUrl.length > 0
            border.width: 1
            border.color: Theme.withAlpha(Theme.bright_foreground, 0.18)

            Image {
                id: shotThumb

                anchors.fill: parent
                source: root.screenshotImageUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
                mipmap: true
            }

            Rectangle {
                anchors.fill: parent
                color: shotMouseArea.containsMouse ? Theme.withAlpha(Theme.accent, 0.16) : "transparent"
                radius: 10

                Behavior on color {
                    ColorAnimation {
                        duration: 120
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

        }

        // ── Screenshot Quick Action Buttons ──
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            visible: root.isScreenshot
            spacing: 8

            // Open Action
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                radius: 8
                color: openMouse.containsMouse ? Theme.withAlpha(Theme.accent, 0.25) : Theme.withAlpha(Theme.foreground, 0.08)
                border.width: 1
                border.color: Theme.withAlpha(Theme.bright_foreground, 0.15)

                Row {
                    anchors.centerIn: parent
                    spacing: 5

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

            }

            // Annotate Action
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                radius: 8
                color: editMouse.containsMouse ? Theme.withAlpha(Theme.cyan, 0.25) : Theme.withAlpha(Theme.foreground, 0.08)
                border.width: 1
                border.color: Theme.withAlpha(Theme.bright_foreground, 0.15)

                Row {
                    anchors.centerIn: parent
                    spacing: 5

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

            }

            // Copy Action
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                radius: 8
                color: copyMouse.containsMouse ? Theme.withAlpha(Theme.green, 0.25) : Theme.withAlpha(Theme.foreground, 0.08)
                border.width: 1
                border.color: Theme.withAlpha(Theme.bright_foreground, 0.15)

                Row {
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.copy
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: 12
                        color: Theme.bright_foreground
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Copy"
                        font.family: Fonts.uiFont
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: Theme.bright_foreground
                    }

                }

                MouseArea {
                    id: copyMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.screenshotFilePath)
                            Quickshell.execDetached(["sh", "-c", "wl-copy --type image/png < '" + root.screenshotFilePath + "'"]);

                    }
                }

            }

        }

        // Actions Row (if any actions are defined)
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Appearance.spacingSmall
            visible: root.actionList.length > 0
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
