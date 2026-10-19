# Swift Quit

Swift Quit quits an application after its last window closes. Rules can apply to all eligible applications with exclusions, or only to selected applications. Finder, Spotlight, Notification Center, and Swift Quit itself are always excluded. A configurable delay gives an application time to open another window before quitting.

## Requirements

- macOS 13 or later.
- Accessibility permission to observe application windows.
- A current Xcode/macOS SDK to build. Standard SwiftUI and AppKit controls follow the running system's appearance, including Liquid Glass on supported macOS releases.

## Setup and quiet startup

1. Install the release app in `/Applications` and open it manually.
2. In Settings, choose **Open Accessibility Settings…** and authorize Swift Quit. Swift Quit checks for permission periodically, so relaunching is not normally necessary.
3. Enable **Launch at login**. If macOS asks for approval, allow Swift Quit in **System Settings → General → Login Items**.

On subsequent logins, Swift Quit starts without opening a window, activating itself, or requesting Accessibility permission. Manually opening the app or choosing **Settings…** from its menu bar icon opens settings. Closing settings leaves the app running.

You can hide the menu bar icon. Open Swift Quit from Applications to access settings again. While Accessibility permission is unavailable, the icon remains visible as a recovery entry point. Automatic quitting waits until permission is granted.

The previous version's application rules, menu bar preference, and quit delay are preserved. Login startup migrates from the old LaunchAtLogin helper to Apple's `SMAppService`. If legacy helper cleanup fails, settings explains how to remove the old entry. The old **Launch Hidden** preference is replaced by explicit behavior: login launches are quiet; manual launches show settings.

## Development

```sh
./script/build_and_run.sh          # Build and open settings
./script/build_and_run.sh --build  # Build only
./script/build_and_run.sh --background # Start quietly without opening settings
./script/build_and_run.sh --verify # Build, launch, and check the development process
./script/test.sh                   # Isolated settings and login migration checks
```

The Codex Run action uses the same script. `--debug`, `--logs`, and `--telemetry` are also available. Set `DEVELOPER_DIR` when Xcode is installed elsewhere; `SWIFTQUIT_BUILD_DIR` and `SWIFTQUIT_PACKAGES_DIR` can override build/cache locations.

Debug builds use the separate bundle identifier `onebadidea.Swift-Quit.Development`, with separate preferences and Accessibility authorization. They leave the installed release app alone. To exercise automatic quitting, quit the installed copy and authorize the development build explicitly. Release builds retain `onebadidea.Swift-Quit` for existing user preferences and login migration.

For installation, build the Release configuration, sign it with your own identity, and place the app at its final location before enabling login startup. The repository's historical signing team setting must be replaced for distribution under another developer account. The run script uses ad hoc signing for local development.

## Verification before release

- Authorize Accessibility and verify that closing an app's last window quits it after the delay; opening a new window during the delay keeps it running.
- Check both include and exclude modes, list persistence, adding/removing applications, and delay persistence.
- Verify light/dark appearance, keyboard navigation, and Command-comma to open settings.
- Enable login startup from the installed release app; log out and back in. Confirm it remains running with no settings window or focus change.
- Disable startup in System Settings; reopen Swift Quit settings and confirm the switch reflects the system state.
- Test upgrade from the previous release with its login helper enabled and confirm only one login mechanism remains.

Build and isolated checks do not substitute for an actual login or Accessibility integration test.

## Upstream

Original project: [swiftquit.com](https://swiftquit.com). Existing upstream releases can be installed with `brew install --cask swift-quit`; that command does not install these local changes.

Quitting behavior depends on the windows each application exposes through Accessibility. Validate rules with your own applications before enabling automatic quitting broadly.

## App icon

`swiftquit.icon` is the editable Icon Composer document used as the primary app icon in both build configurations. It contains separate SVG window and close-symbol layers over a warm gradient. System lighting and materials are rendered by Icon Composer; no shadows or outer icon mask are baked into the source artwork. The original raster icon remains in the asset catalog for reference, but is no longer the primary icon.

Open `swiftquit.icon` in Icon Composer to adjust its layers. Run `./script/export_icons.sh` with Xcode 27 or later to regenerate the default, dark, and monochrome previews in `design/icon-previews`. Xcode compiles the document into the application's icon resources, including its `.icns` fallback for earlier supported macOS releases.

## Local signed package

Run `./script/package_local.sh` to build an ad hoc signed Release app for the host architecture and produce `dist/Swift Quit.app`, a ZIP, and a SHA-256 checksum. The script validates signatures both before packaging and after extracting the ZIP. These local builds are not notarized. Move the previous staged app aside before rerunning the script.
