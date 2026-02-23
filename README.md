# Uninstaller for macOS

Dragging a macOS app to the Trash leaves behind caches, preferences, containers, and support files scattered across `~/Library`. When you reinstall, those stale settings come back — causing config conflicts or the app behaving as if it was never removed.

Tools like AppZapper were great for older macOS apps, but modern apps spread files across far more locations (Containers, Group Containers, Application Scripts, HTTPStorages, etc.) that legacy uninstallers don't check. I wanted something I could trust to actually find everything.

## What it does

Drop a `.app` file onto the window. The app parses its bundle identifier, scans known macOS directories, and uses multiple discovery strategies to surface files that pattern-matching alone would miss.

You get a checklist of every associated file with its size, grouped by category. Nothing is deleted automatically — you choose what to remove, and deletions go to Trash.

## How it finds files

1. **Exact match** — checks standard locations using the app's bundle identifier (e.g., `~/Library/Containers/com.google.antigravity`)
2. **Pattern match** — scans Library directories for anything matching the app name, bundle ID, or developer prefix
3. **Home directory scan** — looks for hidden dot-folders in `~/` matching the app name
4. **Binary scanning** — reads the app's executable for embedded path references to find non-standard config locations
5. **Community mappings** — a [crowdsourced JSON file](Uninstaller/Resources/community_mappings.json) of known non-standard paths that can't be discovered automatically (e.g., Antigravity → `~/.gemini/`). The app fetches the latest version from this repo on each scan, falling back to the bundled copy when offline.

## Locations scanned

- `~/Library/Application Support/`, `Caches/`, `Preferences/`, `Containers/`
- `~/Library/Saved Application State/`, `HTTPStorages/`, `WebKit/`, `Cookies/`
- `~/Library/Logs/`, `LaunchAgents/`, `Group Containers/`, `Application Scripts/`
- `~/Library/Logs/DiagnosticReports/` (crash reports)
- `/Library/Application Support/`, `LaunchAgents/`, `LaunchDaemons/`, `Preferences/`, `Caches/`
- `/var/db/receipts/`
- `~/` hidden dot-folders matching the app name
- Paths discovered by scanning the app's executable binary
- Paths from community mappings

## Installation

1. Download `Uninstaller-v1.0.zip` from [Releases](https://github.com/maylard/MacOS-App-UnInstall/releases)
2. Unzip and move `Uninstaller.app` to `/Applications/`
3. Right-click → Open on first launch (the app is not notarized)
4. Grant Full Disk Access: System Settings → Privacy & Security → Full Disk Access → add Uninstaller
5. **Quit and reopen the app** after granting FDA (macOS applies permissions at launch)

## Requirements

- macOS 14 (Sonoma) or later
- Full Disk Access recommended for complete scanning and deletion of protected files

## Building from source

Open `Uninstaller.xcodeproj` in Xcode and build. Sandboxing is disabled in the entitlements to allow filesystem access.

## Contributing community mappings

Some apps store files in non-standard locations that can't be discovered automatically (e.g., `~/.gemini/` for Google's Antigravity). You can help by adding entries to [`community_mappings.json`](Uninstaller/Resources/community_mappings.json) via pull request:

```json
"com.example.app": {
  "name": "Example App",
  "paths": [
    "~/.example-config/",
    "~/Library/SomeUnusualLocation/"
  ]
}
```
