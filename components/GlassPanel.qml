import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"

Item {
    id: root

    // ─────────────────────────────────────────────────────────────────────────
    // Quickshell Apple Liquid Glass Panel Component (GLSL 440 ShaderEffect)
    // Inspired by fsalinas26/qt-liquid-glass visual language & Apple Tahoe glass
    // ─────────────────────────────────────────────────────────────────────────

    // Mode: "liquid"  (Full GPU ShaderEffect with Snell's law refraction & specular rim),
    //       "frosted" (Compositor dual-kawase blur with content lensing),
    //       "clear"   (Ultra-high clarity crystal refraction),
    //       "flat"    (High-performance solid fallback)
    property string mode: Appearance.glassMode || "liquid"

    // Material preset: "controlCenter", "widgets", "clearGlass", "sidebar", "chromatic"
    property string material: Appearance.glassMaterial || "controlCenter"

    // Geometry & Squircles
    property int radius: Appearance.barRadius > 0 ? Appearance.barRadius : 16
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
    property real rimIllumination: Appearance.glassRimIllumination !== undefined ? Appearance.glassRimIllumination : 0.50
    property real specularIntensity: Appearance.glassSpecularIntensity !== undefined ? Appearance.glassSpecularIntensity : 0.75
    property real refractionStrength: Appearance.glassRefractionStrength !== undefined ? Appearance.glassRefractionStrength : 0.85
    property real innerBevelStrength: Appearance.glassInnerBevel !== undefined ? Appearance.glassInnerBevel : 0.55
    property real chromaticStrength: Appearance.glassChromaticDispersion !== undefined ? Appearance.glassChromaticDispersion : 0.60

    // Interaction State
    property bool interactive: false
    property bool isHovered: false
    property bool isPressed: false
    property bool active: false

    // Color Tinting
    property color baseColor: Theme.barBackground || Theme.background
    property color accentTint: Theme.accent

    // External Backdrop Source (optional: allows parent to pass a custom ShaderEffectSource)
    property var externalBackdrop: null
    property point backdropOffset: Qt.point(0, 0)

    // Child Content Reparenting
    default property alias content: contentContainer.data

    implicitWidth: 100
    implicitHeight: 100

    readonly property real padAmount: 10
    readonly property real marginAmount: 48
    readonly property url shaderFileUrl: Qt.resolvedUrl("../effects/glass/liquidglass.frag.qsb")

    property bool shaderActive: (root.mode === "liquid" || root.mode === "clear")

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
        // 1. Internal Backdrop Layer (used when no external backdrop is handed in)
        // ─────────────────────────────────────────────────────────────────────
        Item {
            id: localBackdropLayer
            visible: false
            x: -root.marginAmount
            y: -root.marginAmount
            width: root.width + 2 * root.marginAmount
            height: root.height + 2 * root.marginAmount

            Rectangle {
                anchors.fill: parent
                antialiasing: true
                color: "transparent"

                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: Qt.rgba(1, 1, 1, 0.16 + (0.08 * root.specularIntensity))
                    }
                    GradientStop {
                        position: 0.08
                        color: Theme.withAlpha(Theme.lighter_background, 0.36)
                    }
                    GradientStop {
                        position: 0.52
                        color: Theme.withAlpha(root.baseColor, 0.42)
                    }
                    GradientStop {
                        position: 1.0
                        color: Theme.withAlpha(Theme.dark_background, 0.50)
                    }
                }
            }
        }

        // Mipmapped ShaderEffectSource for the 24-tap Gaussian disk sampler
        ShaderEffectSource {
            id: localBackdropSes
            sourceItem: root.externalBackdrop !== null ? null : localBackdropLayer
            hideSource: true
            live: true
            mipmap: true
            visible: false
        }

        // ─────────────────────────────────────────────────────────────────────
        // 2. GLSL Liquid Glass ShaderEffect (Real GPU Snell's Law Refraction)
        // ─────────────────────────────────────────────────────────────────────
        Loader {
            id: shaderLoader
            anchors.fill: parent
            active: root.shaderActive

            sourceComponent: Item {
                ShaderEffect {
                    id: glassShaderItem
                    x: -root.padAmount
                    y: -root.padAmount
                    width: root.width + 2 * root.padAmount
                    height: root.height + 2 * root.padAmount

                    fragmentShader: root.shaderFileUrl

                    onStatusChanged: {
                        if (status === ShaderEffect.Error) {
                            console.warn("[GlassPanel] Shader compilation failed, falling back to procedural surface");
                            root.shaderActive = false;
                        }
                    }

                    // Sampler and sizes
                    property variant src: root.externalBackdrop !== null ? root.externalBackdrop : localBackdropSes
                    property vector2d itemSize: Qt.vector2d(width, height)
                    property vector2d glassSize: Qt.vector2d(root.width, root.height)
                    property vector2d srcSize: root.externalBackdrop !== null
                        ? Qt.vector2d(root.externalBackdrop.width, root.externalBackdrop.height)
                        : Qt.vector2d(localBackdropLayer.width, localBackdropLayer.height)
                    property vector2d srcOffset: root.externalBackdrop !== null
                        ? Qt.vector2d(root.backdropOffset.x - root.padAmount, root.backdropOffset.y - root.padAmount)
                        : Qt.vector2d(root.marginAmount - root.padAmount, root.marginAmount - root.padAmount)

                    // Optical uniform properties
                    property real pad: root.padAmount
                    property real radius: root.radius
                    property real bezel: Math.min(root.height * 0.38, 28)
                    property real thickness: 32.0 * root.refractionStrength
                    property real dispersion: 0.08 * root.chromaticStrength * root.refractionStrength
                    property real blurPx: 2.0
                    property real tintMix: (1.0 - root.clarity) * 0.60
                    property real saturation: 1.35
                    property real dark: 1.0
                    property real debug: 0.0
                    property real rim: root.rimIllumination * (root.isHovered ? 2.2 : 1.7)
                    property real grain: 0.025
                    property real magnify: 0.06 * root.refractionStrength
                    property real shadowAmt: 0.40
                    property real rimTint: root.active ? 1.0 : 0.0
                    property real ringW: 1.2
                    property real flatInner: 0.0
                }
            }
        }

        // ─────────────────────────────────────────────────────────────────────
        // 3. Procedural Surface (Active in Frosted / Flat mode or fallback)
        // ─────────────────────────────────────────────────────────────────────
        Rectangle {
            id: fallbackSurface
            visible: !shaderLoader.active || !root.shaderActive
            anchors.fill: parent
            topLeftRadius: root.effectiveTopLeftRadius
            topRightRadius: root.effectiveTopRightRadius
            bottomLeftRadius: root.effectiveBottomLeftRadius
            bottomRightRadius: root.effectiveBottomRightRadius
            antialiasing: true

            color: {
                if (root.mode === "flat") return Theme.darker_background
                return "transparent"
            }

            gradient: root.mode === "flat" ? null : proceduralGradient

            Gradient {
                id: proceduralGradient

                GradientStop {
                    position: 0.0
                    color: {
                        var alpha = (root.mode === "liquid")
                            ? (0.13 + (0.07 * root.specularIntensity))
                            : 0.10
                        if (root.isHovered) alpha += 0.05
                        return Qt.rgba(1, 1, 1, alpha)
                    }
                }
                GradientStop {
                    position: 0.05
                    color: Theme.withAlpha(Theme.lighter_background, 0.34)
                }
                GradientStop {
                    position: 0.50
                    color: Theme.withAlpha(root.baseColor, 0.40)
                }
                GradientStop {
                    position: 1.0
                    color: Theme.withAlpha(Theme.dark_background, 0.48)
                }
            }

            border.width: 1
            border.color: {
                if (root.mode === "flat") return Theme.withAlpha(Theme.foreground, 0.15)
                if (root.active) return Theme.withAlpha(root.accentTint, 0.65)
                if (root.isHovered) return Theme.withAlpha(Theme.bright_foreground, 0.35)
                return Theme.glassBorder
            }

            // Inset Bevel for fallback
            Rectangle {
                visible: root.mode !== "flat"
                anchors.fill: parent
                anchors.margins: 1
                topLeftRadius: Math.max(0, parent.topLeftRadius - 1)
                topRightRadius: Math.max(0, parent.topRightRadius - 1)
                bottomLeftRadius: Math.max(0, parent.bottomLeftRadius - 1)
                bottomRightRadius: Math.max(0, parent.bottomRightRadius - 1)
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.08 * root.innerBevelStrength)
                antialiasing: true
            }

            // Top specular sheen for fallback
            Rectangle {
                visible: root.mode !== "flat"
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
                        color: Qt.rgba(1, 1, 1, (root.isHovered ? 0.15 : 0.10) * root.specularIntensity)
                    }
                    GradientStop {
                        position: 1.0
                        color: "transparent"
                    }
                }
            }

            // Top illuminated crest line
            Rectangle {
                visible: root.mode !== "flat"
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Math.min(parent.topLeftRadius, 8)
                anchors.rightMargin: Math.min(parent.topRightRadius, 8)
                height: 1
                color: Qt.rgba(1, 1, 1, (root.isHovered ? 0.38 : 0.26) * root.rimIllumination)
                antialiasing: true
            }

            // Bottom edge shadow
            Rectangle {
                visible: root.mode !== "flat" && parent.height > 10
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Math.min(parent.bottomLeftRadius, 8)
                anchors.rightMargin: Math.min(parent.bottomRightRadius, 8)
                height: 1
                color: Qt.rgba(0, 0, 0, 0.30)
                antialiasing: true
            }
        }

        // ─────────────────────────────────────────────────────────────────────
        // 4. Content Container (Reparents all child items)
        // ─────────────────────────────────────────────────────────────────────
        Item {
            id: contentContainer
            anchors.fill: parent
        }
    }
}
