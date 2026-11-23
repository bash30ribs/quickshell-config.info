import "../theme"
import QtQuick
import Quickshell

Item {
    // ─────────────────────────────────────────────────────────────────────────
    // Quickshell Apple Liquid Glass Panel Component
    // Inspired by Apple visionOS & macOS Liquid Glass Visual Language
    // Designed for native Wayland compositor dual-kawase blur integration
    // ─────────────────────────────────────────────────────────────────────────

    id: root

    // Mode: "liquid"  (Specular rim + subtle top sheen + translucent body),
    //       "frosted" (Clean frosted gradient over compositor blur),
    //       "clear"   (High-clarity crystal refraction),
    //       "flat"    (High-performance solid fallback)
    property string mode: Appearance.glassMode || "liquid"
    // Screen-facing / crest light edge ("top", "bottom", "left", "right")
    property string lightEdge: "top"
    // Geometry & Squircles
    property int radius: Appearance.popupRadius > 0 ? Appearance.popupRadius : 14
    property int topLeftRadius: -1
    property int topRightRadius: -1
    property int bottomLeftRadius: -1
    property int bottomRightRadius: -1
    readonly property int effectiveTopLeftRadius: topLeftRadius >= 0 ? topLeftRadius : radius
    readonly property int effectiveTopRightRadius: topRightRadius >= 0 ? topRightRadius : radius
    readonly property int effectiveBottomLeftRadius: bottomLeftRadius >= 0 ? bottomLeftRadius : radius
    readonly property int effectiveBottomRightRadius: bottomRightRadius >= 0 ? bottomRightRadius : radius
    readonly property bool isPill: (root.lightEdge === "left" || root.lightEdge === "right") ? (Math.max(root.effectiveTopLeftRadius, root.effectiveTopRightRadius, root.effectiveBottomLeftRadius, root.effectiveBottomRightRadius) >= (root.width * 0.42)) : (root.effectiveTopLeftRadius >= (root.height * 0.42))
    readonly property bool isHorizontalLight: root.lightEdge === "top" || root.lightEdge === "bottom"
    // Optical Parameters (exposed for live tuning)
    property real clarity: Appearance.glassClarity !== undefined ? Appearance.glassClarity : 0.75
    property real rimIllumination: Appearance.glassRimIllumination !== undefined ? Appearance.glassRimIllumination : 0.5
    property real specularIntensity: Appearance.glassSpecularIntensity !== undefined ? Appearance.glassSpecularIntensity : 0.75
    property real refractionStrength: Appearance.glassRefractionStrength !== undefined ? Appearance.glassRefractionStrength : 0.85
    // Interaction State (Mornye Spring Physics: Mass 1, Stiffness 420, Damping 24)
    property bool interactive: false
    property bool isHovered: false
    property bool isPressed: false
    property bool active: false
    // Color Tinting
    property color baseColor: Theme.barBackground || Theme.background
    property color accentTint: Theme.accent
    // External Backdrop Source compatibility
    property var externalBackdrop: null
    property point backdropOffset: Qt.point(0, 0)
    // Child Content Reparenting
    default property alias content: contentContainer.data

    implicitWidth: 100
    implicitHeight: 100

    // ─────────────────────────────────────────────────────────────────────────
    // Physical Spring Physics Scale & Compression Container (m=1.0, k=420, c=24)
    // ─────────────────────────────────────────────────────────────────────────
    Item {
        id: surfaceContainer

        anchors.fill: parent
        scale: {
            if (!root.interactive)
                return 1;

            if (root.isPressed)
                return 0.965;

            if (root.isHovered)
                return 1.025;

            return 1;
        }

        // ─────────────────────────────────────────────────────────────────────
        // Master Glass Surface (Compositor-friendly translucent liquid glass)
        // ─────────────────────────────────────────────────────────────────────
        Rectangle {
            id: glassSurface

            anchors.fill: parent
            clip: true
            radius: (root.topLeftRadius < 0 && root.topRightRadius < 0 && root.bottomLeftRadius < 0 && root.bottomRightRadius < 0) ? root.radius : 0
            topLeftRadius: root.effectiveTopLeftRadius
            topRightRadius: root.effectiveTopRightRadius
            bottomLeftRadius: root.effectiveBottomLeftRadius
            bottomRightRadius: root.effectiveBottomRightRadius
            antialiasing: true
            color: {
                if (root.mode === "flat")
                    return Theme.darker_background;

                return "transparent";
            }
            // Mode C (Liquid) and Mode B (Frosted) Multi-stop Lens Gradient
            // Calibrated to harmonize with Kitty's 0.35 opacity and compositor glass shaders
            gradient: root.mode === "flat" ? null : liquidGradient
            // ─────────────────────────────────────────────────────────────────
            // Illuminated Rim Stroke (Subtle 1px edge definition)
            // ─────────────────────────────────────────────────────────────────
            border.width: 1
            border.color: {
                if (root.mode === "flat")
                    return Theme.withAlpha(Theme.foreground, 0.15);

                if (root.active)
                    return Theme.withAlpha(root.accentTint, 0.65);

                if (root.isHovered)
                    return Qt.rgba(1, 1, 1, Appearance.hyprglassEnabled ? 0.28 : 0.32);

                return Qt.rgba(1, 1, 1, Appearance.hyprglassEnabled ? 0.12 : 0.16);
            }

            Gradient {
                id: liquidGradient

                // Dynamic clarity scaling harmonized with Kitty (0.35 reference)
                readonly property bool useHyprglass: Appearance.hyprglassEnabled
                readonly property real clarityFactor: Math.max(0.6, Math.min(1.4, 1 - (root.clarity - 0.75) * 0.8))
                readonly property real baseAlpha: liquidGradient.useHyprglass ? (root.mode === "clear" ? 0.18 : (root.mode === "liquid" ? 0.24 : 0.3)) : (root.mode === "clear" ? 0.32 : (root.mode === "liquid" ? 0.4 : 0.48))
                readonly property real midAlpha: liquidGradient.useHyprglass ? (root.mode === "clear" ? 0.22 : (root.mode === "liquid" ? 0.28 : 0.34)) : (root.mode === "clear" ? 0.38 : (root.mode === "liquid" ? 0.46 : 0.54))
                readonly property real bodyAlpha: liquidGradient.useHyprglass ? (root.mode === "clear" ? 0.25 : (root.mode === "liquid" ? 0.32 : 0.38)) : (root.mode === "clear" ? 0.44 : (root.mode === "liquid" ? 0.52 : 0.6))
                readonly property real deepAlpha: liquidGradient.useHyprglass ? (root.mode === "clear" ? 0.28 : (root.mode === "liquid" ? 0.35 : 0.42)) : (root.mode === "clear" ? 0.5 : (root.mode === "liquid" ? 0.58 : 0.68))

                // Position 0.0: High-clarity crystalline specular crest
                GradientStop {
                    position: 0
                    color: {
                        var c = liquidGradient.useHyprglass ? Qt.rgba(0.08, 0.09, 0.12, liquidGradient.baseAlpha * liquidGradient.clarityFactor) : Qt.rgba(0.06, 0.07, 0.1, liquidGradient.baseAlpha);
                        if (root.active)
                            c = Qt.tint(c, Theme.withAlpha(root.accentTint, 0.12));
                        else if (root.isHovered)
                            c = Qt.tint(c, Theme.withAlpha(root.accentTint, 0.05));
                        var sheen = (root.mode === "liquid" || root.mode === "clear") ? (0.05 * root.specularIntensity) : 0.03;
                        if (root.isHovered)
                            sheen += 0.03;

                        return Qt.tint(c, Qt.rgba(1, 1, 1, sheen));
                    }
                }

                // Position 0.18: Sub-crest luminous optical transition
                GradientStop {
                    position: 0.18
                    color: {
                        var c = liquidGradient.useHyprglass ? Qt.rgba(0.07, 0.08, 0.11, liquidGradient.midAlpha * liquidGradient.clarityFactor) : Qt.rgba(0.05, 0.06, 0.08, liquidGradient.midAlpha);
                        if (root.active)
                            c = Qt.tint(c, Theme.withAlpha(root.accentTint, 0.1));

                        return c;
                    }
                }

                // Position 0.55: Pure translucent body allowing compositor glass shaders to refract vibrantly
                GradientStop {
                    position: 0.55
                    color: {
                        var c = liquidGradient.useHyprglass ? Qt.rgba(0.06, 0.07, 0.1, liquidGradient.bodyAlpha * liquidGradient.clarityFactor) : Qt.rgba(0.04, 0.05, 0.07, liquidGradient.bodyAlpha);
                        if (root.active)
                            c = Qt.tint(c, Theme.withAlpha(root.accentTint, 0.08));

                        return c;
                    }
                }

                // Position 1.0: Deep ambient ground base
                GradientStop {
                    position: 1
                    color: {
                        var c = liquidGradient.useHyprglass ? Qt.rgba(0.05, 0.06, 0.09, liquidGradient.deepAlpha * liquidGradient.clarityFactor) : Qt.rgba(0.03, 0.04, 0.06, liquidGradient.deepAlpha);
                        if (root.active)
                            c = Qt.tint(c, Theme.withAlpha(root.accentTint, 0.06));

                        return c;
                    }
                }

            }

            // ─────────────────────────────────────────────────────────────────
            // Curved Edge Specular Diffuse Sheen (follows active lightEdge)
            // ─────────────────────────────────────────────────────────────────
            Rectangle {
                id: specularSheen

                readonly property real bandSize: root.isHorizontalLight ? Math.max(8, Math.min(22, parent.height * 0.32)) : Math.max(8, Math.min(18, parent.width * 0.32))
                readonly property bool reverseStops: root.lightEdge === "bottom" || root.lightEdge === "right"

                visible: root.mode === "liquid" || root.mode === "clear" || root.mode === "frosted"
                x: root.isHorizontalLight ? 1 : (root.lightEdge === "left" ? 1 : Math.max(1, parent.width - 1 - bandSize))
                y: root.isHorizontalLight ? (root.lightEdge === "top" ? 1 : Math.max(1, parent.height - 1 - bandSize)) : 1
                width: root.isHorizontalLight ? Math.max(0, parent.width - 2) : bandSize
                height: root.isHorizontalLight ? bandSize : Math.max(0, parent.height - 2)
                topLeftRadius: Math.max(0, root.effectiveTopLeftRadius - 1)
                topRightRadius: Math.max(0, root.effectiveTopRightRadius - 1)
                bottomLeftRadius: Math.max(0, root.effectiveBottomLeftRadius - 1)
                bottomRightRadius: Math.max(0, root.effectiveBottomRightRadius - 1)
                antialiasing: true

                gradient: Gradient {
                    orientation: root.isHorizontalLight ? Gradient.Vertical : Gradient.Horizontal

                    GradientStop {
                        position: 0
                        color: specularSheen.reverseStops ? "transparent" : Qt.rgba(1, 1, 1, 0.08 * root.specularIntensity)
                    }

                    GradientStop {
                        position: 0.5
                        color: Qt.rgba(1, 1, 1, 0.02 * root.specularIntensity)
                    }

                    GradientStop {
                        position: 1
                        color: specularSheen.reverseStops ? Qt.rgba(1, 1, 1, 0.08 * root.specularIntensity) : "transparent"
                    }

                }

            }

            // ─────────────────────────────────────────────────────────────────
            // Feathered Edge Rim Catch (merges invisibly into corner arcs)
            // ─────────────────────────────────────────────────────────────────
            Rectangle {
                id: illuminatedTopEdge

                readonly property real insetA: root.isHorizontalLight ? Math.max(3, Math.round((root.lightEdge === "top" ? root.effectiveTopLeftRadius : root.effectiveBottomLeftRadius) * 0.45)) : Math.max(3, Math.round((root.lightEdge === "left" ? root.effectiveTopLeftRadius : root.effectiveTopRightRadius) * 0.45))
                readonly property real insetB: root.isHorizontalLight ? Math.max(3, Math.round((root.lightEdge === "top" ? root.effectiveTopRightRadius : root.effectiveBottomRightRadius) * 0.45)) : Math.max(3, Math.round((root.lightEdge === "left" ? root.effectiveBottomLeftRadius : root.effectiveBottomRightRadius) * 0.45))

                visible: root.mode === "liquid" || root.mode === "clear" || root.mode === "frosted"
                x: root.isHorizontalLight ? insetA : (root.lightEdge === "left" ? 1 : Math.max(1, parent.width - 2))
                y: root.isHorizontalLight ? (root.lightEdge === "top" ? 1 : Math.max(1, parent.height - 2)) : insetA
                width: root.isHorizontalLight ? Math.max(0, parent.width - insetA - insetB) : 1
                height: root.isHorizontalLight ? 1 : Math.max(0, parent.height - insetA - insetB)
                antialiasing: true

                gradient: Gradient {
                    orientation: root.isHorizontalLight ? Gradient.Horizontal : Gradient.Vertical

                    GradientStop {
                        position: 0
                        color: "transparent"
                    }

                    GradientStop {
                        position: 0.12
                        color: Qt.rgba(1, 1, 1, 0.35 * root.rimIllumination)
                    }

                    GradientStop {
                        position: 0.5
                        color: Qt.rgba(1, 1, 1, 0.52 * root.rimIllumination)
                    }

                    GradientStop {
                        position: 0.88
                        color: Qt.rgba(1, 1, 1, 0.35 * root.rimIllumination)
                    }

                    GradientStop {
                        position: 1
                        color: "transparent"
                    }

                }

            }

            // ─────────────────────────────────────────────────────────────────
            // Lower Ambient Bounce Chamfer
            // ─────────────────────────────────────────────────────────────────
            Rectangle {
                id: illuminatedBottomEdge

                readonly property real insetA: root.isHorizontalLight ? Math.max(4, Math.round(root.effectiveBottomLeftRadius * 0.5)) : Math.max(4, Math.round(root.effectiveTopRightRadius * 0.5))
                readonly property real insetB: root.isHorizontalLight ? Math.max(4, Math.round(root.effectiveBottomRightRadius * 0.5)) : Math.max(4, Math.round(root.effectiveBottomRightRadius * 0.5))

                visible: root.mode === "liquid" || root.mode === "clear"
                x: root.isHorizontalLight ? insetA : (root.lightEdge === "left" ? Math.max(1, parent.width - 2) : 1)
                y: root.isHorizontalLight ? (root.lightEdge === "top" ? Math.max(1, parent.height - 2) : 1) : insetA
                width: root.isHorizontalLight ? Math.max(0, parent.width - insetA - insetB) : 1
                height: root.isHorizontalLight ? 1 : Math.max(0, parent.height - insetA - insetB)
                antialiasing: true

                gradient: Gradient {
                    orientation: root.isHorizontalLight ? Gradient.Horizontal : Gradient.Vertical

                    GradientStop {
                        position: 0
                        color: "transparent"
                    }

                    GradientStop {
                        position: 0.2
                        color: Qt.rgba(1, 1, 1, 0.08 * root.rimIllumination)
                    }

                    GradientStop {
                        position: 0.8
                        color: Qt.rgba(1, 1, 1, 0.08 * root.rimIllumination)
                    }

                    GradientStop {
                        position: 1
                        color: "transparent"
                    }

                }

            }

            // ─────────────────────────────────────────────────────────────────
            // Content Container
            // ─────────────────────────────────────────────────────────────────
            Item {
                id: contentContainer

                anchors.fill: parent
            }

            Behavior on border.color {
                ColorAnimation {
                    duration: 150
                }

            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: root.isPressed ? 80 : 180
                easing.type: root.isPressed ? Easing.OutQuad : Easing.OutBack
                easing.overshoot: root.isPressed ? 1 : 1.25
            }

        }

    }

}
