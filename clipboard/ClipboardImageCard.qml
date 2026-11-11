import "../components"
import "../theme"
import QtQuick
import QtQuick.Effects

// Editorial liquid-glass screenshot card with hover HUD, click-to-paste, and Wayland drag-and-drop
Item {
    id: imgCard

    required property var modelData
    required property int index
    required property var clipboardService
    property bool stayPinnedOpen: false
    readonly property bool isCopiedNow: clipboardService && clipboardService.copiedFeedbackId === modelData.id
    readonly property bool isHovered: imgCardHover.hovered || pillMouse.containsMouse || copyBtn.isHovered || editBtn.isHovered || deleteBtn.isHovered || copyBtn.isPressed || editBtn.isPressed || deleteBtn.isPressed

    signal pasteRequested(string itemId)
    signal copyRequested(string itemId)
    signal editRequested(string filePath)
    signal dragStateChanged(bool dragging)
    signal closeDrawerRequested()

    scale: imgDragHandler.active ? 0.965 : (imgCard.isHovered ? 1.025 : 1)

    HoverHandler {
        id: imgCardHover

        cursorShape: Qt.PointingHandCursor
    }

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
        Drag.onDragStarted: imgCard.dragStateChanged(true)
        Drag.onDragFinished: function(dropAction) {
            imgCard.dragStateChanged(false);
            if (dropAction !== Qt.IgnoreAction && !imgCard.stayPinnedOpen)
                imgCard.closeDrawerRequested();

        }
    }

    Rectangle {
        id: imgCardFrame

        anchors.fill: parent
        radius: 12
        color: Theme.withAlpha(Theme.darker_background, 0.56)
        clip: true

        Rectangle {
            id: thumbMask

            anchors.fill: parent
            radius: 12
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

        // Subtle top glass rim sheen inside thumbnail
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 1
            height: 20
            topLeftRadius: 11
            topRightRadius: 11
            z: 5

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.rgba(1, 1, 1, 0.1)
                }

                GradientStop {
                    position: 1
                    color: "transparent"
                }

            }

        }

        // Crisp outermost rounded glass border
        Rectangle {
            anchors.fill: parent
            radius: 12
            color: "transparent"
            border.width: imgCard.isHovered || imgCard.isCopiedNow ? 1.5 : 1
            border.color: {
                if (imgCard.isCopiedNow)
                    return Theme.green;

                if (imgCard.isHovered)
                    return Theme.withAlpha(Theme.accent, 0.82);

                return Qt.rgba(1, 1, 1, 0.18);
            }
            z: 20

            Behavior on border.color {
                ColorAnimation {
                    duration: 120
                }

            }

        }

        // Body Interaction Layer (Wayland DnD, Click-to-Paste)
        Item {
            anchors.fill: parent
            z: 10

            DragHandler {
                id: imgDragHandler

                target: null
                dragThreshold: 8
            }

            TapHandler {
                onTapped: imgCard.pasteRequested(imgCard.modelData.id)
            }

        }

        // Hover Top-Right Frosted Floating Action Pill (isolated from body tap/drag)
        Rectangle {
            id: imgActionPill

            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 6
            height: 26
            width: imgActionRow.implicitWidth + 6
            radius: 13
            color: Qt.rgba(14, 16, 20, 0.84)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.2)
            opacity: imgCard.isHovered ? 1 : 0
            visible: opacity > 0.01
            z: 25

            MouseArea {
                id: pillMouse

                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
                acceptedButtons: Qt.LeftButton
            }

            Row {
                id: imgActionRow

                anchors.centerIn: parent
                spacing: 1

                GhostIconButton {
                    id: copyBtn

                    glyph: Icons.copy
                    buttonSize: 22
                    glyphSize: 12
                    cornerRadius: 11
                    darkSurface: true
                    onClicked: imgCard.copyRequested(imgCard.modelData.id)
                }

                GhostIconButton {
                    id: editBtn

                    glyph: Icons.editBrush
                    buttonSize: 22
                    glyphSize: 12
                    cornerRadius: 11
                    darkSurface: true
                    onClicked: imgCard.editRequested(imgCard.modelData.path)
                }

                GhostIconButton {
                    id: deleteBtn

                    glyph: Icons.trash
                    buttonSize: 22
                    glyphSize: 12
                    cornerRadius: 11
                    destructive: true
                    darkSurface: true
                    onClicked: {
                        if (imgCard.clipboardService)
                            imgCard.clipboardService.deleteItem(imgCard.modelData.id);

                    }
                }

            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                }

            }

        }

        // Hover Bottom Frosted Scrim & Dimension/Age Caption
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 30
            opacity: imgCard.isHovered ? 1 : 0
            visible: opacity > 0.01
            z: 10

            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.bottomMargin: 5
                text: {
                    var parts = [];
                    if (imgCard.modelData.width > 0)
                        parts.push(imgCard.modelData.width + "×" + imgCard.modelData.height);

                    if (imgCard.clipboardService) {
                        var tm = imgCard.clipboardService.formatRelativeTime(imgCard.modelData.timestamp);
                        var sz = imgCard.clipboardService.formatSize(imgCard.modelData.sizeBytes);
                        if (tm)
                            parts.push(tm);

                        if (sz)
                            parts.push(sz);

                    }
                    return parts.join(" · ");
                }
                font.family: Fonts.uiFont
                font.pixelSize: 10
                font.weight: Font.Medium
                color: Theme.withAlpha(Theme.bright_foreground, 0.92)
                elide: Text.ElideRight
            }

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "transparent"
                }

                GradientStop {
                    position: 1
                    color: Qt.rgba(8, 10, 14, 0.82)
                }

            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                }

            }

        }

        // Crisp Copied Pill Toast
        Rectangle {
            anchors.centerIn: parent
            height: 24
            width: copiedLabel.implicitWidth + 18
            radius: 12
            color: Qt.rgba(14, 18, 16, 0.9)
            border.width: 1
            border.color: Theme.withAlpha(Theme.green, 0.78)
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

    }

    Behavior on scale {
        NumberAnimation {
            duration: imgDragHandler.active ? 80 : 180
            easing.type: imgDragHandler.active ? Easing.OutQuad : Easing.OutBack
            easing.overshoot: imgDragHandler.active ? 1 : 1.25
        }

    }

}
