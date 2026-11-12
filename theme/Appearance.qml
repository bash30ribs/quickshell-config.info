import QtQuick
import Quickshell
pragma Singleton

QtObject {
    // Lateral prism refraction

    id: root

    // Bar dimensions and layout
    property int barHeight: Math.max(26, Math.round(Fonts.baseTextSize * 2.5))
    property int barVerticalWidth: Math.max(40, Math.round(Fonts.baseTextSize * 3.5))
    property int barRadius: 16
    property int barMarginHorizontal: 12
    property int barSpacing: 4
    property int barSectionSpacing: 8
    property int barButtonHeight: barHeight - 4
    property bool barVisible: true
    property string barEdge: "top" // "top" | "bottom" | "left" | "right"
    property bool barTransitioning: false
    readonly property bool barIsVertical: root.barEdge === "left" || root.barEdge === "right"
    readonly property bool barIsHorizontal: !root.barIsVertical
    readonly property bool barIsTop: root.barEdge === "top"
    readonly property bool barIsBottom: root.barEdge === "bottom"
    readonly property bool barIsLeft: root.barEdge === "left"
    readonly property bool barIsRight: root.barEdge === "right"
    readonly property int barThickness: root.barIsVertical ? root.barVerticalWidth : root.barHeight
    // =========================================================================
    // Apple macOS Liquid Glass Optical Settings (qt-liquid-glass Specification)
    // =========================================================================
    property string glassMode: "liquid"
    // "liquid", "frosted", "clear", "flat"
    property string glassMaterial: "controlCenter"
    // "controlCenter", "widgets", "clearGlass", "sidebar", "chromatic"
    property real glassClarity: 0.75
    // Apple liquid clarity
    property real glassRimIllumination: 0.5
    // Specular crest illumination
    property real glassSpecularIntensity: 0.75
    // Top specular sheen
    property real glassRefractionStrength: 0.85
    // Chromatic dispersion & lensing
    property real glassInnerBevel: 0.55
    // Inset chamfer light catch
    property real glassChromaticDispersion: 0.6
    // Mornye Spring Physics Settings (mornye_glass_press.dart)
    property real springMass: 1
    property real springStiffness: 420
    property real springDamping: 24
    // =========================================================================
    // Border Toggles (off by default)
    // =========================================================================
    // Bar border toggle
    property bool barBorder: false
    // Polkit password input border toggle (off by default)
    property bool polkitInputBorder: false
    property alias polkitBorder: root.polkitInputBorder
    // PowerMenu power switch / action buttons border toggle (off by default)
    property bool powerMenuSwitchBorder: false
    property alias powerMenuPowerSwitchBorder: root.powerMenuSwitchBorder
    property alias powerSwitchBorder: root.powerMenuSwitchBorder
    // Theme Switcher individual theme card border toggle (off by default)
    property bool themeSwitcherCardBorder: false
    property alias themeCardBorder: root.themeSwitcherCardBorder
    property alias themeSwitcherThemeBorder: root.themeSwitcherCardBorder
    // Wallpaper Switcher card border toggle (off by default)
    property bool wallpaperSwitcherCardBorder: true
    property alias wallpaperCardBorder: root.wallpaperSwitcherCardBorder
    // Bar widget display options
    property bool batteryShowPercentage: true
    property bool batteryShowCycles: true
    property bool batteryShowHealth: true
    property int batteryCycleOverride: 0
    // Individual bar widget icon sizes (px) - adaptively scaled with global text size
    property int barIconSize: Icons.barIconSize
    property int batteryIconSize: Math.max(14, Math.round(Fonts.baseTextSize * (22 / 12)))
    property int audioIconSize: root.barIconSize
    property int bluetoothIconSize: root.barIconSize
    property int networkIconSize: root.barIconSize
    property int monitorIconSize: root.barIconSize
    // Hyprland Workspaces Indicator Controls - adaptively scaled with global text size
    property int workspacesPaddingHorizontal: Math.max(2, Math.round(Fonts.baseTextSize * (4 / 12)))
    property int workspacesPaddingVertical: Math.max(2, Math.round(Fonts.baseTextSize * (3 / 12)))
    property int workspacesMargin: 0
    property int workspacesSpacing: Math.max(2, Math.round(Fonts.baseTextSize * (4 / 12)))
    property int workspacesDotSize: Math.max(4, Math.round(Fonts.baseTextSize * (7 / 12)))
    property int workspacesStarSize: Math.max(8, Math.round(Fonts.baseTextSize * (14 / 12)))
    property int workspacesIconSize: root.workspacesStarSize
    property int workspacesInactiveIconSize: Math.max(6, Math.round(Fonts.baseTextSize * (11 / 12)))
    property int workspacesIconOffsetX: 0
    property int workspacesIconOffsetY: 0
    property int workspacesCapsuleWidth: Math.max(16, Math.round(Fonts.baseTextSize * (24 / 12)))
    property int workspacesActiveCapsuleWidth: Math.max(30, Math.round(Fonts.baseTextSize * (46 / 12)))
    // =========================================================================
    // Corner Radii
    // =========================================================================
    property int radiusXs: 2
    property int radiusSmall: 4
    property int radiusMedium: 8
    property int radiusLarge: 12
    property int radiusXl: 14
    property int radiusPill: 24
    // Semantic component radii
    property int buttonRadius: root.radiusSmall
    property int popupRadius: root.radiusMedium
    property int cardRadius: root.radiusLarge
    property int dialogRadius: root.radiusXl
    property int surfaceRadius: 10
    // =========================================================================
    // Borders & Outlines
    // =========================================================================
    property int borderWidthNone: 0
    property int borderWidthThin: 1
    property int borderWidthMedium: 2
    property int borderWidthThick: 3
    property int defaultBorderWidth: root.borderWidthThin
    // =========================================================================
    // Padding & Spacing
    // =========================================================================
    property int spacingXs: 2
    property int spacingSmall: 4
    property int spacingMedium: 8
    property int spacingLarge: 12
    property int spacingXl: 16
    property int paddingSmall: 6
    property int paddingMedium: 10
    property int paddingLarge: 14
    property int paddingXl: 20
    // Popup card geometry
    property int popupPadding: 12
    property int popupMargin: 8
    property int popupHeaderHeight: 38
    // =========================================================================
    // Button & Control Dimensions
    // =========================================================================
    property int buttonHeight: 32
    property int buttonPadding: 8
    // =========================================================================
    // Sliders
    // =========================================================================
    // Standard popup slider
    property int sliderWidth: 260
    property int sliderHeight: 34
    property int sliderTrackHeight: 8
    property int sliderTrackRadius: 4
    property int sliderKnobSize: 16
    property int sliderKnobRadius: 8
    property int sliderKnobBorderWidth: 2
    property int sliderSpacing: 10
    // Compact audio mixer slider
    property int audioSliderHeight: 22
    property int audioSliderTrackHeight: 4
    property int audioSliderTrackRadius: 2
    // =========================================================================
    // Toggle Switches
    // =========================================================================
    property int toggleTrackWidth: 40
    property int toggleTrackHeight: 22
    property int toggleTrackRadius: 2
    property int toggleThumbSize: 16
    property int toggleThumbRadius: 2
    property int toggleBorderWidth: 1
    // =========================================================================
    // On-Screen Display (OSD)
    // =========================================================================
    property int osdHeight: 48
    property int osdRadius: 24
    property int osdBottomMargin: (root.barVisible && root.barIsBottom) ? (root.barHeight + 24) : 64
    property int osdSpacing: 14
    property int osdTrackWidth: 140
    property int osdTrackHeight: 6
    property int osdTrackRadius: 3
    // =========================================================================
    // Notifications
    // =========================================================================
    property int notificationWidth: 380
    property int notificationRadius: root.radiusLarge
    property int notificationRightMargin: 16
    property int notificationTopMargin: (root.barVisible && root.barIsTop ? root.barHeight : 0) + 12
    property int notificationSpacing: 8
    property int notificationUrgencyStripWidth: 4
    // =========================================================================
    // Application Launcher
    // =========================================================================
    property int launcherWidth: 620
    property int launcherHeight: 460
    property int launcherModalWidth: 700
    property int launcherModalHeight: 468
    property int launcherRadius: 20
    property int launcherPadding: 16
    property int launcherItemHeight: 42
    property int launcherItemRadius: 10
    property int launcherIconSize: Math.max(16, Math.round(Fonts.baseTextSize * (24 / 12)))
    // =========================================================================
    // Power & Unified Menu
    // =========================================================================
    property int powerMenuRadiusActive: 14
    property int powerMenuRadiusInactive: 32
    property int powerMenuWidthPower: 380
    property int powerMenuHeightPower: 146
    property int powerMenuHeightTheme: 254
    property int powerMenuHeightWallpaper: 202
    // =========================================================================
    // Media Controls & Pills
    // =========================================================================
    property int mediaPillHeight: 28
    property int mediaPillRadius: root.radiusMedium
    property int mediaPopupWidth: 350
    property int mediaPopupHeight: 195
    property int mediaIslandWidth: 340
    property int mediaIslandHeight: 140
    property int mediaIslandRadius: 22
    // =========================================================================
    // Clipboard Drawer (Bar Pull-Down Shade)
    // =========================================================================
    property int clipboardWidth: 740
    property int clipboardHeight: 504
    property int clipboardRadius: 20
    property int clipboardPadding: 14
    property int clipboardThumbWidth: 168
    property int clipboardThumbHeight: 98
    // =========================================================================
    // Opacity & Transparency Tokens
    // =========================================================================
    property real baseOpacity: 0.62
    property real elevatedOpacity: 0.88
    property real layerOpacity: 0.28
    property real scrimOpacity: 0.35
    property real subtleOpacity: 0.6
    property real disabledOpacity: 0.38
    // =========================================================================
    // Animation Durations (ms)
    // =========================================================================
    property int animDurationFast: 100
    property int animDurationNormal: 150
    property int animDurationMedium: 200
    property int animDurationSlow: 250
    property int animDurationSpring: 320

    signal closeBarPopups()

    function computeBarScreenOrigin(anchorItem, fallbackW, fallbackH) {
        if (!anchorItem)
            return Qt.point(0, 0);

        var win = (anchorItem.QsWindow && anchorItem.QsWindow.window) ? anchorItem.QsWindow.window : null;
        if (!win)
            return Qt.point(0, 0);

        var screenW = win.screen ? win.screen.width : fallbackW;
        var screenH = win.screen ? win.screen.height : fallbackH;
        var bx = 0;
        var by = 0;
        if (win.anchors && win.anchors.left && win.anchors.right)
            bx = (win.margins && win.margins.left) ? win.margins.left : 0;
        else if (win.anchors && win.anchors.left)
            bx = (win.margins && win.margins.left) ? win.margins.left : 0;
        else if (win.anchors && win.anchors.right)
            bx = screenW - win.width - ((win.margins && win.margins.right) ? win.margins.right : 0);
        else
            bx = Math.round((screenW - win.width) / 2);
        if (win.anchors && win.anchors.top && win.anchors.bottom)
            by = (win.margins && win.margins.top) ? win.margins.top : 0;
        else if (win.anchors && win.anchors.top)
            by = (win.margins && win.margins.top) ? win.margins.top : 0;
        else if (win.anchors && win.anchors.bottom)
            by = screenH - win.height - ((win.margins && win.margins.bottom) ? win.margins.bottom : 0);
        else
            by = Math.round((screenH - win.height) / 2);
        return Qt.point(bx, by);
    }

    function computeBarPopupPos(anchorItem, contentW, contentH, margin, fallbackW, fallbackH) {
        var gap = 6;
        if (!anchorItem)
            return Qt.point(margin, root.barHeight + gap);

        var win = (anchorItem.QsWindow && anchorItem.QsWindow.window) ? anchorItem.QsWindow.window : null;
        var screenW = (win && win.screen) ? win.screen.width : fallbackW;
        var screenH = (win && win.screen) ? win.screen.height : fallbackH;
        var origin = root.computeBarScreenOrigin(anchorItem, fallbackW, fallbackH);
        var pt = anchorItem.mapToItem(null, 0, 0);
        var px = margin;
        var py = root.barHeight + gap;
        if (root.barIsLeft) {
            var barRight = origin.x + (win ? win.width : root.barThickness);
            px = Math.min(screenW - contentW - margin, barRight + gap);
            var cyL = origin.y + pt.y + (anchorItem.height / 2);
            py = Math.max(margin, Math.min(cyL - (contentH / 2), screenH - contentH - margin));
        } else if (root.barIsRight) {
            px = Math.max(margin, origin.x - contentW - gap);
            var cyR = origin.y + pt.y + (anchorItem.height / 2);
            py = Math.max(margin, Math.min(cyR - (contentH / 2), screenH - contentH - margin));
        } else if (root.barIsBottom) {
            var cxB = origin.x + pt.x + (anchorItem.width / 2);
            px = Math.max(margin, Math.min(cxB - (contentW / 2), screenW - contentW - margin));
            py = Math.max(margin, origin.y - contentH - gap);
        } else {
            var cxT = origin.x + pt.x + (anchorItem.width / 2);
            px = Math.max(margin, Math.min(cxT - (contentW / 2), screenW - contentW - margin));
            var barBottom = origin.y + (win ? win.height : root.barHeight);
            py = Math.max(root.barHeight + gap, barBottom + gap);
        }
        return Qt.point(px, py);
    }

}
