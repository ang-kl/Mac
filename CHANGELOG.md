# Version history

Format: `v0.0.###` — a three-digit build counter starting at v0.0.001 with the
first release, incremented on every release. The running app shows its version
at the bottom of the cup menu; if it doesn't match the newest entry here,
rebuild (`cd menubar && ./build.sh`).

| Version | PR | Changes |
|---------|----|---------|
| v0.0.001 | #1 | First release: `keepawake` CLI script (wrap / on / off / status, `--lid-closed`) and basic menu-bar toggle app |
| v0.0.002 | #2 | Presets 1h–5d + custom, draining-cup animation, timer/health notifications, display & disk controls, iCloud download helper |
| v0.0.003 | #3 | System Insights: own footprint, memory used/pressure, network throughput, AI apps, top memory/CPU |
| v0.0.004 | #4 | Fix Activity Monitor path on pre-Catalina macOS |
| v0.0.005 | #5 | Fix menu-bar hang: all subprocess work moved off the main thread; menu reads cached insights only |
| v0.0.006 | #6 | Lightweight by default: Background Monitoring opt-in with confirmation popup; Keep Disk Active defaults off |
| v0.0.007 | #7 | High-contrast 14 pt menu text, menu-bar countdown in last 15 min, one-time iCloud folder setup with hourly auto-download |
| v0.0.008 | #8 | Versioning scheme, this changelog, running version shown inside the menu |
| v0.0.009 | #9 | iCloud auto-download timing submenu (30 min / 1 h / 3 h / 6 h) and resource intelligence (skip + retry while hot / low memory / on battery); version format finalized as v0.0.### |
| v0.0.010 | #11 | Auto-download also yields to AI work: scheduled runs are skipped and retried while Claude (CLI or app) or another AI process is actively using CPU |
| v0.0.011 | #12 | Fix faint insight text on modern macOS: info rows are enabled (non-dimmed) inert items, so the 14 pt full-contrast color actually renders |
| v0.0.012 | #13 | "Countdown Only While Idle" toggle (off by default): timed hours only burn while the Mac is untouched; status shows "(paused while you work)" during activity |
