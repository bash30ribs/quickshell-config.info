import "../theme"
import QtQuick

Item {
    id: root

    property real value: 0
    property string label: ""
    property string unit: "%"
    property color accentColor: Theme.accent
    property int gaugeSize: 76
    property int strokeWidth: 5
    property real animatedValue: value

    onAnimatedValueChanged: canvas.requestPaint()
    onAccentColorChanged: canvas.requestPaint()
    implicitWidth: gaugeSize
    implicitHeight: gaugeSize
    width: implicitWidth
    height: implicitHeight

    // Mornye Glass Backing Circle
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.withAlpha(Theme.glassCrest, 0.08)
        border.color: Theme.withAlpha(Theme.glassBorderColor, 0.22)
        border.width: 1

        // Top specular rim arc
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 1
            width: parent.width * 0.65
            height: 1
            color: Theme.withAlpha(Theme.glassRim, 0.3)
        }

    }

    // Canvas arc progress
    Canvas {
        id: canvas

        anchors.fill: parent
        antialiasing: true
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            var centerX = width / 2;
            var centerY = height / 2;
            var radius = (Math.min(width, height) - root.strokeWidth * 2) / 2;
            // 1. Background full track
            ctx.beginPath();
            ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI, false);
            ctx.lineWidth = root.strokeWidth;
            ctx.strokeStyle = Theme.withAlpha(Theme.glassBorderColor, 0.15);
            ctx.lineCap = "round";
            ctx.stroke();
            // 2. Active progress arc
            var fraction = Math.max(0.01, Math.min(1, root.animatedValue / 100));
            var startAngle = -0.5 * Math.PI;
            var endAngle = startAngle + (fraction * 2 * Math.PI);
            ctx.beginPath();
            ctx.arc(centerX, centerY, radius, startAngle, endAngle, false);
            ctx.lineWidth = root.strokeWidth;
            ctx.strokeStyle = root.accentColor;
            ctx.lineCap = "round";
            ctx.stroke();
        }
    }

    // Center Content
    Column {
        anchors.centerIn: parent
        spacing: 1

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Math.round(root.animatedValue) + root.unit
            font.family: Fonts.uiFont
            font.pixelSize: Fonts.scale(12)
            font.weight: Fonts.weightBold
            color: Theme.bright_foreground
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            font.family: Fonts.uiFont
            font.pixelSize: Fonts.scale(9)
            font.weight: Fonts.weightDemiBold
            color: Theme.glassLabel
        }

    }

    Behavior on animatedValue {
        NumberAnimation {
            duration: 450
            easing.type: Easing.OutCubic
        }

    }

}
