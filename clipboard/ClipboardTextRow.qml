import "../components"
import "../theme"
import QtQuick
import QtQuick.Layouts

// Floating liquid-glass clipboard text/link/code/swatch pill row
Item {
    id: rowRoot

    required property var modelData
    required property int index
    required property var clipboardService
    property bool stayPinnedOpen: false
    readonly property bool isCopiedNow: clipboardService && clipboardService.copiedFeedbackId === modelData.id
    readonly property string badgeTag: {
        if (modelData.isColor)
            return "HEX";

        if (modelData.isUrl)
            return "URL";

        if (modelData.isCode)
            return "CODE";

        if ((modelData.lineCount || 1) > 1)
            return modelData.lineCount + "L";

        return "";
    }
    readonly property color tagColor: {
        if (modelData.isUrl)
            return Theme.cyan;

        if (modelData.isCode)
            return Theme.magenta;

        if (modelData.isColor)
            return Theme.accent;

        return Theme.muted;
    }

    signal pasteRequested(string itemId)
    signal copyRequested(string itemId)
    signal dragStateChanged(bool dragging)
    signal closeDrawerRequested()

    Layout.fillWidth: true
    Layout.preferredHeight: Math.max(38, Math.min(54, textPreviewLabel.implicitHeight + 16))
    scale: textDragHandler.active ? 0.985 : (rowHover.hovered ? 1.006 : 1)

    Item {
        id: textDragPayload

        Drag.active: textDragHandler.active
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction
        Drag.hotSpot: Qt.point(24, 16)
        Drag.mimeData: {
            "text/plain": rowRoot.modelData.text || ""
        }
        Drag.onDragStarted: rowRoot.dragStateChanged(true)
        Drag.onDragFinished: function(dropAction) {
            rowRoot.dragStateChanged(false);
            if (dropAction !== Qt.IgnoreAction && !rowRoot.stayPinnedOpen)
                rowRoot.closeDrawerRequested();

        }
    }

    // Floating Translucent Pill Card Surface (Matches AppLauncher row language)
    Rectangle {
        id: cardBg

        anchors.fill: parent
        radius: 11
        color: {
            if (rowRoot.isCopiedNow)
                return Theme.withAlpha(Theme.green, 0.16);

            if (textDragHandler.active)
                return Theme.withAlpha(Theme.accent, 0.2);

            if (rowHover.hovered)
                return Theme.withAlpha(Theme.accent, 0.13);

            return Qt.rgba(1, 1, 1, 0.035);
        }
        border.width: 1
        border.color: {
            if (rowRoot.isCopiedNow)
                return Theme.withAlpha(Theme.green, 0.58);

            if (rowHover.hovered)
                return Theme.withAlpha(Theme.accent, 0.48);

            return Qt.rgba(1, 1, 1, 0.075);
        }

        Behavior on color {
            ColorAnimation {
                duration: 110
            }

        }

        Behavior on border.color {
            ColorAnimation {
                duration: 110
            }

        }

    }

    // Left Accent Focus Strip on Hover (AppLauncher signature)
    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: 5
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: rowHover.hovered ? 18 : 0
        radius: 1.5
        color: rowRoot.isCopiedNow ? Theme.green : Theme.accent
        visible: height > 0
        opacity: 1

        Behavior on height {
            NumberAnimation {
                duration: 130
                easing.type: Easing.OutCubic
            }

        }

    }

    // Interaction Hitbox Behind Right Action Icons
    Item {
        anchors.fill: parent

        HoverHandler {
            id: rowHover

            cursorShape: Qt.PointingHandCursor
        }

        DragHandler {
            id: textDragHandler

            target: null
            dragThreshold: 8
        }

        TapHandler {
            onTapped: rowRoot.pasteRequested(rowRoot.modelData.id)
        }

    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 13
        anchors.rightMargin: 10
        spacing: 10

        // Squircle Type Badge / Glowing Color Swatch
        Rectangle {
            Layout.preferredWidth: 26
            Layout.preferredHeight: 26
            Layout.alignment: Qt.AlignVCenter
            radius: 8
            color: {
                if (rowRoot.modelData.isColor)
                    return Theme.withAlpha(Theme.darker_background, 0.5);

                if (rowRoot.modelData.isUrl)
                    return Theme.withAlpha(Theme.cyan, 0.14);

                if (rowRoot.modelData.isCode)
                    return Theme.withAlpha(Theme.magenta, 0.14);

                return Theme.withAlpha(Theme.bright_foreground, rowHover.hovered ? 0.11 : 0.06);
            }
            border.width: 1
            border.color: rowHover.hovered ? Theme.withAlpha(rowRoot.tagColor, 0.32) : Theme.withAlpha(Theme.bright_foreground, 0.06)

            Rectangle {
                visible: Boolean(rowRoot.modelData.isColor)
                anchors.centerIn: parent
                width: 14
                height: 14
                radius: 7
                color: rowRoot.modelData.colorHex || "transparent"
                border.width: 1.5
                border.color: Theme.withAlpha(Theme.bright_foreground, 0.55)
            }

            Text {
                visible: !rowRoot.modelData.isColor
                anchors.centerIn: parent
                text: rowRoot.modelData.isUrl ? Icons.linkIcon : (rowRoot.modelData.isCode ? Icons.codeIcon : Icons.textDoc)
                font.family: Icons.effectiveFont(text)
                font.pixelSize: 13
                color: rowRoot.modelData.isUrl ? Theme.cyan : (rowRoot.modelData.isCode ? Theme.magenta : (rowHover.hovered ? Theme.accent : Theme.muted))
            }

        }

        // Snippet Content
        Text {
            id: textPreviewLabel

            Layout.fillWidth: true
            text: rowRoot.modelData.preview || rowRoot.modelData.text || ""
            font.family: (rowRoot.modelData.isCode || rowRoot.modelData.isColor) ? Fonts.monoFont : Fonts.uiFont
            font.pixelSize: 12
            font.weight: rowHover.hovered ? Font.Medium : Font.Normal
            color: rowHover.hovered ? Theme.bright_foreground : Theme.withAlpha(Theme.bright_foreground, 0.9)
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.WrapAnywhere
        }

        // Right-Aligned Semantic Tag + Metadata OR Frosted Hover Actions
        Item {
            Layout.preferredWidth: Math.max(metaCluster.implicitWidth, hoverActionRow.implicitWidth)
            Layout.preferredHeight: 26
            Layout.alignment: Qt.AlignVCenter
            z: 10

            // Rest State: Semantic pill, pin mark, relative time
            Row {
                id: metaCluster

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7
                visible: !rowHover.hovered && !rowRoot.isCopiedNow

                Rectangle {
                    visible: rowRoot.badgeTag.length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    height: 17
                    width: tagText.implicitWidth + 10
                    radius: 5
                    color: Theme.withAlpha(rowRoot.tagColor, 0.14)
                    border.width: 1
                    border.color: Theme.withAlpha(rowRoot.tagColor, 0.25)

                    Text {
                        id: tagText

                        anchors.centerIn: parent
                        text: rowRoot.badgeTag
                        font.family: Fonts.monoFont
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        color: rowRoot.tagColor
                    }

                }

                Text {
                    text: rowRoot.clipboardService ? rowRoot.clipboardService.formatRelativeTime(rowRoot.modelData.timestamp) : ""
                    font.family: Fonts.uiFont
                    font.pixelSize: 11
                    color: Theme.muted
                    anchors.verticalCenter: parent.verticalCenter
                }

            }

            // Copied Confirmation Pill
            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: rowRoot.isCopiedNow
                height: 20
                width: copiedText.implicitWidth + 14
                radius: 10
                color: Theme.withAlpha(Theme.green, 0.16)
                border.width: 1
                border.color: Theme.withAlpha(Theme.green, 0.55)

                Text {
                    id: copiedText

                    anchors.centerIn: parent
                    text: "Copied"
                    font.family: Fonts.uiFont
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: Theme.green
                }

            }

            // Hover State: Frosted Floating Action Pill
            Rectangle {
                id: hoverActionRow

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: rowHover.hovered && !rowRoot.isCopiedNow
                height: 26
                width: actionButtonsRow.implicitWidth + 8
                radius: 13
                color: Theme.withAlpha(Theme.darker_background, 0.62)
                border.width: 1
                border.color: Theme.withAlpha(Theme.bright_foreground, 0.1)

                Row {
                    id: actionButtonsRow

                    anchors.centerIn: parent
                    spacing: 1

                    GhostIconButton {
                        glyph: Icons.copy
                        buttonSize: 22
                        glyphSize: 12
                        cornerRadius: 11
                        onClicked: rowRoot.copyRequested(rowRoot.modelData.id)
                    }

                    GhostIconButton {
                        glyph: Icons.trash
                        buttonSize: 22
                        glyphSize: 12
                        cornerRadius: 11
                        destructive: true
                        onClicked: {
                            if (rowRoot.clipboardService)
                                rowRoot.clipboardService.deleteItem(rowRoot.modelData.id);

                        }
                    }

                }

            }

        }

    }

    Behavior on scale {
        NumberAnimation {
            duration: textDragHandler.active ? 80 : 160
            easing.type: textDragHandler.active ? Easing.OutQuad : Easing.OutBack
            easing.overshoot: textDragHandler.active ? 1 : 1.15
        }

    }

}
