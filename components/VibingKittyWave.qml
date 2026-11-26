import "../services"
import "../theme"
import QtQuick

Item {
    id: root

    // Visual modes: "pill" (horizontal bar), "vertical" (vertical bar), "island" (media card)
    property string mode: "pill"
    property bool playing: false
    property bool activeVisible: true
    property bool pausedTransition: false
    property AudioSyncService audioSync: null
    property real phase: 0
    property real _animAccum: 0
    property real energy: root.playing ? 1 : 0
    property color accentColor: Theme.accent
    property color secondaryColor: Theme.foreground
    property color bodyColor: Theme.bright_foreground
    property color detailColor: Theme.dark_background
    readonly property bool shouldAnimate: root.activeVisible && root.visible && !root.pausedTransition && (root.playing || root.energy > 0.01)
    readonly property bool liveHasSignal: !!(root.audioSync && root.audioSync.hasSignal)
    readonly property real liveLevel: liveHasSignal ? root.audioSync.level : 0.30
    readonly property real liveBass: liveHasSignal ? root.audioSync.bass : 0.25
    readonly property real liveBeat: liveHasSignal ? root.audioSync.beat : 0
    readonly property real liveSpeed: liveHasSignal ? root.audioSync.speed : 0.85
    readonly property real waveBoost: 0.36 + 0.60 * root.liveLevel + 0.50 * root.liveBass + 0.36 * root.liveBeat
    readonly property bool showHappyKitty: root.energy > 0.35
    readonly property real kittyUnit: {
        if (root.mode === "island")
            return Math.min(20, Math.max(15, root.height * 0.5));

        if (root.mode === "vertical")
            return Math.min(11.5, Math.min(root.width, root.height) * 0.62);

        return Math.min(14.5, root.height * 0.66);
    }
    readonly property real kittyCenterX: {
        if (root.mode === "island")
            return root.width - root.kittyUnit * 0.95;

        if (root.mode === "vertical")
            return root.width * 0.5;

        return root.width - 10.5;
    }
    readonly property real kittyCenterY: {
        if (root.mode === "island")
            return root.height - root.kittyUnit * 0.68;

        if (root.mode === "vertical")
            return root.height * 0.58;

        return root.height * 0.46;
    }
    readonly property real kittyBobY: {
        var kinetic = 0.45 + 0.45 * root.liveLevel + 0.35 * root.liveBass + 0.65 * root.liveBeat;
        return (Math.sin(root.phase * 2.0) * 0.65 + (root.liveBeat * 0.72)) * (root.kittyUnit * 0.105) * root.energy * kinetic;
    }
    readonly property real kittyTiltDeg: Math.sin(root.phase) * (4.5 + 3.4 * Math.min(2.2, root.liveSpeed)) * root.energy

    Behavior on energy {
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutCubic
        }

    }

    FrameAnimation {
        running: root.shouldAnimate
        onTriggered: {
            root._animAccum += frameTime;
            if (root._animAccum < 0.020)
                return ;

            var dt = root._animAccum;
            root._animAccum = 0;
            var rate = root.liveHasSignal ? (1.45 + root.liveSpeed * 3.15) : 2.1;
            root.phase = (root.phase + dt * rate) % (Math.PI * 200);
        }
    }

    // Back harmonic wave ribbon (GPU CurveRenderer — static gradient + GPU opacity)
    GlassWaveRibbon {
        anchors.fill: parent
        visible: root.mode !== "vertical"
        phase: -root.phase * 0.85 + 1.4
        leftMargin: root.mode === "island" ? 4 : 2
        rightMargin: root.mode === "island" ? 4 : 14
        baseFraction: root.mode === "island" ? ((root.height - 7) / Math.max(1, root.height)) : 0.76
        frequency: root.mode === "island" ? 10.5 : 8.4
        amplitudePx: (root.mode === "island" ? (0.9 + 3.4 * root.energy * root.waveBoost) : (0.5 + 2.6 * root.energy * root.waveBoost))
        strokeColor: Theme.withAlpha(root.secondaryColor, 0.58)
        fillColor: root.secondaryColor
        fillAlpha: root.mode === "island" ? 0.16 : 0.12
        opacity: 0.42 + (0.46 + 0.12 * root.liveBeat) * root.energy
        lineWidth: 1.25
    }

    // Primary luminous accent wave ribbon (GPU CurveRenderer — static gradient + GPU opacity)
    GlassWaveRibbon {
        anchors.fill: parent
        phase: root.phase
        leftMargin: root.mode === "island" ? 4 : (root.mode === "vertical" ? 1 : 2)
        rightMargin: root.mode === "island" ? 4 : (root.mode === "vertical" ? 1 : 14)
        baseFraction: root.mode === "island" ? ((root.height - 8) / Math.max(1, root.height)) : (root.mode === "vertical" ? ((root.height - 3) / Math.max(1, root.height)) : 0.72)
        frequency: root.mode === "vertical" ? 6.2 : (root.mode === "island" ? 8.2 : 7.2)
        amplitudePx: (root.mode === "island" ? (1.0 + 4.4 * root.energy * root.waveBoost) : (root.mode === "vertical" ? (0.5 + 2.0 * root.energy * root.waveBoost) : (0.6 + 3.8 * root.energy * root.waveBoost)))
        strokeColor: Theme.withAlpha(root.accentColor, 0.92)
        fillColor: root.accentColor
        fillAlpha: root.mode === "vertical" ? 0.18 : 0.28
        opacity: 0.45 + (0.43 + 0.12 * root.liveBeat) * root.energy
        lineWidth: root.mode === "vertical" ? 1.3 : (root.mode === "island" ? 1.75 : 1.65)
    }

    // Subtle glowing radial halo behind kitty driven purely by GPU transforms & opacity
    Rectangle {
        visible: root.energy > 0.08
        width: root.kittyUnit * 1.65
        height: width
        radius: width / 2
        x: Math.round(root.kittyCenterX - width / 2)
        y: Math.round(root.kittyCenterY + root.kittyBobY - height / 2)
        scale: 0.92 + 0.22 * root.liveBeat
        color: Theme.withAlpha(root.accentColor, (0.12 + 0.10 * root.liveLevel + 0.18 * root.liveBeat) * root.energy)
    }

    // Floating eighth note in expanded island mode
    Text {
        readonly property real cycle: (root.phase * 0.28) % 1.0

        visible: root.mode === "island" && root.energy > 0.45
        text: "♪"
        font.pixelSize: Math.max(9, Math.round(root.kittyUnit * 0.58))
        font.bold: true
        color: root.accentColor
        opacity: Math.sin(cycle * Math.PI) * (0.65 + 0.30 * root.liveBeat) * root.energy
        x: root.kittyCenterX - root.kittyUnit * 1.15 + Math.sin(cycle * Math.PI * 2) * (root.kittyUnit * 0.16)
        y: root.kittyCenterY - root.kittyUnit * 0.65 - cycle * (root.kittyUnit * 0.62)
    }

    // Static-cached kitty head Canvas (painted ONLY on size, state, or theme color change -> 0 per-frame Canvas work!)
    Canvas {
        id: kittyHeadCanvas

        readonly property int cacheDim: Math.max(16, Math.ceil(root.kittyUnit * 1.85))
        readonly property bool isHappy: root.showHappyKitty
        readonly property color accCol: root.accentColor
        readonly property color bodCol: root.bodyColor
        readonly property color detCol: root.detailColor

        function cRgba(col, aMul) {
            var c = Qt.color(col);
            return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + Math.max(0, Math.min(1, c.a * aMul)).toFixed(2) + ")";
        }

        width: cacheDim
        height: cacheDim
        x: root.kittyCenterX - width / 2
        y: root.kittyCenterY + root.kittyBobY - height / 2
        rotation: root.kittyTiltDeg
        transformOrigin: Item.Center
        antialiasing: true
        onCacheDimChanged: requestPaint()
        onIsHappyChanged: requestPaint()
        onAccColChanged: requestPaint()
        onBodColChanged: requestPaint()
        onDetColChanged: requestPaint()
        Component.onCompleted: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            var w = width;
            var h = height;
            if (w <= 0 || h <= 0)
                return ;

            ctx.clearRect(0, 0, w, h);
            var u = root.kittyUnit;
            var hx = u * 0.48;
            var hy = u * 0.37;
            ctx.save();
            ctx.translate(w * 0.5, h * 0.54);
            // Headphones headband & earcups when active/happy
            if (root.showHappyKitty) {
                ctx.strokeStyle = cRgba(root.accentColor, 0.94);
                ctx.lineWidth = Math.max(1.3, u * 0.095);
                ctx.lineCap = "round";
                ctx.beginPath();
                ctx.arc(0, -hy * 0.12, hx * 1.12, Math.PI * 1.08, Math.PI * 1.92);
                ctx.stroke();
                ctx.fillStyle = cRgba(root.accentColor, 0.96);
                ctx.beginPath();
                ctx.roundedRect(-hx * 1.24, -u * 0.12, u * 0.17, u * 0.34, u * 0.08, u * 0.08);
                ctx.fill();
                ctx.beginPath();
                ctx.roundedRect(hx * 1.24 - u * 0.17, -u * 0.12, u * 0.17, u * 0.34, u * 0.08, u * 0.08);
                ctx.fill();
            }
            // Pointed outer ears
            ctx.fillStyle = cRgba(root.bodyColor, 0.97);
            ctx.beginPath();
            ctx.moveTo(-hx * 0.78, -hy * 0.45);
            ctx.lineTo(-hx * 0.68, -hy * 1.48);
            ctx.lineTo(-hx * 0.16, -hy * 0.88);
            ctx.closePath();
            ctx.fill();
            ctx.beginPath();
            ctx.moveTo(hx * 0.78, -hy * 0.45);
            ctx.lineTo(hx * 0.68, -hy * 1.48);
            ctx.lineTo(hx * 0.16, -hy * 0.88);
            ctx.closePath();
            ctx.fill();
            // Inner ear accent triangles
            ctx.fillStyle = cRgba(root.accentColor, root.showHappyKitty ? 0.94 : 0.62);
            ctx.beginPath();
            ctx.moveTo(-hx * 0.66, -hy * 0.58);
            ctx.lineTo(-hx * 0.60, -hy * 1.22);
            ctx.lineTo(-hx * 0.28, -hy * 0.84);
            ctx.closePath();
            ctx.fill();
            ctx.beginPath();
            ctx.moveTo(hx * 0.66, -hy * 0.58);
            ctx.lineTo(hx * 0.60, -hy * 1.22);
            ctx.lineTo(hx * 0.28, -hy * 0.84);
            ctx.closePath();
            ctx.fill();
            // Head oval
            ctx.fillStyle = cRgba(root.bodyColor, 0.97);
            ctx.beginPath();
            ctx.ellipse(-hx, -hy, hx * 2, hy * 2);
            ctx.fill();
            ctx.strokeStyle = cRgba(root.accentColor, root.showHappyKitty ? 0.62 : 0.28);
            ctx.lineWidth = Math.max(0.8, u * 0.05);
            ctx.stroke();
            // Happy ^ ^ eyes when playing vs calm - - when paused
            ctx.strokeStyle = cRgba(root.detailColor, 0.92);
            ctx.lineWidth = Math.max(1.15, u * 0.085);
            ctx.lineCap = "round";
            var eyeX = hx * 0.42;
            var eyeY = -hy * 0.04;
            var eyeW = u * 0.13;
            if (root.showHappyKitty) {
                ctx.beginPath();
                ctx.moveTo(-eyeX - eyeW, eyeY + u * 0.04);
                ctx.lineTo(-eyeX, eyeY - u * 0.07);
                ctx.lineTo(-eyeX + eyeW, eyeY + u * 0.04);
                ctx.moveTo(eyeX - eyeW, eyeY + u * 0.04);
                ctx.lineTo(eyeX, eyeY - u * 0.07);
                ctx.lineTo(eyeX + eyeW, eyeY + u * 0.04);
                ctx.stroke();
            } else {
                ctx.beginPath();
                ctx.moveTo(-eyeX - eyeW, eyeY);
                ctx.lineTo(-eyeX + eyeW, eyeY);
                ctx.moveTo(eyeX - eyeW, eyeY);
                ctx.lineTo(eyeX + eyeW, eyeY);
                ctx.stroke();
            }
            // Nose dot
            ctx.fillStyle = cRgba(root.accentColor, 0.96);
            ctx.beginPath();
            ctx.arc(0, hy * 0.22, Math.max(0.9, u * 0.065), 0, Math.PI * 2);
            ctx.fill();
            if (u >= 15) {
                ctx.strokeStyle = cRgba(root.detailColor, 0.38);
                ctx.lineWidth = Math.max(0.8, u * 0.045);
                ctx.beginPath();
                ctx.moveTo(-hx * 0.72, hy * 0.1);
                ctx.lineTo(-hx * 1.05, hy * 0.02);
                ctx.moveTo(-hx * 0.72, hy * 0.34);
                ctx.lineTo(-hx * 1.02, hy * 0.42);
                ctx.moveTo(hx * 0.72, hy * 0.1);
                ctx.lineTo(hx * 1.05, hy * 0.02);
                ctx.moveTo(hx * 0.72, hy * 0.34);
                ctx.lineTo(hx * 1.02, hy * 0.42);
                ctx.stroke();
            }
            ctx.restore();
        }
    }

    // Hardware-composited bopping left & right paws synced cleanly to beat
    Rectangle {
        readonly property real pawDrive: 0.55 + 0.55 * root.liveBeat + 0.25 * root.liveBass
        readonly property real bounce: Math.max(0, Math.sin(root.phase * 2.0)) * (root.kittyUnit * 0.16) * root.energy * pawDrive

        width: Math.max(2, root.kittyUnit * 0.22)
        height: Math.max(1.5, root.kittyUnit * 0.14)
        radius: height / 2
        color: Theme.withAlpha(root.bodyColor, 0.96)
        x: root.kittyCenterX - root.kittyUnit * 0.30 - width / 2
        y: root.kittyCenterY + root.kittyUnit * 0.38 + root.kittyBobY * 0.4 - bounce
    }

    Rectangle {
        readonly property real pawDrive: 0.55 + 0.55 * root.liveBeat + 0.25 * root.liveBass
        readonly property real bounce: Math.max(0, -Math.sin(root.phase * 2.0)) * (root.kittyUnit * 0.16) * root.energy * pawDrive

        width: Math.max(2, root.kittyUnit * 0.22)
        height: Math.max(1.5, root.kittyUnit * 0.14)
        radius: height / 2
        color: Theme.withAlpha(root.bodyColor, 0.96)
        x: root.kittyCenterX + root.kittyUnit * 0.30 - width / 2
        y: root.kittyCenterY + root.kittyUnit * 0.38 + root.kittyBobY * 0.4 - bounce
    }

}
