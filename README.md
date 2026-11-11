# DeviceTray

DeviceTray is a macOS menu-bar app for mobile developers who test on iOS Simulators and Android emulators. It puts the commands you'd otherwise type into `xcrun simctl` and `adb` behind one panel: open a deep link, send a test push notification, set a location, change the status bar, take a screenshot or record the screen.

It runs locally, has no account or server, and only talks to the simulator and emulator tools already on your Mac.

## Who it's for

iOS and Android developers and testers who switch between simulators and emulators many times a day and are tired of looking up `simctl` and `adb` flags.

## Status

Early development. The menu-bar panel lists your iOS Simulators from `xcrun simctl list devices --json`, grouped by runtime with booted ones first and a green dot on each booted one. A refresh button reloads the list. Each row has a Boot or Shut Down button, and Simulator.app opens after a boot. On a booted simulator, the link button opens a field where you can enter a deep link or universal link, which DeviceTray opens with `xcrun simctl openurl`. Push notifications, locations and the rest are planned in [ROADMAP.md](ROADMAP.md).

## Built with

- Swift and SwiftUI (`MenuBarExtra`), macOS 14 or later
- `xcrun simctl` for iOS Simulators and `adb` for Android emulators
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project from `project.yml`

## Running it

You need Xcode 16 or later and XcodeGen (`brew install xcodegen`). Android features also need the Android SDK platform tools (`adb`).

```sh
git clone https://github.com/emmanuelkehinde/DeviceTray.git
cd DeviceTray
xcodegen generate
open DeviceTray.xcodeproj
```

Run the `DeviceTray` scheme. The app has no Dock icon, and it appears in the menu bar as a phone symbol.

Run the tests with:

```sh
xcodebuild -project DeviceTray.xcodeproj -scheme DeviceTray -destination 'platform=macOS' test
```

## License

MIT. See [LICENSE](LICENSE).
