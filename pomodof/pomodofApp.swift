import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct PomodofApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var pomodoroTimer = PomodoroTimer()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(pomodoroTimer)
        } label: {
            Text(pomodoroTimer.menuBarLabel)
        }
        .menuBarExtraStyle(.window)
    }
}
