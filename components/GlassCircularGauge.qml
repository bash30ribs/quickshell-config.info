import "../theme"
import QtQuick

Item {
    id: root

    property real value: 0
    property real maxValue: 100
    property string label: ""
    property string unit: "%"
    property color accentColor: "#7fbbb3"
    property color gradientEndColor: "#a7c080"
    property int gaugeSize: 86
    property int strokeWidth: 5
    property bool showGlowDot: true
    property real animatedValue: value

    onAnimatedValueChanged: canvas.requestPaint()
    onAccentColorChanged: canvas.requestPaint()
    onGradientEndColorChanged: canvas.requestPaint()
    implicitWidth: gaugeSize
    implicitHeight: gaugeSize
    width: implicitWidth
    height: implicitHeight

    // ── 1. Technical Slate Backing Disc (btop TUI Box) ────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "#1e2326"
        border.color: "#3d484d"
        border.width: 1
        antialiasing: true

        // Inner recessed cavity
        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 6
            height: parent.height - 6
            radius: width / 2
            color: "#232a2e"
            border.color: "#2d353b"
            border.width: 1
            antialiasing: true
        }

    }

    // ── 2. Precision TUI Meter Canvas ─────────────────────────────────────────
    Canvas {
        id: canvas

        anchors.fill: parent
        antialiasing: true
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            var centerX = width / 2;
            var centerY = height / 2;
            var radius = (Math.min(width, height) - root.strokeWidth * 2.6) / 2;
            // Precision btop/TUI scale ticks (24 ticks = 15° intervals)
            var totalTicks = 24;
            for (var i = 0; i < totalTicks; i++) {
                var tickAngle = -0.5 * Math.PI + (i / totalTicks) * 2 * Math.PI;
                var isMajor = (i % 6 === 0);
                var tickIn = radius + root.strokeWidth * 0.95;
                var tickOut = radius + root.strokeWidth * (isMajor ? 1.45 : 1.2);
                ctx.beginPath();
                ctx.moveTo(centerX + tickIn * Math.cos(tickAngle), centerY + tickIn * Math.sin(tickAngle));
                ctx.lineTo(centerX + tickOut * Math.cos(tickAngle), centerY + tickOut * Math.sin(tickAngle));
                ctx.lineWidth = 1;
                ctx.strokeStyle = isMajor ? root.accentColor : "#475258";
                ctx.stroke();
            }
            // Inactive track groove (recessed dark slate track)
            ctx.beginPath();
            ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI, false);
            ctx.lineWidth = root.strokeWidth;
            ctx.strokeStyle = "#2d353b";
            ctx.lineCap = "round";
            ctx.stroke();
            // Progress fraction
            var maxVal = Math.max(1, root.maxValue);
            var fraction = Math.max(0.015, Math.min(1, root.animatedValue / maxVal));
            var startAngle = -0.5 * Math.PI;
            var endAngle = startAngle + (fraction * 2 * Math.PI);
            // Precision gradient
            var grad = ctx.createLinearGradient(0, height, width, 0);
            grad.addColorStop(0, root.accentColor);
            grad.addColorStop(1, root.gradientEndColor);
            // Crisp active laser arc
            ctx.beginPath();
            ctx.arc(centerX, centerY, radius, startAngle, endAngle, false);
            ctx.lineWidth = root.strokeWidth;
            ctx.strokeStyle = grad;
            ctx.lineCap = "round";
            ctx.stroke();
            // Indicator head dot
            if (root.showGlowDot && fraction > 0.02) {
                var dotX = centerX + radius * Math.cos(endAngle);
                var dotY = centerY + radius * Math.sin(endAngle);
                // Small outer ring
                ctx.beginPath();
                ctx.arc(dotX, dotY, root.strokeWidth * 0.7, 0, 2 * Math.PI, false);
                ctx.fillStyle = root.gradientEndColor;
                ctx.fill();
                // Center bright pin
                ctx.beginPath();
                ctx.arc(dotX, dotY, root.strokeWidth * 0.35, 0, 2 * Math.PI, false);
                ctx.fillStyle = "#ffffff";
                ctx.fill();
            }
        }
    }

    // ── 3. Technical Monospace Value & Terminal Bracket Label ────────────────
    Column {
        anchors.centerIn: parent
        spacing: 2

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 1

            Text {
                text: Math.round(root.animatedValue)
                font.family: Fonts.monoFont
                font.pixelSize: Fonts.scale(16)
                font.bold: true
                color: "#d3c6aa"
                anchors.baseline: unitText.baseline
            }

            Text {
                id: unitText

                text: root.unit
                font.family: Fonts.monoFont
                font.pixelSize: Fonts.scale(10)
                font.bold: true
                color: root.accentColor
            }

        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "[" + root.label + "]"
            font.family: Fonts.monoFont
            font.pixelSize: Fonts.scale(8.5)
            font.bold: true
            color: "#9da9a0"
        }

    }

    Behavior on animatedValue {
        NumberAnimation {
            duration: 350
            easing.type: Easing.OutCubic
        }

    }

}
