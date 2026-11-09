import QtQuick
import Quickshell
import "../theme"

Item {
    id: root

    // ─────────────────────────────────────────────────────────────────────────
    // Apple macOS Liquid Glass Material Specification (qt-liquid-glass)
    // Multi-tier optical surface: Liquid / Frosted / Clear / Flat
    // ─────────────────────────────────────────────────────────────────────────

    // Mode: "liquid"  (Apple Liquid Glass: chromatic refraction + content lensing + specular crest),
    //       "frosted" (Apple Control Center / Widgets frosted blur),
    //       "clear"   (Apple ClearGlass: crisp transparent crystal refraction),
    //       "flat"    (Apple WindowBackground: opaque solid fallback)
    property string mode: Appearance.glassMode || "liquid"

    // Material preset: "controlCenter", "widgets", "clearGlass", "sidebar", "chromatic"
    property string material: Appearance.glassMaterial || "controlCenter"

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

    // Apple Liquid Glass Optical Parameters
    property real clarity: Appearance.glassClarity !== undefined ? Appearance.glassClarity : 0.75
    property real rimIllumination: Appearance.glassRimIllumination !== undefined ? Appearance.glassRimIllumination : 0.50
    property real specularIntensity: Appearance.glassSpecularIntensity !== undefined ? Appearance.glassSpecularIntensity : 0.75
    property real refractionStrength: Appearance.glassRefractionStrength !== undefined ? Appearance.glassRefractionStrength : 0.85
    property real innerBevelStrength: Appearance.glassInnerBevel !== undefined ? Appearance.glassInnerBevel : 0.55
    property real chromaticStrength: Appearance.glassChromaticDispersion !== undefined ? Appearance.glassChromaticDispersion : 0.60

    // Interaction State (qt-liquid-glass InteractionState::Normal vs Hovered)
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
    // Physical Spring Physics Scale & Compression Container (m=1.0, k=420, c=24)
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
        // Master Glass Surface Rectangle (Dual-Kawase Compositor Blur Sampled)
        // ─────────────────────────────────────────────────────────────────────
        Rectangle {
            id: glassSurface
            anchors.fill: parent
            topLeftRadius: root.effectiveTopLeftRadius
            topRightRadius: root.effectiveTopRightRadius
            bottomLeftRadius: root.effectiveBottomLeftRadius
            bottomRightRadius: root.effectiveBottomRightRadius
            antialiasing: true

            // Base color for flat fallback vs transparent for blur sampling
            color: {
                if (root.mode === "flat") return Theme.darker_background
                return "transparent"
            }

            // Apple Refraction Lens Multi-stop Gradient
            gradient: root.mode === "flat" ? null : liquidGradient

            Gradient {
                id: liquidGradient

                // Stop 0.0: Top Specular Crest catch
                GradientStop {
                    position: 0.0
                    color: {
                        if (root.mode === "clear") return Qt.rgba(1, 1, 1, 0.16 + (0.08 * root.specularIntensity))
                        var alpha = (root.mode === "liquid")
                            ? (0.13 + (0.07 * root.specularIntensity))
                            : 0.10
                        if (root.isHovered) alpha += 0.05
                        return Qt.rgba(1, 1, 1, alpha)
                    }
                }

                // Stop 0.05: Refractive transition shelf
                GradientStop {
                    position: 0.05
                    color: {
                        if (root.mode === "clear") return Theme.withAlpha(Theme.lighter_background, 0.12)
                        var baseAlpha = (root.mode === "liquid") ? 0.32 : 0.36
                        var c = Theme.withAlpha(Theme.lighter_background, baseAlpha)
                        if (root.active) c = Qt.tint(c, Theme.withAlpha(root.accentTint, 0.16))
                        return c
                    }
                }

                // Stop 0.50: Apple Smoked Translucent Core (allows vivid compositor blur)
                GradientStop {
                    position: 0.50
                    color: {
                        if (root.mode === "clear") return Theme.withAlpha(root.baseColor, 0.15)
                        var baseAlpha = (root.mode === "liquid") ? 0.38 : 0.42
                        var c = Theme.withAlpha(root.baseColor, baseAlpha)
                        if (root.active) c = Qt.tint(c, Theme.withAlpha(root.accentTint, 0.18))
                        return c
                    }
                }

                // Stop 1.0: Deep ambient lower refraction boundary
                GradientStop {
                    position: 1.0
                    color: {
                        if (root.mode === "clear") return Theme.withAlpha(Theme.dark_background, 0.20)
                        var baseAlpha = (root.mode === "liquid") ? 0.46 : 0.48
                        var c = Theme.withAlpha(Theme.dark_background, baseAlpha)
                        if (root.active) c = Qt.tint(c, Theme.withAlpha(root.accentTint, 0.22))
                        return c
                    }
                }
            }

            // ─────────────────────────────────────────────────────────────────
            // Apple Directional Border Stroke
            // ─────────────────────────────────────────────────────────────────
            border.width: 1
            border.color: {
                if (root.mode === "flat") return Theme.withAlpha(Theme.foreground, 0.15)
                if (root.active) return Theme.withAlpha(root.accentTint, 0.65)
                if (root.isHovered) return Theme.withAlpha(Theme.bright_foreground, 0.35)
                return Theme.glassBorder
            }

            Behavior on border.color {
                ColorAnimation { duration: 150 }
            }

            // ─────────────────────────────────────────────────────────────────
            // 1. Apple Chromatic Dispersion (Lateral Prism Refraction Fringing)
            // Simulates Material::Chromatic from qt-liquid-glass
            // ─────────────────────────────────────────────────────────────────
            Rectangle {
                id: chromaticDispersion
                visible: root.mode === "liquid" || root.material === "chromatic"
                anchors.fill: parent
                topLeftRadius: parent.topLeftRadius
                topRightRadius: parent.topRightRadius
                bottomLeftRadius: parent.bottomLeftRadius
                bottomRightRadius: parent.bottomRightRadius
                antialiasing: true
                color: "transparent"

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0.0
                        color: Qt.rgba(1.0, 0.82, 0.63, 0.05 * root.chromaticStrength * root.refractionStrength)
                    }
                    GradientStop {
                        position: 0.22
                        color: "transparent"
                    }
                    GradientStop {
                        position: 0.78
                        color: "transparent"
                    }
                    GradientStop {
                        position: 1.0
                        color: Qt.rgba(0.67, 0.84, 1.0, 0.05 * root.chromaticStrength * root.refractionStrength)
                    }
                }
            }

            // ─────────────────────────────────────────────────────────────────
            // 2. Apple Inset Chamfer Bevel (Content Lensing Perimeter Highlight)
            // ─────────────────────────────────────────────────────────────────
            Rectangle {
                id: innerBevel
                visible: root.mode === "liquid" || root.mode === "frosted" || root.mode === "clear"
                anchors.fill: parent
                anchors.margins: 1
                topLeftRadius: Math.max(0, parent.topLeftRadius - 1)
                topRightRadius: Math.max(0, parent.topRightRadius - 1)
                bottomLeftRadius: Math.max(0, parent.bottomLeftRadius - 1)
                bottomRightRadius: Math.max(0, parent.bottomRightRadius - 1)
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, (root.isHovered ? 0.12 : 0.07) * root.innerBevelStrength)
                antialiasing: true

                Behavior on border.color {
                    ColorAnimation { duration: 150 }
                }
            }

            // ─────────────────────────────────────────────────────────────────
            // 3. Directional Top Specular Sheen (Curved overhead lighting)
            // ─────────────────────────────────────────────────────────────────
            Rectangle {
                id: specularSheen
                visible: root.mode === "liquid" || root.mode === "clear"
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
                        color: Qt.rgba(1, 1, 1, (root.isHovered ? 0.14 : 0.09) * root.specularIntensity)
                    }
                    GradientStop {
                        position: 1.0
                        color: "transparent"
                    }
                }
            }

            // ─────────────────────────────────────────────────────────────────
            // 4. Apple Thin Specular Crest Line (1px illuminated top boundary catch)
            // ─────────────────────────────────────────────────────────────────
            Rectangle {
                id: illuminatedTopEdge
                visible: root.mode === "liquid" || root.mode === "clear"
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Math.min(parent.topLeftRadius, 8)
                anchors.rightMargin: Math.min(parent.topRightRadius, 8)
                height: 1
                color: Qt.rgba(1, 1, 1, (root.isHovered ? 0.36 : 0.25) * root.rimIllumination)
                antialiasing: true

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }

            // ─────────────────────────────────────────────────────────────────
            // 5. Apple Ambient Bottom Occlusion Edge (1px physical grounding line)
            // ─────────────────────────────────────────────────────────────────
            Rectangle {
                id: bottomEdgeShadow
                visible: (root.mode === "liquid" || root.mode === "frosted" || root.mode === "clear") && parent.height > 10
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Math.min(parent.bottomLeftRadius, 8)
                anchors.rightMargin: Math.min(parent.bottomRightRadius, 8)
                height: 1
                color: Qt.rgba(0, 0, 0, 0.28)
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
