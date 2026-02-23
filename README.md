# Uninstaller for macOS

Dragging a macOS app to the Trash leaves behind caches, preferences, containers, and support files scattered across `~/Library`. When you reinstall, those stale settings come back — causing config conflicts or the app behaving as if it was never removed.

Tools like AppZapper were great for older macOS apps, but modern apps spread files across far more locations (Containers, Group Containers, Application Scripts, HTTPStorages, etc.) that legacy uninstallers don't check. I wanted something I could trust to actually find everything.

## What it does

Drop a `.app` file onto the window. The app parses its bundle identifier, scans known macOS directories, and even reads the app's binary for embedded path references (e.g., `~/.gemini/`) to find files that pattern-matching alone would miss.

You get a checklist of every associated file with its size, grouped by category. Nothing is deleted automatically — you choose what to remove, and deletions go to Trash.

## Locations scanned

- `~/Library/Application Support/`, `Caches/`, `Preferences/`, `Containers/`
- `~/Library/Saved Application State/`, `HTTPStorages/`, `WebKit/`, `Cookies/`
- `~/Library/Logs/`, `LaunchAgents/`, `Group Containers/`, `Application Scripts/`
- `/Library/Application Support/`, `LaunchAgents/`, `LaunchDaemons/`, `Preferences/`, `Caches/`
- `/var/db/receipts/`
- `~/` hidden dot-folders matching the app name
- Paths discovered by scanning the app's executable binary

## Requirements

- macOS 14+
- Full Disk Access recommended (System Settings → Privacy & Security → Full Disk Access)

## Building

Open `Uninstaller.xcodeproj` in Xcode and build. Sandboxing is disabled in the entitlements to allow filesystem access.
