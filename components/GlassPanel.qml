import QtQuick
import Quickshell
import "../theme"

Item {
    id: root

    // ─────────────────────────────────────────────────────────────────────────
    // Mornye Glass Material Specification
    // Reusable Glass Panel with Liquid / Frosted / Flat Quality Tiers
    // ─────────────────────────────────────────────────────────────────────────

    // Mode: "liquid" (Mode C: specular + refraction sheen + illuminated rim),
    //       "frosted" (Mode B: dual-kawase blur + clean gradient),
    //       "flat"    (Mode A: opaque performance fallback)
    property string mode: Appearance.glassMode || "liquid"

    // Geometry
    property int radius: Appearance.popupRadius > 0 ? Appearance.popupRadius : 14
    property int topLeftRadius: -1
    property int topRightRadius: -1
    property int bottomLeftRadius: -1
    property int bottomRightRadius: -1

    readonly property int effectiveTopLeftRadius: topLeftRadius >= 0 ? topLeftRadius : radius
    readonly property int effectiveTopRightRadius: topRightRadius >= 0 ? topRightRadius : radius
    readonly property int effectiveBottomLeftRadius: bottomLeftRadius >= 0 ? bottomLeftRadius : radius
    readonly property int effectiveBottomRightRadius: bottomRightRadius >= 0 ? bottomRightRadius : radius

    // Mornye Glass Optical Settings
    property real clarity: Appearance.glassClarity !== undefined ? Appearance.glassClarity : 0.75
    property real rimIllumination: Appearance.glassRimIllumination !== undefined ? Appearance.glassRimIllumination : 0.45
    property real specularIntensity: Appearance.glassSpecularIntensity !== undefined ? Appearance.glassSpecularIntensity : 0.70
    property real refractionStrength: Appearance.glassRefractionStrength !== undefined ? Appearance.glassRefractionStrength : 0.85

    // Interactive Spring States (Mornye Spring: Mass 1, Stiffness 420, Damping 24)
    property bool interactive: false
    property bool isHovered: false
    property bool isPressed: false
    property bool active: false

    // Color Tinting
    property color baseColor: Theme.background
    property color accentTint: Theme.accent

    // Child Content Reparenting
    default property alias content: contentContainer.data

    implicitWidth: 100
    implicitHeight: 100

    // ─────────────────────────────────────────────────────────────────────────
    // Mornye Spring Physics Scale & Compression Container
    // ─────────────────────────────────────────────────────────────────────────
    Item {
        id: surfaceContainer
        anchors.fill: parent

        scale: {
            if (!root.interactive) return 1.0
            if (root.isPressed) return 0.965
            if (root.isHovered) return 1.025
            return 1.0
        }

        Behavior on scale {
            NumberAnimation {
                duration: root.isPressed ? 80 : 180
                easing.type: root.isPressed ? Easing.OutQuad : Easing.OutBack
                easing.overshoot: root.isPressed ? 1.0 : 1.25
            }
        }

        // ─────────────────────────────────────────────────────────────────────
        // Master Glass Surface Rectangle
        // ─────────────────────────────────────────────────────────────────────
        Rectangle {
            id: glassSurface
            anchors.fill: parent
            topLeftRadius: root.effectiveTopLeftRadius
            topRightRadius: root.effectiveTopRightRadius
            bottomLeftRadius: root.effectiveBottomLeftRadius
            bottomRightRadius: root.effectiveBottomRightRadius
            antialiasing: true

            // Color & Translucency based on Quality Tier
            color: {
                if (root.mode === "flat") {
                    return Theme.darker_background
                }
                return "transparent"
            }

            // Mode C (Liquid) and Mode B (Frosted) Multi-stop Lens Gradient
            gradient: root.mode === "flat" ? null : liquidGradient

            Gradient {
                id: liquidGradient
                // Position 0.0: Top specular reflection highlight
                GradientStop {
                    position: 0.0
                    color: {
                        var alpha = (root.mode === "liquid")
                            ? (0.12 + (0.06 * root.specularIntensity))
                            : 0.10
                        if (root.isHovered) alpha += 0.04
                        return Qt.rgba(1, 1, 1, alpha)
                    }
                }
                // Position 0.05: Refraction bend shelf
                GradientStop {
                    position: 0.05
                    color: {
                        var baseAlpha = (root.mode === "liquid") ? 0.35 : 0.38
                        var c = Theme.withAlpha(Theme.lighter_background, baseAlpha)
                        if (root.active) c = Qt.tint(c, Theme.withAlpha(root.accentTint, 0.15))
                        return c
                    }
                }
                // Position 0.55: Smoked translucent core
                GradientStop {
                    position: 0.55
                    color: {
                        var baseAlpha = (root.mode === "liquid") ? 0.42 : 0.44
                        var c = Theme.withAlpha(root.baseColor, baseAlpha)
                        if (root.active) c = Qt.tint(c, Theme.withAlpha(root.accentTint, 0.18))
                        return c
                    }
                }
                // Position 1.0: Deep ambient lower refraction boundary
                GradientStop {
                    position: 1.0
                    color: {
                        var baseAlpha = (root.mode === "liquid") ? 0.48 : 0.50
                        var c = Theme.withAlpha(Theme.dark_background, baseAlpha)
                        if (root.active) c = Qt.tint(c, Theme.withAlpha(root.accentTint, 0.20))
                        return c
                    }
                }
            }

            // ─────────────────────────────────────────────────────────────────
            // Illuminated Rim Stroke (Mornye directional boundary illumination)
            // ─────────────────────────────────────────────────────────────────
            border.width: 1
            border.color: {
                if (root.mode === "flat") return Theme.withAlpha(Theme.foreground, 0.15)
                if (root.active) return Theme.withAlpha(root.accentTint, 0.65)
                if (root.isHovered) return Theme.withAlpha(Theme.bright_foreground, 0.32)
                return Theme.glassBorder
            }

            Behavior on border.color {
                ColorAnimation { duration: 150 }
            }

            // ─────────────────────────────────────────────────────────────────
            // Directional Top Specular Sheen (Diffusely curves with the squircle)
            // ─────────────────────────────────────────────────────────────────
            Rectangle {
                id: specularSheen
                visible: root.mode === "liquid"
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: Math.max(6, Math.min(14, parent.height * 0.28))
                topLeftRadius: parent.topLeftRadius
                topRightRadius: parent.topRightRadius
                bottomLeftRadius: 0
                bottomRightRadius: 0
                antialiasing: true

                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: Qt.rgba(1, 1, 1, 0.09 * root.specularIntensity)
                    }
                    GradientStop {
                        position: 1.0
                        color: "transparent"
                    }
                }
            }

            // ─────────────────────────────────────────────────────────────────
            // Thin Illuminated Top Rim Highlight Line (1px specular edge catch)
            // ─────────────────────────────────────────────────────────────────
            Rectangle {
                id: illuminatedTopEdge
                visible: root.mode === "liquid"
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
        }
    }
}
