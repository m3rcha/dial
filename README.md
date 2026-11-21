# Dial

A native macOS system tweaker for **macOS Sequoia (15.0)+**, rebuilt from scratch as the successor to [BareMac](https://github.com/m3rcha/bare-mac).

## Features

- **Adaptive Native UI:** Clean native AppKit/SwiftUI surfaces on macOS 15 (Sequoia), and native Liquid Glass on macOS 26 (Tahoe) and macOS 27 (Golden Gate).
- **58 Built-in Tweaks:** Declarative, `CFPreferences`-backed tweaks across Dock, Finder, Window & Mission Control, Screenshots, Keyboard & Input, Trackpad & Mouse, Menu Bar & Desktop, Animations & Performance, and Developer & Privacy.
- **Setup Codes (`dial:v1:` & `dial://`):** Export your Mac's modified settings as a compact Setup Code, or paste (`⇧⌘V`) a code from the Dial community to preview a selective `Current → New` diff before applying.
- **Automatic Snapshots & Rollback:** Every change records a reversible snapshot; revert individual tweaks to stock macOS defaults or undo entire batches.
- **Smart Service Restarts:** Queues `Dock`, `Finder`, `SystemUIServer`, and `WindowManager` restarts into a single confirmation capsule.
- **Profiles & Optional Menu Bar:** Built-in and custom profiles with an optional menu bar switcher.

## Build & Run

Requires Swift 6.0+ on macOS 15.0 or newer:

```bash
# Run core tests
swift test -Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing

# Build Dial.app
./Scripts/bundle-app.sh
open build/Dial.app
```

## License

[MIT](LICENSE)
