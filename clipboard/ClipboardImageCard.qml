import "../components"
import "../theme"
import QtQuick
import QtQuick.Effects
import Quickshell

// Editorial liquid-glass screenshot card with hover HUD, click-to-paste, and Wayland drag-and-drop
Item {
    id: imgCard

    required property var modelData
    required property int index
    required property var clipboardService
    property bool stayPinnedOpen: false
    property bool dragTriggered: false
    property bool pendingCloseAfterDrop: false
    property var cachedDragImage: null
    readonly property string imageMimeType: (imgCard.modelData && imgCard.modelData.mime) ? String(imgCard.modelData.mime) : "image/png"
    readonly property string thumbUrl: imgCard.modelData.thumbPath ? ("file://" + imgCard.modelData.thumbPath) : (imgCard.modelData.path ? imgCard.toFileUri(imgCard.modelData.path) : "")
    readonly property bool isCopiedNow: clipboardService && clipboardService.copiedFeedbackId === modelData.id
    readonly property bool isHovered: imgCardHover.hovered || pillMouse.containsMouse || copyBtn.isHovered || editBtn.isHovered || deleteBtn.isHovered || copyBtn.isPressed || editBtn.isPressed || deleteBtn.isPressed

    signal pasteRequested(string itemId)
    signal copyRequested(string itemId)
    signal editRequested(string filePath)
    signal deleteRequested(string itemId)
    signal dragStateChanged(bool dragging)
    signal closeDrawerRequested()

    function toFileUri(filePath) {
        var clean = String(filePath || "");
        if (!clean)
            return "";

        return "file://" + encodeURI(clean).replace(/#/g, "%23").replace(/\?/g, "%3F");
    }

    function refreshCachedImage() {
        var win = imgCard.QsWindow ? imgCard.QsWindow.window : null;
        if (!imgThumb || imgThumb.status !== Image.Ready || imgCard.cachedDragImage || !imgCard.visible || !win || !win.visible)
            return ;

        imgThumb.grabToImage(function(result) {
            if (result && result.image)
                imgCard.cachedDragImage = result.image;

        }, Qt.size(340, 220));
    }

    function buildDragMimeData() {
        var filePath = String(imgCard.modelData.path || "");
        var uri = imgCard.toFileUri(filePath);
        var map = {
        };
        if (uri) {
            map["text/uri-list"] = uri + "\r\n";
            map["x-special/gnome-copied-files"] = "copy\n" + uri;
        }
        if (imgCard.cachedDragImage)
            map[imgCard.imageMimeType] = imgCard.cachedDragImage;

        return map;
    }

    scale: imgCard.dragTriggered ? 0.965 : (imgCard.isHovered ? 1.025 : 1)
    onIsHoveredChanged: {
        if (imgCard.isHovered)
            imgCard.refreshCachedImage();

    }

    HoverHandler {
        id: imgCardHover

        cursorShape: Qt.PointingHandCursor
    }

    Timer {
        id: dragFinishGraceTimer

        interval: 220
        repeat: false
        onTriggered: {
            imgCardFrame.Drag.active = false;
            imgCard.dragTriggered = false;
            imgCard.dragStateChanged(false);
            if (imgCard.pendingCloseAfterDrop) {
                imgCard.pendingCloseAfterDrop = false;
                imgCard.closeDrawerRequested();
            }
        }
    }

    Rectangle {
        id: imgCardFrame

        anchors.fill: parent
        radius: 12
        color: Theme.withAlpha(Theme.darker_background, 0.56)
        clip: true
        Drag.active: false
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction | Qt.LinkAction
        Drag.proposedAction: Qt.CopyAction
        Drag.hotSpot: Qt.point(Math.round(width / 2), Math.round(height / 2))
        Drag.imageSource: imgCard.thumbUrl
        Drag.imageSourceSize: Qt.size(340, 220)
        Drag.onDragStarted: {
            dragFinishGraceTimer.stop();
            imgCard.dragStateChanged(true);
        }
        Drag.onDragFinished: function(dropAction) {
            imgCard.pendingCloseAfterDrop = (dropAction !== Qt.IgnoreAction && !imgCard.stayPinnedOpen);
            dragFinishGraceTimer.restart();
        }

        Rectangle {
            id: thumbMask

            anchors.fill: parent
            radius: 12
            color: "black"
            layer.enabled: true
            visible: false
        }

        Image {
            id: imgThumb

            anchors.fill: parent
            source: imgCard.thumbUrl
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

        // Body Interaction Layer (Wayland DnD with cached PNG + URI payload, Click-to-Paste)
        MouseArea {
            id: cardDragMouse

            property point pressPos: Qt.point(0, 0)

            anchors.fill: parent
            z: 10
            acceptedButtons: Qt.LeftButton
            hoverEnabled: false
            preventStealing: true
            cursorShape: imgCard.dragTriggered ? Qt.ClosedHandCursor : Qt.PointingHandCursor
            onPressed: function(mouse) {
                dragFinishGraceTimer.stop();
                imgCard.refreshCachedImage();
                imgCard.dragTriggered = false;
                imgCard.pendingCloseAfterDrop = false;
                pressPos = Qt.point(mouse.x, mouse.y);
            }
            onPositionChanged: function(mouse) {
                if (imgCard.dragTriggered || !(mouse.buttons & Qt.LeftButton))
                    return ;

                var dx = mouse.x - pressPos.x;
                var dy = mouse.y - pressPos.y;
                if ((dx * dx + dy * dy) < 64)
                    return ;

                imgCard.dragTriggered = true;
                imgCard.dragStateChanged(true);
                imgCardFrame.Drag.mimeData = imgCard.buildDragMimeData();
                imgCardFrame.Drag.active = true;
            }
            onReleased: function() {
                if (!imgCard.dragTriggered)
                    imgCard.pasteRequested(imgCard.modelData.id);

            }
            onCanceled: {
                if (!imgCardFrame.Drag.active && !dragFinishGraceTimer.running) {
                    imgCard.dragTriggered = false;
                    imgCard.dragStateChanged(false);
                }
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
                    onClicked: imgCard.deleteRequested(imgCard.modelData.id)
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
            duration: imgCard.dragTriggered ? 80 : 180
            easing.type: imgCard.dragTriggered ? Easing.OutQuad : Easing.OutBack
            easing.overshoot: imgCard.dragTriggered ? 1 : 1.25
        }

    }

}
