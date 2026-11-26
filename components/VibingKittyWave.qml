import "../theme"
import QtQuick

Item {
    id: root

    // Visual modes: "pill" (horizontal bar), "vertical" (vertical bar), "island" (media card)
    property string mode: "pill"
    property bool playing: false
    property bool activeVisible: true
    property bool pausedTransition: false
    property real phase: 0
    property real energy: root.playing ? 1 : 0
    property color accentColor: Theme.accent
    property color secondaryColor: Theme.foreground
    property color bodyColor: Theme.bright_foreground
    property color detailColor: Theme.dark_background
    readonly property bool shouldAnimate: root.activeVisible && root.visible && !root.pausedTransition && (root.playing || root.energy > 0.01)

    Behavior on energy {
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutCubic
        }

    }

    onEnergyChanged: waveCanvas.requestPaint()
    onPlayingChanged: waveCanvas.requestPaint()
    onAccentColorChanged: waveCanvas.requestPaint()
    onBodyColorChanged: waveCanvas.requestPaint()
    onWidthChanged: waveCanvas.requestPaint()
    onHeightChanged: waveCanvas.requestPaint()
    Component.onCompleted: waveCanvas.requestPaint()

    FrameAnimation {
        running: root.shouldAnimate
        onTriggered: {
            root.phase = (root.phase + frameTime * 4.4) % (Math.PI * 200);
            waveCanvas.requestPaint();
        }
    }

    Canvas {
        id: waveCanvas

        function rgbaStr(col, alphaMul) {
            var c = Qt.color(col);
            var a = Math.max(0, Math.min(1, c.a * alphaMul));
            return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a.toFixed(3) + ")";
        }

        function drawRibbonWave(ctx, xStart, xEnd, h, baseY, amp, freq, phaseShift, topColor, glowAlpha, lineAlpha, lineWidth) {
            var span = Math.max(1, xEnd - xStart);
            var steps = Math.max(14, Math.min(64, Math.round(span / 4)));
            ctx.beginPath();
            for (var i = 0; i <= steps; i++) {
                var u = i / steps;
                var x = xStart + u * span;
                var edgeTaper = Math.sin(u * Math.PI);
                var wave = Math.sin(u * freq + phaseShift) * 0.65 + Math.cos(u * (freq * 1.75) - phaseShift * 0.72) * 0.35;
                var y = baseY - wave * amp * (0.28 + 0.72 * edgeTaper);
                if (i === 0)
                    ctx.moveTo(x, y);
                else
                    ctx.lineTo(x, y);
            }
            if (glowAlpha > 0.005) {
                ctx.save();
                ctx.lineTo(xEnd, h);
                ctx.lineTo(xStart, h);
                ctx.closePath();
                var grad = ctx.createLinearGradient(0, Math.max(0, baseY - amp - 2), 0, h);
                grad.addColorStop(0, rgbaStr(topColor, glowAlpha));
                grad.addColorStop(1, rgbaStr(topColor, 0));
                ctx.fillStyle = grad;
                ctx.fill();
                ctx.restore();
            }
            ctx.strokeStyle = rgbaStr(topColor, lineAlpha);
            ctx.lineWidth = lineWidth;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.stroke();
        }

        function drawVibingKitty(ctx, cx, cy, u, phaseVal, e, showNotes) {
            var bob = Math.sin(phaseVal * 2.0) * (u * 0.085) * e;
            var tilt = Math.sin(phaseVal) * 0.13 * e;
            var earPerk = Math.sin(phaseVal * 2.0 + 0.5) * (u * 0.045) * e;
            var hx = u * 0.48;
            var hy = u * 0.37;
            // Subtle floating music eighth-note in expanded mode while vibing
            if (showNotes && e > 0.45) {
                var noteCycle = (phaseVal * 0.28) % 1.0;
                var noteAlpha = Math.sin(noteCycle * Math.PI) * 0.85 * e;
                var nx = cx - u * 0.75 + Math.sin(noteCycle * Math.PI * 2) * (u * 0.14);
                var ny = cy - u * 0.32 - noteCycle * (u * 0.55);
                ctx.save();
                ctx.strokeStyle = rgbaStr(root.accentColor, noteAlpha);
                ctx.fillStyle = rgbaStr(root.accentColor, noteAlpha);
                ctx.lineWidth = Math.max(1.1, u * 0.075);
                ctx.beginPath();
                ctx.ellipse(nx - u * 0.12, ny - u * 0.06, u * 0.14, u * 0.1);
                ctx.fill();
                ctx.beginPath();
                ctx.moveTo(nx, ny);
                ctx.lineTo(nx, ny - u * 0.28);
                ctx.lineTo(nx + u * 0.14, ny - u * 0.22);
                ctx.stroke();
                ctx.restore();
            }
            ctx.save();
            ctx.translate(cx, cy + bob);
            ctx.rotate(tilt);
            // Ambient glow behind kitty when playing
            if (e > 0.08) {
                var halo = ctx.createRadialGradient(0, 0, u * 0.1, 0, 0, u * 0.95);
                halo.addColorStop(0, rgbaStr(root.accentColor, 0.26 * e));
                halo.addColorStop(1, rgbaStr(root.accentColor, 0));
                ctx.fillStyle = halo;
                ctx.beginPath();
                ctx.arc(0, 0, u * 0.95, 0, Math.PI * 2);
                ctx.fill();
            }
            // Headphones headband over top of kitty head
            if (e > 0.2) {
                ctx.strokeStyle = rgbaStr(root.accentColor, 0.92 * e);
                ctx.lineWidth = Math.max(1.3, u * 0.095);
                ctx.lineCap = "round";
                ctx.beginPath();
                ctx.arc(0, -hy * 0.12, hx * 1.12, Math.PI * 1.08, Math.PI * 1.92);
                ctx.stroke();
                // Left & right earcups
                ctx.fillStyle = rgbaStr(root.accentColor, 0.95 * e);
                ctx.beginPath();
                ctx.roundedRect(-hx * 1.24, -u * 0.12, u * 0.17, u * 0.34, u * 0.08, u * 0.08);
                ctx.fill();
                ctx.beginPath();
                ctx.roundedRect(hx * 1.24 - u * 0.17, -u * 0.12, u * 0.17, u * 0.34, u * 0.08, u * 0.08);
                ctx.fill();
            }
            // Left & right outer pointed ears
            ctx.fillStyle = rgbaStr(root.bodyColor, 0.96);
            ctx.beginPath();
            ctx.moveTo(-hx * 0.78, -hy * 0.45);
            ctx.lineTo(-hx * 0.68, -hy * 1.48 - earPerk);
            ctx.lineTo(-hx * 0.16, -hy * 0.88);
            ctx.closePath();
            ctx.fill();
            ctx.beginPath();
            ctx.moveTo(hx * 0.78, -hy * 0.45);
            ctx.lineTo(hx * 0.68, -hy * 1.48 + earPerk * 0.6);
            ctx.lineTo(hx * 0.16, -hy * 0.88);
            ctx.closePath();
            ctx.fill();
            // Cute accent inner-ear triangles
            ctx.fillStyle = rgbaStr(root.accentColor, 0.62 + 0.35 * e);
            ctx.beginPath();
            ctx.moveTo(-hx * 0.66, -hy * 0.58);
            ctx.lineTo(-hx * 0.60, -hy * 1.22 - earPerk * 0.8);
            ctx.lineTo(-hx * 0.28, -hy * 0.84);
            ctx.closePath();
            ctx.fill();
            ctx.beginPath();
            ctx.moveTo(hx * 0.66, -hy * 0.58);
            ctx.lineTo(hx * 0.60, -hy * 1.22 + earPerk * 0.5);
            ctx.lineTo(hx * 0.28, -hy * 0.84);
            ctx.closePath();
            ctx.fill();
            // Squishy rounded kitty head
            ctx.fillStyle = rgbaStr(root.bodyColor, 0.96);
            ctx.beginPath();
            ctx.ellipse(-hx, -hy, hx * 2, hy * 2);
            ctx.fill();
            // Subtle accent outline around head for crispness on light/dark surfaces
            ctx.strokeStyle = rgbaStr(root.accentColor, 0.28 + 0.38 * e);
            ctx.lineWidth = Math.max(0.8, u * 0.05);
            ctx.stroke();
            // Expressive eyes: joyful ^ ^ when vibing, peaceful sleepy arcs when paused
            ctx.strokeStyle = rgbaStr(root.detailColor, 0.92);
            ctx.lineWidth = Math.max(1.15, u * 0.085);
            ctx.lineCap = "round";
            var eyeX = hx * 0.42;
            var eyeY = -hy * 0.04;
            var eyeW = u * 0.13;
            if (e > 0.35) {
                // Happy upturned vibing eyes (^ ^)
                ctx.beginPath();
                ctx.moveTo(-eyeX - eyeW, eyeY + u * 0.04);
                ctx.lineTo(-eyeX, eyeY - u * 0.07);
                ctx.lineTo(-eyeX + eyeW, eyeY + u * 0.04);
                ctx.moveTo(eyeX - eyeW, eyeY + u * 0.04);
                ctx.lineTo(eyeX, eyeY - u * 0.07);
                ctx.lineTo(eyeX + eyeW, eyeY + u * 0.04);
                ctx.stroke();
            } else {
                // Resting sleepy lids (- -)
                ctx.beginPath();
                ctx.moveTo(-eyeX - eyeW, eyeY);
                ctx.lineTo(-eyeX + eyeW, eyeY);
                ctx.moveTo(eyeX - eyeW, eyeY);
                ctx.lineTo(eyeX + eyeW, eyeY);
                ctx.stroke();
            }
            // Tiny pink/accent nose dot
            ctx.fillStyle = rgbaStr(root.accentColor, 0.95);
            ctx.beginPath();
            ctx.arc(0, hy * 0.22, Math.max(0.9, u * 0.065), 0, Math.PI * 2);
            ctx.fill();
            // Tiny whisker ticks on larger views
            if (u >= 15) {
                ctx.strokeStyle = rgbaStr(root.detailColor, 0.38);
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
            // Alternating bopping paws riding the crest underneath the head
            var pawBounceL = Math.max(0, Math.sin(phaseVal * 2.0)) * (u * 0.14) * e;
            var pawBounceR = Math.max(0, -Math.sin(phaseVal * 2.0)) * (u * 0.14) * e;
            var pawY = cy + hy + bob * 0.4 + u * 0.06;
            ctx.fillStyle = rgbaStr(root.bodyColor, 0.95);
            ctx.beginPath();
            ctx.ellipse(cx - u * 0.26 - u * 0.09, pawY - pawBounceL - u * 0.06, u * 0.18, u * 0.12);
            ctx.fill();
            ctx.beginPath();
            ctx.ellipse(cx + u * 0.26 - u * 0.09, pawY - pawBounceR - u * 0.06, u * 0.18, u * 0.12);
            ctx.fill();
        }

        anchors.fill: parent
        antialiasing: true
        onPaint: {
            var ctx = getContext("2d");
            var w = width;
            var h = height;
            if (w <= 0 || h <= 0)
                return ;

            ctx.clearRect(0, 0, w, h);
            var e = root.energy;
            var ph = root.phase;
            if (root.mode === "island") {
                // Full-width dual ambient music waves along bottom of Media Island card
                var baseWaveY = h - 8;
                drawRibbonWave(ctx, 4, w - 4, h, baseWaveY + 1, 1.2 + 3.2 * e, 10.5, -ph * 0.85 + 1.4, root.secondaryColor, 0.08 + 0.10 * e, 0.25 + 0.25 * e, 1.25);
                drawRibbonWave(ctx, 4, w - 4, h, baseWaveY, 1.4 + 4.2 * e, 8.2, ph, root.accentColor, 0.14 + 0.20 * e, 0.45 + 0.45 * e, 1.75);
                // Perched vibing kitty riding the right-hand side of the wave floor
                var kittySize = Math.min(20, Math.max(15, h * 0.5));
                drawVibingKitty(ctx, w - kittySize * 0.95, h - kittySize * 0.68, kittySize, ph, e, true);
            } else if (root.mode === "vertical") {
                // Ultra-compact wave + kitty badge for narrow vertical dock
                drawRibbonWave(ctx, 1, w - 1, h, h - 3, 0.6 + 1.8 * e, 6.2, ph, root.accentColor, 0.16 * e, 0.55 + 0.40 * e, 1.3);
                var vertSize = Math.min(11.5, Math.min(w, h) * 0.62);
                drawVibingKitty(ctx, w * 0.5, h * 0.58, vertSize, ph, e, false);
            } else {
                // Horizontal Bar Pill ("pill"): smooth wave leading up to vibing kitty on right
                var waveEnd = Math.max(18, w - 14);
                var waveY = h * 0.72;
                drawRibbonWave(ctx, 2, waveEnd, h, waveY + 1, 0.6 + 2.6 * e, 8.4, -ph * 0.82 + 1.1, root.secondaryColor, 0.06 + 0.08 * e, 0.25 + 0.30 * e, 1.2);
                drawRibbonWave(ctx, 2, waveEnd, h, waveY, 0.8 + 3.8 * e, 7.2, ph, root.accentColor, 0.12 + 0.18 * e, 0.45 + 0.48 * e, 1.65);
                var pillKittySize = Math.min(14.5, h * 0.66);
                drawVibingKitty(ctx, w - 10.5, h * 0.46, pillKittySize, ph, e, false);
            }
        }
    }

}
