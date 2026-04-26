# Pomodof

A minimal Pomodoro timer that lives in your Mac menu bar. Link tasks from Reminders, play focus sounds, and log every session automatically.

## Download

Grab the latest release from the [dist](./dist) folder:

- **`Pomodof.dmg`** — mount and drag to Applications (recommended)
- **`Pomodof.zip`** — unzip and move `pomodof.app` to Applications

## Installation

### From DMG

1. Double-click `Pomodof.dmg`
2. Drag `pomodof` into your **Applications** folder
3. Eject the disk image
4. Open `pomodof` from Applications or Spotlight

### From ZIP

1. Unzip `Pomodof.zip`
2. Move `pomodof.app` to your **Applications** folder
3. Open it

## First Launch — Gatekeeper

Because this app is not notarized by Apple, macOS will block it on first open. To bypass this:

1. In **Finder**, navigate to Applications
2. **Right-click** `pomodof` → **Open**
3. Click **Open** in the dialog that appears

You only need to do this once. After that, the app opens normally.

Alternatively, go to **System Settings → Privacy & Security** and click **Open Anyway** after the first blocked attempt.

## Features

- **Menu bar timer** — runs quietly in the background, no Dock icon required
- **Three modes** — Focus (25 min), Short break (5 min), Long break (15 min)
- **Reminders integration** — pick tasks from Apple Reminders; they get marked complete when your session ends
- **Focus sounds** — Rain, Café, or Focus noise; pauses automatically when you pause the timer
- **Session log** — every completed session writes a timestamped note back to Reminders
- **Session review** — rate your focus (1–5 stars) and add notes at the end of each session
- **Launch at Login** — optional, toggle in settings

## Requirements

- macOS 14 Sonoma or later
- Apple Reminders (optional, for task integration)

## Building from Source

```bash
git clone https://github.com/metecapar/pomodof.git
cd pomodof
open pomodof.xcodeproj
```

Then press `Cmd+R` in Xcode to build and run.
