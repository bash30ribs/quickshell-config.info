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

    IpcHandler {
        function toggle() : string {
            Appearance.barVisible = !Appearance.barVisible;
            return Appearance.barVisible ? "visible" : "hidden";
        }

        function hide() : string {
            Appearance.barVisible = false;
            return "hidden";
        }

        function show() : string {
            Appearance.barVisible = true;
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
        id: clipboardDrawer

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
            clipboardDrawer: clipboardDrawer
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

    themeSwitcherService: ThemeSwitcherService {
    }

    wallpaperSwitcherService: WallpaperSwitcherService {
    }

    auditService: AuditService {
    }

    clipboardService: ClipboardService {
    }

}
