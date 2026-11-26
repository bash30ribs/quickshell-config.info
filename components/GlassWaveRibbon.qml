import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property real phase: 0
    property real amplitudePx: 4
    property real frequency: 7.5
    property real baseFraction: 0.68
    property real leftMargin: 0
    property real rightMargin: 0
    property real edgeTaperBase: 0.28
    property color strokeColor: "#ffffff"
    property color fillColor: "#ffffff"
    property real fillAlpha: 0.16
    property real lineWidth: 1.8
    property real waveScaleFactor: 1
    readonly property real xLeft: root.leftMargin
    readonly property real xRight: Math.max(root.leftMargin + 12, root.width - root.rightMargin)
    readonly property real span: root.xRight - root.xLeft
    readonly property real baseY: root.height * root.baseFraction
    readonly property color fillTopCol: Qt.rgba(fillColor.r, fillColor.g, fillColor.b, Math.max(0, Math.min(1, fillColor.a * fillAlpha)))
    readonly property color fillMidCol: Qt.rgba(fillColor.r, fillColor.g, fillColor.b, Math.max(0, Math.min(1, fillColor.a * fillAlpha * 0.42)))

    function sampleY(u) {
        var taper = root.edgeTaperBase + (1 - root.edgeTaperBase) * Math.sin(u * Math.PI);
        var w = Math.sin(u * root.frequency + root.phase) * 0.65 + Math.cos(u * (root.frequency * 1.72) - root.phase * 0.72) * 0.35;
        return root.baseY - (w * root.amplitudePx * root.waveScaleFactor * taper);
    }

    function syncCurves() {
        var w = root.span;
        if (w <= 1 || root.height <= 1)
            return ;

        var dx = w / 6;
        var ys = [sampleY(0 / 6), sampleY(1 / 6), sampleY(2 / 6), sampleY(3 / 6), sampleY(4 / 6), sampleY(5 / 6), sampleY(6 / 6)];
        var ym1 = 2 * ys[0] - ys[1];
        var y7 = 2 * ys[6] - ys[5];
        var ext = [ym1, ys[0], ys[1], ys[2], ys[3], ys[4], ys[5], ys[6], y7];
        var fSegs = [fc0, fc1, fc2, fc3, fc4, fc5];
        var sSegs = [sc0, sc1, sc2, sc3, sc4, sc5];
        fillPath.startX = root.xLeft;
        fillPath.startY = ys[0];
        strokePath.startX = root.xLeft;
        strokePath.startY = ys[0];
        for (var i = 0; i < 6; i++) {
            var xi = root.xLeft + i * dx;
            var xn = xi + dx;
            var c1x = xi + dx / 3;
            var c2x = xn - dx / 3;
            var c1y = ys[i] + (ext[i + 2] - ext[i]) / 6;
            var c2y = ys[i + 1] - (ext[i + 3] - ext[i + 1]) / 6;
            var fs = fSegs[i];
            fs.control1X = c1x;
            fs.control1Y = c1y;
            fs.control2X = c2x;
            fs.control2Y = c2y;
            fs.x = xn;
            fs.y = ys[i + 1];
            var ss = sSegs[i];
            ss.control1X = c1x;
            ss.control1Y = c1y;
            ss.control2X = c2x;
            ss.control2Y = c2y;
            ss.x = xn;
            ss.y = ys[i + 1];
        }
        fillBotRight.x = root.xRight;
        fillBotRight.y = root.height;
        fillBotLeft.x = root.xLeft;
        fillBotLeft.y = root.height;
        fillClose.x = root.xLeft;
        fillClose.y = ys[0];
    }

    onPhaseChanged: syncCurves()
    onWidthChanged: syncCurves()
    onHeightChanged: syncCurves()
    onBaseFractionChanged: syncCurves()
    Component.onCompleted: syncCurves()

    Shape {
        id: shape

        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true

        ShapePath {
            id: fillPath

            strokeColor: "transparent"
            strokeWidth: 0
            startX: root.xLeft
            startY: root.baseY

            fillGradient: LinearGradient {
                x1: 0
                y1: Math.round(root.height * Math.max(0.15, root.baseFraction - 0.25))
                x2: 0
                y2: root.height

                GradientStop {
                    position: 0
                    color: root.fillAlpha > 0.005 ? root.fillTopCol : "transparent"
                }

                GradientStop {
                    position: 0.6
                    color: root.fillAlpha > 0.005 ? root.fillMidCol : "transparent"
                }

                GradientStop {
                    position: 1
                    color: "transparent"
                }

            }

            PathCubic {
                id: fc0
            }

            PathCubic {
                id: fc1
            }

            PathCubic {
                id: fc2
            }

            PathCubic {
                id: fc3
            }

            PathCubic {
                id: fc4
            }

            PathCubic {
                id: fc5
            }

            PathLine {
                id: fillBotRight
            }

            PathLine {
                id: fillBotLeft
            }

            PathLine {
                id: fillClose
            }

        }

        ShapePath {
            id: strokePath

            fillColor: "transparent"
            strokeColor: root.strokeColor
            strokeWidth: root.lineWidth
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: root.xLeft
            startY: root.baseY

            PathCubic {
                id: sc0
            }

            PathCubic {
                id: sc1
            }

            PathCubic {
                id: sc2
            }

            PathCubic {
                id: sc3
            }

            PathCubic {
                id: sc4
            }

            PathCubic {
                id: sc5
            }

        }

    }

}
