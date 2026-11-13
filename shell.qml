//@ pragma IconTheme Adwaita
import QtQuick
import Quickshell
import Quickshell.Io
import "bar"
import "clipboard"
import "components"
import "launcher"
import "notifications"
import "osd"
import "polkit"
import "powermenu"
import "services"
import "theme"

ShellRoot {
    id: root

    // Core Shared Services
    property WorkspacesService workspacesService
    property AudioService audioService
    property BrightnessService brightnessService
    property BatteryService batteryService
    property NetworkService networkService
    property BluetoothService bluetoothService
    property PowerService powerService
    property ThemeSwitcherService themeSwitcherService
    property WallpaperSwitcherService wallpaperSwitcherService
    property AuditService auditService
    property ClipboardService clipboardService
    property HardwareService hardwareService
    readonly property ClipboardDrawer clipboardDrawer: clipboardDrawerWindow

    IpcHandler {
        function toggle() : string {
            Quickshell.execDetached(["qs", "ipc", "call", "barpopups", "toggleControlCenter"]);
            return "ok";
        }

        target: "controlcenter"
    }

    IpcHandler {
        function toggle() : string {
            Appearance.barVisible = !Appearance.barVisible;
            var cmd = "mkdir -p \"$HOME/.config/quickshell\" && printf '%s\\n' \"" + (Appearance.barVisible ? "visible" : "hidden") + "\" > \"$HOME/.config/quickshell/bar-visibility\"";
            Quickshell.execDetached(["sh", "-c", cmd]);
            return Appearance.barVisible ? "visible" : "hidden";
        }

        function hide() : string {
            Appearance.barVisible = false;
            var cmd = "mkdir -p \"$HOME/.config/quickshell\" && printf '%s\\n' \"hidden\" > \"$HOME/.config/quickshell/bar-visibility\"";
            Quickshell.execDetached(["sh", "-c", cmd]);
            return "hidden";
        }

        function show() : string {
            Appearance.barVisible = true;
            var cmd = "mkdir -p \"$HOME/.config/quickshell\" && printf '%s\\n' \"visible\" > \"$HOME/.config/quickshell/bar-visibility\"";
            Quickshell.execDetached(["sh", "-c", cmd]);
            return "visible";
        }

        function isVisible() : string {
            return Appearance.barVisible ? "true" : "false";
        }

        target: "bar"
    }

    IpcHandler {
        function test() : string {
            root.powerService.requestShutdown(null);
            return "ok";
        }

        function cancel() : string {
            root.powerService.cancelConfirm();
            return "ok";
        }

        target: "powerconfirm"
    }

    // App Launcher (Rofi-style Quickshell application launcher)
    AppLauncher {
        id: launcher
    }

    // Pull-Down Clipboard & Screenshot Shade Drawer
    ClipboardDrawer {
        id: clipboardDrawerWindow

        clipboardService: root.clipboardService
    }

    // Power Confirmation Dialog (centered overlay)
    PowerConfirmDialog {
        id: powerConfirm

        powerService: root.powerService
    }

    // Bottom Pop-up Unified Menu (Power Session + Theme Switcher + Wallpaper Switcher)
    PowerMenu {
        id: bottomMenu

        powerService: root.powerService
        themeService: root.themeSwitcherService
        wallpaperService: root.wallpaperSwitcherService
    }

    // Polkit Authentication Agent (centered overlay)
    Polkit {
        id: polkit
    }

    // On-Screen Display (OSD UI Window)
    Osd {
        id: osd

        bluetoothService: root.bluetoothService
        brightnessService: root.brightnessService
    }

    // OSD IPC & Trigger Service (modeled on swayosd-client)
    OsdService {
        id: osdService

        osd: osd
    }

    // Desktop Notifications Service
    Notifications {
        id: notifications
    }

    // Mount Bar on each screen
    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData

            screen: modelData
            workspacesService: root.workspacesService
            audioService: root.audioService
            brightnessService: root.brightnessService
            batteryService: root.batteryService
            networkService: root.networkService
            bluetoothService: root.bluetoothService
            powerService: root.powerService
            clipboardDrawer: root.clipboardDrawer
            hardwareService: root.hardwareService
        }

    }

    workspacesService: WorkspacesService {
    }

    audioService: AudioService {
    }

    brightnessService: BrightnessService {
    }

    batteryService: BatteryService {
    }

    networkService: NetworkService {
    }

    bluetoothService: BluetoothService {
    }

    powerService: PowerService {
    }

    hardwareService: HardwareService {
    }

    themeSwitcherService: ThemeSwitcherService {
    }

    wallpaperSwitcherService: WallpaperSwitcherService {
    }

    auditService: AuditService {
    }

    clipboardService: ClipboardService {
    }

}
