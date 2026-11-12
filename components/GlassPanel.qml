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
            // Calibrated to let Hyprland dual-kawase blur shine through vibrantly
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
                    return Theme.withAlpha(Theme.bright_foreground, 0.32);

                return Theme.glassBorder;
            }

            Gradient {
                id: liquidGradient

                // Position 0.0: Soft curved glass crest (merges organically without a harsh top stripe)
                GradientStop {
                    position: 0
                    color: {
                        var baseA = Theme.isLightWallpaper ? 0.26 : ((root.mode === "liquid" || root.mode === "clear") ? 0.16 : 0.2);
                        var c = Theme.withAlpha(Theme.dark_background, baseA * (1 - (root.clarity - 0.75) * 0.3));
                        c = Qt.tint(c, Theme.withAlpha(root.accentTint, root.active ? 0.2 : 0.07));
                        var sheenMix = (root.mode === "liquid" || root.mode === "clear") ? (0.045 * root.specularIntensity) : 0.03;
                        if (root.isHovered)
                            sheenMix += 0.025;

                        return Qt.tint(c, Qt.rgba(1, 1, 1, sheenMix));
                    }
                }

                // Position 0.14: Smooth optical transition into translucent body
                GradientStop {
                    position: 0.14
                    color: {
                        var baseA = Theme.isLightWallpaper ? 0.3 : ((root.mode === "liquid" || root.mode === "clear") ? 0.19 : 0.23);
                        var c = Theme.withAlpha(Theme.dark_background, baseA * (1 - (root.clarity - 0.75) * 0.3));
                        c = Qt.tint(c, Theme.withAlpha(root.accentTint, root.active ? 0.2 : 0.07));
                        return c;
                    }
                }

                // Position 0.50: Translucent body allowing Hyprland dual-kawase blur to glow through
                GradientStop {
                    position: 0.5
                    color: {
                        var baseA = Theme.isLightWallpaper ? 0.34 : ((root.mode === "liquid" || root.mode === "clear") ? 0.22 : 0.26);
                        var c = Theme.withAlpha(root.baseColor, baseA * (1 - (root.clarity - 0.75) * 0.3));
                        c = Qt.tint(c, Theme.withAlpha(root.accentTint, root.active ? 0.24 : 0.08));
                        return c;
                    }
                }

                // Position 1.0: Lower ambient base
                GradientStop {
                    position: 1
                    color: {
                        var baseA = Theme.isLightWallpaper ? 0.4 : ((root.mode === "liquid" || root.mode === "clear") ? 0.28 : 0.32);
                        var c = Theme.withAlpha(Theme.dark_background, baseA * (1 - (root.clarity - 0.75) * 0.3));
                        c = Qt.tint(c, Theme.withAlpha(root.accentTint, root.active ? 0.2 : 0.05));
                        return c;
                    }
                }

            }

            // ─────────────────────────────────────────────────────────────────
            // Curved Edge Specular Diffuse Sheen (follows active lightEdge)
            // ─────────────────────────────────────────────────────────────────
            Rectangle {
                id: specularSheen

                readonly property real bandSize: root.isHorizontalLight ? Math.max(10, Math.min(26, parent.height * 0.26)) : Math.max(8, Math.min(18, parent.width * 0.32))
                readonly property bool reverseStops: root.lightEdge === "bottom" || root.lightEdge === "right"

                visible: !root.isPill && (root.mode === "liquid" || root.mode === "clear")
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
                        color: specularSheen.reverseStops ? "transparent" : Qt.rgba(1, 1, 1, 0.045 * root.specularIntensity)
                    }

                    GradientStop {
                        position: 0.48
                        color: Qt.rgba(1, 1, 1, 0.015 * root.specularIntensity)
                    }

                    GradientStop {
                        position: 1
                        color: specularSheen.reverseStops ? Qt.rgba(1, 1, 1, 0.045 * root.specularIntensity) : "transparent"
                    }

                }

            }

            // ─────────────────────────────────────────────────────────────────
            // Feathered Edge Rim Catch (merges invisibly into corner arcs)
            // ─────────────────────────────────────────────────────────────────
            Rectangle {
                id: illuminatedTopEdge

                readonly property real insetA: root.isHorizontalLight ? Math.max(2, Math.round((root.lightEdge === "top" ? root.effectiveTopLeftRadius : root.effectiveBottomLeftRadius) * 0.4)) : Math.max(2, Math.round((root.lightEdge === "left" ? root.effectiveTopLeftRadius : root.effectiveTopRightRadius) * 0.4))
                readonly property real insetB: root.isHorizontalLight ? Math.max(2, Math.round((root.lightEdge === "top" ? root.effectiveTopRightRadius : root.effectiveBottomRightRadius) * 0.4)) : Math.max(2, Math.round((root.lightEdge === "left" ? root.effectiveBottomLeftRadius : root.effectiveBottomRightRadius) * 0.4))

                visible: !root.isPill && (root.mode === "liquid" || root.mode === "clear")
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
                        position: 0.16
                        color: Qt.rgba(1, 1, 1, 0.15 * root.rimIllumination)
                    }

                    GradientStop {
                        position: 0.84
                        color: Qt.rgba(1, 1, 1, 0.15 * root.rimIllumination)
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
