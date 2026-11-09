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

                // Position 0.0: Top rim highlight catch
                GradientStop {
                    position: 0
                    color: {
                        var baseA = (root.mode === "liquid" || root.mode === "clear") ? (0.16 + (0.08 * root.specularIntensity)) : 0.12;
                        if (root.isHovered)
                            baseA += 0.05;

                        return Qt.rgba(1, 1, 1, baseA);
                    }
                }

                // Position 0.07: Upper translucent crest
                GradientStop {
                    position: 0.07
                    color: {
                        var baseA = Theme.isLightWallpaper ? 0.6 : ((root.mode === "liquid" || root.mode === "clear") ? 0.42 : 0.46);
                        var c = Theme.withAlpha(Theme.dark_background, baseA * (1 - (root.clarity - 0.75) * 0.3));
                        if (root.active)
                            c = Qt.tint(c, Theme.withAlpha(root.accentTint, 0.15));

                        return c;
                    }
                }

                // Position 0.50: Translucent body allowing Hyprland dual-kawase blur to glow through
                GradientStop {
                    position: 0.5
                    color: {
                        var baseA = Theme.isLightWallpaper ? 0.72 : ((root.mode === "liquid" || root.mode === "clear") ? 0.52 : 0.56);
                        var c = Theme.withAlpha(root.baseColor, baseA * (1 - (root.clarity - 0.75) * 0.3));
                        if (root.active)
                            c = Qt.tint(c, Theme.withAlpha(root.accentTint, 0.18));

                        return c;
                    }
                }

                // Position 1.0: Lower ambient base
                GradientStop {
                    position: 1
                    color: {
                        var baseA = Theme.isLightWallpaper ? 0.8 : ((root.mode === "liquid" || root.mode === "clear") ? 0.6 : 0.64);
                        var c = Theme.withAlpha(Theme.dark_background, baseA * (1 - (root.clarity - 0.75) * 0.3));
                        if (root.active)
                            c = Qt.tint(c, Theme.withAlpha(root.accentTint, 0.2));

                        return c;
                    }
                }

            }

            // ─────────────────────────────────────────────────────────────────
            // Directional Top Specular Sheen (Apple Control Center diffuse sheen)
            // ─────────────────────────────────────────────────────────────────
            Rectangle {
                id: specularSheen

                visible: (root.mode === "liquid" || root.mode === "clear")
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: Math.max(5, Math.min(14, parent.height * 0.26))
                topLeftRadius: parent.topLeftRadius
                topRightRadius: parent.topRightRadius
                bottomLeftRadius: 0
                bottomRightRadius: 0
                antialiasing: true

                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Qt.rgba(1, 1, 1, 0.09 * root.specularIntensity)
                    }

                    GradientStop {
                        position: 1
                        color: "transparent"
                    }

                }

            }

            // ─────────────────────────────────────────────────────────────────
            // Thin Illuminated Top Rim Highlight Line (1px specular edge catch)
            // ─────────────────────────────────────────────────────────────────
            Rectangle {
                id: illuminatedTopEdge

                visible: (root.mode === "liquid" || root.mode === "clear")
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Math.min(parent.topLeftRadius, 8)
                anchors.rightMargin: Math.min(parent.topRightRadius, 8)
                height: 1
                color: Qt.rgba(1, 1, 1, 0.22 * root.rimIllumination)
                antialiasing: true
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
