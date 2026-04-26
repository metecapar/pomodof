import SwiftUI
import EventKit

// MARK: - Root

struct ContentView: View {
    @EnvironmentObject var timer: PomodoroTimer

    var body: some View {
        Group {
            if timer.sessionCompleted  { SessionCompleteView() }
            else if timer.isRunning    { TimerView() }
            else                       { TaskListView() }
        }
        .onAppear { timer.fetchReminders() }
    }
}

// MARK: - Task List

struct TaskListView: View {
    @EnvironmentObject var timer: PomodoroTimer
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            modeBar
            durationPicker
            Divider()
            taskList
            Divider()
            bottomBar
        }
        .frame(width: 270)
    }

    // Three mode tabs
    private var modeBar: some View {
        HStack(spacing: 0) {
            ForEach(SessionMode.allCases, id: \.self) { mode in
                let active = timer.activeMode == mode
                Button { timer.setMode(mode) } label: {
                    VStack(spacing: 2) {
                        Text(mode.rawValue)
                            .font(.caption)
                            .fontWeight(active ? .semibold : .regular)
                        Text("\(timer.minutes(for: mode))m")
                            .font(.system(size: 10))
                            .foregroundStyle(active ? Color.red : Color.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(active ? Color.red.opacity(0.1) : Color.clear)
                    .foregroundStyle(active ? Color.red : Color.secondary)
                }
                .buttonStyle(.plain)
                if mode != .long { Divider().frame(height: 30) }
            }
        }
        .background(Color.secondary.opacity(0.04))
    }

    // − big number + adjuster
    private var durationPicker: some View {
        HStack {
            Button { timer.adjustCurrentDuration(by: -1) } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.secondary.opacity(0.1)))
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 0) {
                Text("\(timer.currentDurationMinutes)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                    .animation(.snappy, value: timer.currentDurationMinutes)
                Text("minutes")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button { timer.adjustCurrentDuration(by: 1) } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.secondary.opacity(0.1)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 10)
    }

    // Reminder task list
    @ViewBuilder
    private var taskList: some View {
        if timer.reminders.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "checklist")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
                Text("No tasks — tap ↻ to sync")
                    .font(.caption)
                    .foregroundStyle(.quaternary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(timer.reminders, id: \.calendarItemIdentifier) { r in
                        TaskRow(
                            title: r.title ?? "Untitled",
                            isSelected: timer.selectedReminderIDs.contains(r.calendarItemIdentifier)
                        ) { timer.toggleReminder(r) }
                    }
                }
            }
            .frame(minHeight: 60, maxHeight: 210)
        }
    }

    // Gear + start button
    private var bottomBar: some View {
        HStack(spacing: 10) {
            // Sync
            Button { timer.fetchReminders() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.secondary.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Sync Reminders")

            // Settings
            Button { showSettings.toggle() } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.secondary.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .popover(isPresented: $showSettings, arrowEdge: .bottom) {
                SettingsPopover().environmentObject(timer)
            }

            // Start / Resume
            Button {
                timer.start()
            } label: {
                Group {
                    if timer.isPaused {
                        Text("Resume · \(timer.timeString)")
                    } else if timer.selectedReminderIDs.isEmpty {
                        Text("Start Pomodoro")
                    } else {
                        Text("Start · \(timer.selectedReminderIDs.count) task\(timer.selectedReminderIDs.count == 1 ? "" : "s")")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }
}

// MARK: - Timer View

struct TimerView: View {
    @EnvironmentObject var timer: PomodoroTimer

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: 1 - timer.progress)
                    .stroke(Color.red, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: timer.progress)
                VStack(spacing: 4) {
                    Text(timer.timeString)
                        .font(.system(size: 42, weight: .bold, design: .monospaced))
                    let names = timer.selectedReminders.compactMap(\.title)
                    if !names.isEmpty {
                        Text(names.prefix(2).joined(separator: " · "))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: 150)
                    }
                    Text(timer.activeMode.rawValue)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 160, height: 160)

            HStack(spacing: 10) {
                Button("Pause")    { timer.pause()       }.buttonStyle(.bordered)
                Button("Complete") { timer.finishEarly() }.buttonStyle(.borderedProminent).tint(.red)
                Button("Stop")     { timer.stop()        }.buttonStyle(.bordered).tint(.secondary)
            }
        }
        .padding(24)
        .frame(width: 270)
    }
}

// MARK: - Session Complete

struct SessionCompleteView: View {
    @EnvironmentObject var timer: PomodoroTimer
    @State private var quality: Int = 0
    @State private var reviewText: String = ""

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("🎉").font(.system(size: 36))
                Text("Session Complete").font(.headline)
                Text(timer.sessionSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }

            Divider()

            VStack(spacing: 10) {
                Text("How was your focus?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= quality ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundStyle(star <= quality ? Color.yellow : Color.secondary.opacity(0.3))
                            .onTapGesture { quality = star }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Session notes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("What did you work on? Any blockers?", text: $reviewText, axis: .vertical)
                    .font(.caption)
                    .lineLimit(3...4)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.08))
                    )
            }

            HStack(spacing: 10) {
                Button("Skip") { timer.completeSession(quality: 0) }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Button(quality > 0 ? "Save  \(quality)★" : "Save") {
                    timer.completeSession(quality: quality, review: reviewText)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .frame(width: 270)
    }
}

// MARK: - Settings Popover

struct SettingsPopover: View {
    @EnvironmentObject var timer: PomodoroTimer

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: Binding(
                get: { timer.isLaunchAtLoginEnabled },
                set: { _ in timer.toggleLaunchAtLogin() }
            )) { Text("Launch at Login").font(.caption) }
            .toggleStyle(.checkbox)

            Toggle("Mark tasks done on finish", isOn: $timer.markDoneOnFinish)
                .font(.caption)
                .toggleStyle(.checkbox)
        }
        .padding(14)
        .frame(width: 200)
    }
}

// MARK: - Task Row

struct TaskRow: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundStyle(isSelected ? Color.red : Color.secondary.opacity(0.4))
            Text(title)
                .font(.callout)
                .lineLimit(1)
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(isSelected ? Color.red.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
