# Roadmap

## 0.1.0: iOS Simulators

- [x] List simulators from `xcrun simctl list devices --json`, grouped by runtime, with booted ones first.
- [ ] Boot and shut down a simulator.
- [ ] Open a deep link or universal link in a booted simulator.
- [ ] Send a push notification from a saved JSON payload.
- [ ] Set or clear a simulated location.
- [ ] Take a screenshot and copy it to the clipboard or save it to a folder.
- [ ] Override the status bar for clean screenshots (time, battery, signal).

## 0.2.0: Android emulators

- Find `adb` and the Android SDK, or let the user point to them.
- List running emulators and available AVDs, and start an AVD.
- Open deep links and App Links with `adb shell am start`.
- Set a location with `adb emu geo fix`.
- Take screenshots and set demo mode for the status bar.

## 0.3.0: daily use

- Record the screen of a simulator or emulator.
- Grant, revoke and reset app permissions.
- Uninstall an app or reset its data.
- Saved deep links and push payloads per project.
- Global keyboard shortcuts for common actions.
- Launch at login.

## Releases

- Signed and notarised builds attached to GitHub releases.
- A Homebrew cask.
- GitHub Actions to build and test every pull request.
