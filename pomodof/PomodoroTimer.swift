import Foundation
import Combine
import AppKit
import UserNotifications
import EventKit
import ServiceManagement

enum SessionMode: String, CaseIterable {
    case focus = "Focus"
    case short = "Short"
    case long  = "Long"
}

@MainActor
class PomodoroTimer: ObservableObject {

    // MARK: - Mode & durations
    @Published var activeMode: SessionMode = .focus
    @Published var focusMinutes: Int  = 25
    @Published var shortMinutes: Int  = 5
    @Published var longMinutes: Int   = 15

    // MARK: - Timer state
    @Published var remainingSeconds: Int = 25 * 60
    @Published var isRunning: Bool = false
    @Published var sessionCompleted: Bool = false

    // MARK: - Settings
    @Published var markDoneOnFinish: Bool = true

    // MARK: - Reminders
    @Published var reminders: [EKReminder] = []
    @Published var selectedReminderIDs: Set<String> = []

    private var timerTask: Task<Void, Never>?
    private let eventStore = EKEventStore()
    private var sessionStartTime: Date?
    private var sessionLogReminder: EKReminder?
    private var sessionID: String = ""

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.timeStyle = .short; return f
    }()
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; return f
    }()

    // MARK: - Computed

    var currentDurationMinutes: Int {
        switch activeMode {
        case .focus: return focusMinutes
        case .short: return shortMinutes
        case .long:  return longMinutes
        }
    }

    var totalSeconds: Int { currentDurationMinutes * 60 }

    var isPaused: Bool {
        !isRunning && !sessionCompleted && remainingSeconds > 0 && remainingSeconds < totalSeconds
    }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
    }

    var timeString: String {
        String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60)
    }

    var menuBarLabel: String { isRunning || isPaused ? timeString : "🍅" }

    var isLaunchAtLoginEnabled: Bool { SMAppService.mainApp.status == .enabled }

    var selectedReminders: [EKReminder] {
        reminders.filter { selectedReminderIDs.contains($0.calendarItemIdentifier) }
    }

    var sessionSummary: String {
        let names = selectedReminders.compactMap(\.title)
        var parts: [String] = []
        if !names.isEmpty { parts.append(names.prefix(3).joined(separator: " · ")) }
        parts.append("\(currentDurationMinutes) min · \(activeMode.rawValue) · \(timeFormatter.string(from: Date()))")
        return parts.joined(separator: "\n")
    }

    // MARK: - Init

    init() {
        if EKEventStore.authorizationStatus(for: .reminder) == .fullAccess { loadReminders() }
    }

    // MARK: - Mode & Duration

    func minutes(for mode: SessionMode) -> Int {
        switch mode {
        case .focus: return focusMinutes
        case .short: return shortMinutes
        case .long:  return longMinutes
        }
    }

    func setMode(_ mode: SessionMode) {
        guard !isRunning else { return }
        activeMode = mode
        remainingSeconds = currentDurationMinutes * 60
    }

    func adjustCurrentDuration(by delta: Int) {
        guard !isRunning else { return }
        switch activeMode {
        case .focus: focusMinutes  = max(1, min(120, focusMinutes  + delta))
        case .short: shortMinutes  = max(1, min(120, shortMinutes  + delta))
        case .long:  longMinutes   = max(1, min(120, longMinutes   + delta))
        }
        remainingSeconds = currentDurationMinutes * 60
    }

    // MARK: - Timer

    func start() {
        guard !isRunning else { return }
        Task { try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) }
        if !isPaused {
            remainingSeconds = currentDurationMinutes * 60
            sessionStartTime = Date()
        }
        isRunning = true
        let deadline = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        timerTask = Task {
            while remainingSeconds > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                remainingSeconds = max(0, Int(deadline.timeIntervalSinceNow.rounded(.up)))
            }
            finish()
        }
    }

    func pause() {
        isRunning = false
        timerTask?.cancel()
        timerTask = nil
    }

    func stop() {
        pause()
        remainingSeconds = currentDurationMinutes * 60
        sessionStartTime = nil
    }

    // MARK: - Reminders

    func toggleReminder(_ reminder: EKReminder) {
        let id = reminder.calendarItemIdentifier
        if selectedReminderIDs.contains(id) { selectedReminderIDs.remove(id) }
        else { selectedReminderIDs.insert(id) }
    }

    func fetchReminders() {
        Task {
            guard (try? await eventStore.requestFullAccessToReminders()) == true else { return }
            loadReminders()
        }
    }

    // MARK: - Session Complete

    func completeSession(quality: Int, review: String = "") {
        let duration  = currentDurationMinutes
        let endTime   = Date()
        let startTime = sessionStartTime ?? endTime.addingTimeInterval(TimeInterval(-duration * 60))
        let names     = selectedReminders.compactMap(\.title)

        let tf = timeFormatter
        let df = dateFormatter

        let stars = quality > 0
            ? String(repeating: "★", count: quality) + String(repeating: "☆", count: 5 - quality)
            : "—"

        let tag = "#pomo-\(sessionID)"
        let trimmedReview = review.trimmingCharacters(in: .whitespacesAndNewlines)

        let noteLines: [String?] = [
            "📅 \(df.string(from: endTime))",
            "🕐 \(tf.string(from: startTime)) → \(tf.string(from: endTime))",
            "⏱ \(duration) min (\(activeMode.rawValue))",
            names.isEmpty ? nil : "📋 \(names.joined(separator: ", "))",
            "⭐ \(stars)",
            trimmedReview.isEmpty ? nil : "📝 \(trimmedReview)",
            "🔗 \(tag)"
        ]
        let notes = noteLines.compactMap { $0 }.joined(separator: "\n")

        if let log = sessionLogReminder {
            log.notes = notes
            log.isCompleted = true
            try? eventStore.save(log, commit: true)
        }

        let reviewSuffix = trimmedReview.isEmpty ? "" : "\n📝 \(trimmedReview)"
        let taskBacklink = "\n\n📍 Pomodoro \(df.string(from: endTime)) \(tf.string(from: startTime))→\(tf.string(from: endTime)) · \(duration)min · \(stars)\(reviewSuffix)\n🔗 \(tag)"
        if markDoneOnFinish {
            for r in selectedReminders {
                r.notes = (r.notes ?? "") + taskBacklink
                r.isCompleted = true
                try? eventStore.save(r, commit: true)
            }
            reminders.removeAll { selectedReminderIDs.contains($0.calendarItemIdentifier) }
            selectedReminderIDs.removeAll()
        } else {
            for r in selectedReminders {
                r.notes = (r.notes ?? "") + taskBacklink
                try? eventStore.save(r, commit: true)
            }
        }

        sessionLogReminder = nil
        sessionStartTime   = nil
        sessionCompleted   = false
        remainingSeconds   = currentDurationMinutes * 60

        if EKEventStore.authorizationStatus(for: .reminder) == .fullAccess { loadReminders() }
    }

    func toggleLaunchAtLogin() {
        do {
            if isLaunchAtLoginEnabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
            objectWillChange.send()
        } catch {}
    }

    func finishEarly() {
        timerTask?.cancel()
        timerTask = nil
        finish()
    }

    // MARK: - Private

    private func loadReminders() {
        Task {
            let pred = eventStore.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
            let fetched: [EKReminder] = await withCheckedContinuation { cont in
                eventStore.fetchReminders(matching: pred) { cont.resume(returning: $0 ?? []) }
            }
            reminders = fetched.sorted { ($0.title ?? "") < ($1.title ?? "") }
        }
    }

    private func finish() {
        sessionID = String(UUID().uuidString.prefix(8)).lowercased()
        isRunning = false
        timerTask = nil
        NSSound(named: "Glass")?.play()
        sendLocalNotification()
        createLogReminder()
        sessionCompleted = true
    }

    private func createLogReminder() {
        let names = selectedReminders.compactMap(\.title)
        let title = names.isEmpty ? "🍅 Pomodof Done" : "🍅 \(names.prefix(2).joined(separator: " + "))"
        Task {
            guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else { return }
            let r = EKReminder(eventStore: eventStore)
            r.title    = title
            r.calendar = eventStore.defaultCalendarForNewReminders()
            try? eventStore.save(r, commit: true)
            sessionLogReminder = r
        }
    }

    private func sendLocalNotification() {
        let c = UNMutableNotificationContent()
        c.title = "Pomodof Complete!"
        let names = selectedReminders.compactMap(\.title)
        c.body  = names.isEmpty ? "Time for a break." : "\(names.joined(separator: ", ")) done."
        c.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil)
        )
    }
}
