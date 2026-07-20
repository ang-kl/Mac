# Mac

MacBook utilities. Versions use `v0.0.###` (three-digit build counter since the first release, v0.0.001) — see [CHANGELOG.md](CHANGELOG.md); the app shows its own version at the bottom of the cup menu. First up: **keepawake** — stop your Mac from sleeping while a long-running CLI job works (e.g. while you're travelling). Two flavours, both built only on Apple's own tools (`caffeinate`, IOKit, `pmset`), so they work on every MacBook — Air or Pro, Intel or Apple Silicon.

## 1. CLI script — `scripts/keepawake`

No build step. Install:

```sh
chmod +x scripts/keepawake
# optional, so you can type `keepawake` from anywhere:
sudo ln -s "$PWD/scripts/keepawake" /usr/local/bin/keepawake
```

Use:

```sh
keepawake -- python3 my_long_job.py   # Mac stays awake exactly while the command runs (safest)
keepawake on 8                        # stay awake for 8 hours
keepawake on 2d                       # stay awake for 2 days
keepawake on                          # stay awake until you turn it off
keepawake off                         # back to normal
keepawake status                      # is it on?
```

### Lid closed?

`caffeinate` alone can't stop sleep when you close the lid on battery. If you need the lid shut:

```sh
keepawake --lid-closed on     # asks for your admin password (sudo pmset disablesleep 1)
keepawake off                 # restores normal sleep — don't forget this
```

**Only do this on AC power.** The script restores normal sleep automatically when the wrapped command exits or you run `off`.

## 2. Menu-bar app — `menubar/`

A coffee-cup toggle in the menu bar. Build once on your Mac (needs the free Xcode Command Line Tools — `xcode-select --install`):

```sh
cd menubar && ./build.sh
open KeepAwake.app
```

What it does:

- **Presets**: 1h / 4h / 8h / 12h / 1 day / 2 days / 5 days / Custom… (any number of hours), or indefinitely until you turn it off. The menu shows the time remaining.
- **Effects** (toggleable): the cup starts full and *drains as the timer counts down*, and you get notifications at start, at 15 minutes left, and when the timer finishes.
- **Lightweight by default**: out of the box the app only keeps the Mac awake — no background checks run at all, and it idles at ~10–20 MB / 0% CPU. Everything below that needs polling is gated behind **Background Monitoring** (off by default): turning it on shows a popup ("Run Background Checks" / "Keep It Lightweight") explaining the cost (~0.1% CPU) before anything starts.
- **Health Alerts** (toggleable, free even in lightweight mode): notifications when memory pressure gets high or critical (worth having on a 16 GB machine), when the Mac runs hot enough to throttle, and when sleep interrupted keep-awake (e.g. lid closed). These come from kernel events, not polling — zero cost. The charger-unplugged alert is the one exception: it needs Background Monitoring on.
- **Keep Display On** (off by default): by default the *screen* is allowed to sleep while the *system* stays awake — best for long unattended jobs. There's also **Turn Display Off Now** to blank the screen immediately (the job keeps running).
- **Keep Disk Active** (off by default): holds a disk-idle assertion during long syncs. Your MacBook's internal drive is an SSD (nothing spins, nothing to keep awake), so this only matters for external hard drives or huge iCloud transfers — turn it on just for those.
- **iCloud auto-download (one-time setup)**: use **Download iCloud Folder Locally…** once to pick a folder (e.g. your GitHub backup) — it downloads it, then offers scheduled auto-download: while keep-awake is on, the app re-requests the download on your chosen timing (**Auto-Download Timing**: every 30 min / 1 h / 3 h / 6 h) so the folder simply stays fully on this Mac. It's also resource-aware: a run is skipped and retried a few minutes later whenever the Mac is running hot, memory pressure is high, the charger is unplugged, or Claude (CLI or app) / another AI app is actively working — so it never competes with your real work. (An idle open Claude window doesn't block it; only active work does.) Toggle it off (or pick a different folder) from the same menu. Done = no cloud ☁ icons in Finder.
- **Readable & colorblind-safe**: all status/insight text renders in full-contrast label color at 14 pt (not the dim gray of standard disabled menu items), and nothing in the app relies on red vs green — the cup level and countdown are shape/text based.
- **End-of-timer warning in the menu bar**: during the last 15 minutes the menu bar shows a countdown next to the cup (e.g. `☕ 12m`), on top of the 15-minute notification. Hovering over the cup always shows the exact time remaining as a tooltip.
- **Likely end time**: the status line includes when the timer will finish — `Awake — 3h 42m left (until 18:45)`, or `(until 03:15 21-07)` when it runs past midnight (HH:MM DD-MM). With idle countdown on, this shifts as pauses accumulate.
- **Countdown Only While Idle** (off by default): with this toggle on, a timed session's hours only count down while you're not touching the keyboard/mouse — so "4 hours" means 4 hours of you being away, and the timer can't expire while you're still working. The status line shows "(paused while you work)" during activity. Detection uses macOS's built-in idle clock; zero overhead.
- **System Insights** submenu — a mini Activity Monitor in the cup (requires Background Monitoring; until enabled it just shows the opt-in):
  - *KeepAwake app: N MB* — the app's own footprint (typically 10–20 MB, ~0% CPU; it's essentially free to keep in the menu bar).
  - *Memory: X of 16 GB used — pressure: normal/high/critical* — same "used" definition as Activity Monitor.
  - *Network: ↓ / ↑ throughput* — whole-machine traffic, refreshed every 30 s.
  - *AI apps running* — Claude, ChatGPT, Copilot, Ollama, Gemini, Cursor, etc., each with memory and CPU. Handy when the Claude app keeps retrying: **traffic flowing + CPU busy = it's working; retries with ~0 KB/s = your connection is the problem** (status.claude.ai only reports Anthropic's side, not your Wi-Fi).
  - *Top memory* and *Top CPU* apps (helpers rolled up per app), plus **Open Activity Monitor** for the full picture.

To have it start on login: System Settings → General → Login Items → add `KeepAwake.app`.

> First launch: if macOS warns the app is from an unidentified developer, right-click → Open (it's unsigned because you built it yourself). Notifications appear via Script Editor — if they don't show, allow it under System Settings → Notifications.

### Keeping your iCloud "GitHub storage" fully local

Two settings matter so a copy actually lives on your drive, not just in the cloud:

1. System Settings → Apple ID → iCloud → iCloud Drive → turn **off** "Optimize Mac Storage" (otherwise macOS may evict local copies when disk gets full).
2. Use **Download iCloud Folder Locally…** in the menu app (or right-click the folder in Finder → "Download Now") and keep the Mac awake while it downloads.

## Travelling checklist

- Keep the Mac **plugged into AC power** — sleep prevention on battery is limited by design, and long jobs will drain it anyway. The app alerts you if the charger gets unplugged.
- Prefer `keepawake -- <command>`: the Mac returns to normal by itself the moment your job finishes.
- If the lid must be closed, use `--lid-closed` and AC power.
- Let the display sleep (leave "Keep Display On" off, or use "Turn Display Off Now") — it saves power and heat while the system keeps working.
- On an older i5 / 16 GB machine: close browsers and heavy apps before leaving so the background job has the memory to itself — the app's Health Alerts will warn you if pressure climbs anyway.
- Don't worry about AI apps taxing the i5 or GPU: Claude/ChatGPT-style apps do their AI computation on the provider's servers — locally they only cost memory and network, which is exactly what System Insights shows.
