# Version history

Format: `v<major>.<minor>.<build>` — starting at v0.0.01; the two-digit build
number counts every release since the first. The running app shows its version
at the bottom of the cup menu; if it doesn't match the newest entry here,
rebuild (`cd menubar && ./build.sh`).

| Version | PR | Changes |
|---------|----|---------|
| v0.0.01 | #1 | First release: `keepawake` CLI script (wrap / on / off / status, `--lid-closed`) and basic menu-bar toggle app |
| v0.1.02 | #2 | Presets 1h–5d + custom, draining-cup animation, timer/health notifications, display & disk controls, iCloud download helper |
| v0.2.03 | #3 | System Insights: own footprint, memory used/pressure, network throughput, AI apps, top memory/CPU |
| v0.2.04 | #4 | Fix Activity Monitor path on pre-Catalina macOS |
| v0.2.05 | #5 | Fix menu-bar hang: all subprocess work moved off the main thread; menu reads cached insights only |
| v0.3.06 | #6 | Lightweight by default: Background Monitoring opt-in with confirmation popup; Keep Disk Active defaults off |
| v0.4.07 | #7 | High-contrast 14 pt menu text, menu-bar countdown in last 15 min, one-time iCloud folder setup with hourly auto-download |
| v0.4.08 | #8 | Adopt v#.#.## versioning starting at v0.0.01, add this changelog, show the running version inside the menu |
| v0.5.09 | #9 | iCloud auto-download gets a timing submenu (30 min / 1 h / 3 h / 6 h) and resource intelligence: runs are skipped and retried later while the Mac is hot, memory is under pressure, or on battery |
