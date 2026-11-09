import SwiftUI

@main
struct DeviceTrayApp: App {
    var body: some Scene {
        MenuBarExtra("DeviceTray", systemImage: "iphone.gen3") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
