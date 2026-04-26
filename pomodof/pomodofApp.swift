import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let showInDock = UserDefaults.standard.bool(forKey: "showInDock")
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
    }
}

@main
struct PomodofApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var pomodoroTimer = PomodoroTimer()
    @StateObject private var audioPlayer   = FocusAudioPlayer()
    @StateObject private var updateChecker = UpdateChecker()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(pomodoroTimer)
                .environmentObject(audioPlayer)
                .environmentObject(updateChecker)
                .onAppear { updateChecker.check() }
        } label: {
            Text(pomodoroTimer.menuBarLabel)
        }
        .menuBarExtraStyle(.window)
        .onChange(of: pomodoroTimer.isRunning) { _, running in
            if running { audioPlayer.resume() }
            else { audioPlayer.pause() }
        }
        .onChange(of: pomodoroTimer.sessionCompleted) { _, completed in
            if completed { audioPlayer.stopAll() }
        }
    }
}
