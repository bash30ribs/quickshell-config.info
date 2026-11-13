import "../theme"
import QtQuick

Item {
    id: root

    property real value: 0
    property real maxValue: 100
    property string label: ""
    property string unit: "%"
    property color accentColor: "#00F0FF"
    property color gradientEndColor: "#B026FF"
    property int gaugeSize: 92
    property int strokeWidth: 7
    property bool showGlowDot: true
    property real animatedValue: value

    onAnimatedValueChanged: canvas.requestPaint()
    onAccentColorChanged: canvas.requestPaint()
    onGradientEndColorChanged: canvas.requestPaint()
    implicitWidth: gaugeSize
    implicitHeight: gaugeSize
    width: implicitWidth
    height: implicitHeight

    // ── 1. Ambient Optical Halo Glow ──────────────────────────────────────────
    Rectangle {
        anchors.centerIn: parent
        width: parent.width * 0.94
        height: parent.height * 0.94
        radius: width / 2
        color: Theme.withAlpha(root.accentColor, 0.1 + Math.min(0.2, (root.animatedValue / root.maxValue) * 0.16))
        antialiasing: true
        scale: 0.96 + (root.animatedValue / root.maxValue) * 0.08

        Behavior on color {
            ColorAnimation {
                duration: 350
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: 450
                easing.type: Easing.OutCubic
            }

        }

    }

    // ── 2. Deep Obsidian Glass Disc with Dual Inner Rims ──────────────────────
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.withAlpha("#0A0E17", 0.88)
        border.color: Theme.withAlpha(root.accentColor, 0.4)
        border.width: 1.2
        antialiasing: true

        // Concentric subtle inner rim highlight
        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 4
            height: parent.height - 4
            radius: width / 2
            color: "transparent"
            border.color: Theme.withAlpha("#FFFFFF", 0.09)
            border.width: 1
            antialiasing: true
        }

        // Center ambient depth circle
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.62
            height: parent.height * 0.62
            radius: width / 2
            color: Theme.withAlpha(root.accentColor, 0.06 + Math.min(0.12, (root.animatedValue / root.maxValue) * 0.1))
            antialiasing: true

            Behavior on color {
                ColorAnimation {
                    duration: 350
                }

            }

        }

    }

    // ── 3. High-Precision Laser Arc Canvas with Chrono Ticks ─────────────────
    Canvas {
        id: canvas

        anchors.fill: parent
        antialiasing: true
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            var centerX = width / 2;
            var centerY = height / 2;
            var radius = (Math.min(width, height) - root.strokeWidth * 2.3) / 2;
            // Precision outer telemetry ticks (24 ticks = 15° intervals)
            var totalTicks = 24;
            for (var i = 0; i < totalTicks; i++) {
                var tickAngle = -0.5 * Math.PI + (i / totalTicks) * 2 * Math.PI;
                var isMajor = (i % 6 === 0);
                var tickIn = radius + root.strokeWidth * 0.9;
                var tickOut = radius + root.strokeWidth * (isMajor ? 1.25 : 1.12);
                ctx.beginPath();
                ctx.moveTo(centerX + tickIn * Math.cos(tickAngle), centerY + tickIn * Math.sin(tickAngle));
                ctx.lineTo(centerX + tickOut * Math.cos(tickAngle), centerY + tickOut * Math.sin(tickAngle));
                ctx.lineWidth = isMajor ? 1.5 : 1;
                ctx.strokeStyle = isMajor ? Theme.withAlpha(root.accentColor, 0.5) : Theme.withAlpha("#FFFFFF", 0.12);
                ctx.stroke();
            }
            // Inactive track groove with soft colored tint
            ctx.beginPath();
            ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI, false);
            ctx.lineWidth = root.strokeWidth;
            ctx.strokeStyle = Theme.withAlpha(root.accentColor, 0.14);
            ctx.lineCap = "round";
            ctx.stroke();
            // Progress fraction
            var maxVal = Math.max(1, root.maxValue);
            var fraction = Math.max(0.015, Math.min(1, root.animatedValue / maxVal));
            var startAngle = -0.5 * Math.PI;
            var endAngle = startAngle + (fraction * 2 * Math.PI);
            // Diagonal high-vibrancy gradient
            var grad = ctx.createLinearGradient(0, height, width, 0);
            grad.addColorStop(0, root.accentColor);
            grad.addColorStop(1, root.gradientEndColor);
            // Neon bloom underglow
            if (fraction > 0.02) {
                ctx.beginPath();
                ctx.arc(centerX, centerY, radius, startAngle, endAngle, false);
                ctx.lineWidth = root.strokeWidth + 4;
                ctx.strokeStyle = Theme.withAlpha(root.accentColor, 0.28);
                ctx.lineCap = "round";
                ctx.stroke();
            }
            // Crisp active laser arc
            ctx.beginPath();
            ctx.arc(centerX, centerY, radius, startAngle, endAngle, false);
            ctx.lineWidth = root.strokeWidth;
            ctx.strokeStyle = grad;
            ctx.lineCap = "round";
            ctx.stroke();
            // High-intensity glowing indicator head dot
            if (root.showGlowDot && fraction > 0.025) {
                var dotX = centerX + radius * Math.cos(endAngle);
                var dotY = centerY + radius * Math.sin(endAngle);
                // Ethereal outer bloom halo
                ctx.beginPath();
                ctx.arc(dotX, dotY, root.strokeWidth * 1.3, 0, 2 * Math.PI, false);
                ctx.fillStyle = Theme.withAlpha(root.gradientEndColor, 0.5);
                ctx.fill();
                // Crisp bright ring
                ctx.beginPath();
                ctx.arc(dotX, dotY, root.strokeWidth * 0.72, 0, 2 * Math.PI, false);
                ctx.strokeStyle = "#FFFFFF";
                ctx.lineWidth = 1.5;
                ctx.stroke();
                // Brilliant core
                ctx.beginPath();
                ctx.arc(dotX, dotY, root.strokeWidth * 0.38, 0, 2 * Math.PI, false);
                ctx.fillStyle = "#FFFFFF";
                ctx.fill();
            }
        }
    }

    // ── 4. Center Micro-Typography with Illuminated Badge ─────────────────────
    Column {
        anchors.centerIn: parent
        spacing: 3

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2

            Text {
                text: Math.round(root.animatedValue)
                font.family: Fonts.monoFont
                font.pixelSize: Fonts.scale(18)
                font.bold: true
                color: "#FFFFFF"
                anchors.baseline: unitText.baseline
            }

            Text {
                id: unitText

                text: root.unit
                font.family: Fonts.uiFont
                font.pixelSize: Fonts.scale(11)
                font.bold: true
                color: root.accentColor
            }

        }

        // Illuminated Category Capsule
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: labelText.implicitWidth + 12
            height: 15
            radius: 7.5
            color: Theme.withAlpha(root.accentColor, 0.22)
            border.color: Theme.withAlpha(root.accentColor, 0.5)
            border.width: 1

            Text {
                id: labelText

                anchors.centerIn: parent
                text: root.label
                font.family: Fonts.uiFont
                font.pixelSize: Fonts.scale(8.5)
                font.weight: Fonts.weightBold
                color: "#FFFFFF"
            }

        }

    }

    Behavior on animatedValue {
        NumberAnimation {
            duration: 450
            easing.type: Easing.OutCubic
        }

    }

}
