import "../components"
import "../theme"
import QtQuick
import QtQuick.Layouts

// Floating liquid-glass clipboard file row for any stored file
Item {
    id: rowRoot

    required property var modelData
    required property int index
    required property var clipboardService
    property bool stayPinnedOpen: false
    readonly property bool isCopiedNow: clipboardService && clipboardService.copiedFeedbackId === modelData.id
    readonly property bool isHovered: rowHover.hovered || pillMouse.containsMouse || openBtn.isHovered || folderBtn.isHovered || copyBtn.isHovered || deleteBtn.isHovered || openBtn.isPressed || copyBtn.isPressed || deleteBtn.isPressed
    readonly property string extTag: String(modelData.extension || "FILE").toUpperCase()
    readonly property color tagColor: {
        var e = String(modelData.extension || "").toLowerCase();
        if (e === "png" || e === "jpg" || e === "jpeg" || e === "webp" || e === "svg")
            return Theme.cyan;

        if (e === "pdf" || e === "doc" || e === "docx" || e === "txt" || e === "md")
            return Theme.accent;

        if (e === "mp3" || e === "flac" || e === "wav" || e === "ogg" || e === "m4a")
            return Theme.magenta;

        if (e === "mp4" || e === "mkv" || e === "webm" || e === "mov")
            return Theme.red;

        if (e === "zip" || e === "tar" || e === "gz" || e === "7z" || e === "rar")
            return Theme.yellow;

        if (e === "py" || e === "qml" || e === "js" || e === "ts" || e === "sh" || e === "rs" || e === "cpp")
            return Theme.green;

        return Theme.muted;
    }

    signal pasteRequested(string itemId)
    signal copyRequested(string itemId)
    signal deleteRequested(string itemId)
    signal dragStateChanged(bool dragging)
    signal closeDrawerRequested()

    Layout.fillWidth: true
    Layout.preferredHeight: 48
    scale: fileDragHandler.active ? 0.985 : (rowRoot.isHovered ? 1.006 : 1)

    HoverHandler {
        id: rowHover

        cursorShape: Qt.PointingHandCursor
    }

    Item {
        id: fileDragPayload

        Drag.active: fileDragHandler.active
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction
        Drag.hotSpot: Qt.point(24, 16)
        Drag.mimeData: {
            "text/uri-list": "file://" + (rowRoot.modelData.path || "") + "\r\n",
            "text/plain": rowRoot.modelData.path || ""
        }
        Drag.onDragStarted: rowRoot.dragStateChanged(true)
        Drag.onDragFinished: function(dropAction) {
            rowRoot.dragStateChanged(false);
            if (dropAction !== Qt.IgnoreAction && !rowRoot.stayPinnedOpen)
                rowRoot.closeDrawerRequested();

        }
    }

    Rectangle {
        id: cardBg

        anchors.fill: parent
        radius: 11
        color: {
            if (rowRoot.isCopiedNow)
                return Theme.withAlpha(Theme.green, 0.16);

            if (fileDragHandler.active)
                return Theme.withAlpha(Theme.accent, 0.2);

            if (rowRoot.isHovered)
                return Theme.withAlpha(Theme.accent, 0.14);

            return Qt.rgba(1, 1, 1, 0.055);
        }
        border.width: 1
        border.color: {
            if (rowRoot.isCopiedNow)
                return Theme.withAlpha(Theme.green, 0.58);

            if (rowRoot.isHovered)
                return Theme.withAlpha(Theme.accent, 0.38);

            return Qt.rgba(1, 1, 1, 0.1);
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 8
            spacing: 10

            // 1. File Type Icon & Extension Badge
            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 8
                color: Theme.withAlpha(rowRoot.tagColor, 0.16)
                border.width: 1
                border.color: Theme.withAlpha(rowRoot.tagColor, 0.35)

                Text {
                    anchors.centerIn: parent
                    text: Icons.fileIcon(rowRoot.modelData.extension)
                    font.family: Icons.effectiveFont(text)
                    font.pixelSize: 16
                    color: rowRoot.tagColor
                }

            }

            // 2. File Name & Metadata
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        text: rowRoot.modelData.filename || "Unknown file"
                        font.family: Fonts.uiFont
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: Theme.bright_foreground
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    // Extension Tag Pill
                    Rectangle {
                        Layout.preferredHeight: 16
                        Layout.preferredWidth: extLabel.implicitWidth + 8
                        radius: 8
                        color: Theme.withAlpha(rowRoot.tagColor, 0.14)
                        border.width: 1
                        border.color: Theme.withAlpha(rowRoot.tagColor, 0.32)

                        Text {
                            id: extLabel

                            anchors.centerIn: parent
                            text: rowRoot.extTag
                            font.family: Fonts.uiFont
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            color: rowRoot.tagColor
                        }

                    }

                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Text {
                        text: rowRoot.clipboardService ? rowRoot.clipboardService.formatSize(rowRoot.modelData.sizeBytes) : ""
                        font.family: Fonts.uiFont
                        font.pixelSize: 10
                        color: Theme.muted
                    }

                    Text {
                        text: "·"
                        font.family: Fonts.uiFont
                        font.pixelSize: 10
                        color: Theme.muted
                    }

                    Text {
                        text: rowRoot.clipboardService ? rowRoot.clipboardService.formatRelativeTime(rowRoot.modelData.timestamp) : ""
                        font.family: Fonts.uiFont
                        font.pixelSize: 10
                        color: Theme.muted
                    }

                    Text {
                        text: "·"
                        font.family: Fonts.uiFont
                        font.pixelSize: 10
                        color: Theme.muted
                        visible: rowRoot.modelData.path !== undefined
                    }

                    Text {
                        Layout.fillWidth: true
                        text: rowRoot.modelData.path || ""
                        font.family: Fonts.uiFont
                        font.pixelSize: 10
                        color: Theme.withAlpha(Theme.foreground, 0.5)
                        elide: Text.ElideMiddle
                        maximumLineCount: 1
                    }

                }

            }

            // 3. Action Buttons
            Row {
                Layout.alignment: Qt.AlignVCenter
                spacing: 4

                // Open with default app
                GhostIconButton {
                    id: openBtn

                    glyph: Icons.openInNew
                    buttonSize: 26
                    glyphSize: 13
                    onClicked: {
                        if (rowRoot.clipboardService)
                            rowRoot.clipboardService.openFile(rowRoot.modelData.path);

                    }
                }

                // Reveal in Nautilus
                GhostIconButton {
                    id: folderBtn

                    glyph: Icons.folderOpen
                    buttonSize: 26
                    glyphSize: 13
                    onClicked: {
                        if (rowRoot.clipboardService)
                            rowRoot.clipboardService.revealFile(rowRoot.modelData.path);

                    }
                }

                // Copy Path
                GhostIconButton {
                    id: copyBtn

                    glyph: rowRoot.isCopiedNow ? Icons.check : Icons.copy
                    buttonSize: 26
                    glyphSize: 13
                    active: rowRoot.isCopiedNow
                    onClicked: rowRoot.copyRequested(rowRoot.modelData.id)
                }

                // Pin
                GhostIconButton {
                    id: pinBtn

                    glyph: Icons.pin
                    buttonSize: 26
                    glyphSize: 13
                    active: rowRoot.modelData.pinned === true
                    onClicked: {
                        if (rowRoot.clipboardService)
                            rowRoot.clipboardService.togglePin(rowRoot.modelData.id);

                    }
                }

                // Delete
                GhostIconButton {
                    id: deleteBtn

                    glyph: Icons.trash
                    buttonSize: 26
                    glyphSize: 13
                    destructive: true
                    onClicked: rowRoot.deleteRequested(rowRoot.modelData.id)
                }

            }

        }

        MouseArea {
            id: pillMouse

            anchors.fill: parent
            z: -1
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton
            onClicked: rowRoot.pasteRequested(rowRoot.modelData.id)
            onDoubleClicked: {
                if (rowRoot.clipboardService)
                    rowRoot.clipboardService.openFile(rowRoot.modelData.path);

            }
        }

        DragHandler {
            id: fileDragHandler

            target: null
            cursorShape: Qt.DragCopyCursor
            grabPermissions: PointerHandler.CanTakeOverFromItems | PointerHandler.ApprovesTakeOverByAnything
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

}
