# Mac

MacBook utilities. First up: **keepawake** — stop your Mac from sleeping while a long-running CLI job works (e.g. while you're travelling). Two flavours, both built only on Apple's own tools (`caffeinate`, IOKit, `pmset`), so they work on every MacBook — Air or Pro, Intel or Apple Silicon.

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

A tiny coffee-cup toggle in the menu bar. Build once on your Mac (needs the free Xcode Command Line Tools — `xcode-select --install`):

```sh
cd menubar && ./build.sh
open KeepAwake.app
```

Click the cup: **Keep Awake** (until you turn it off), or a timed 1h/4h/8h option. Filled cup = active. To have it start on login: System Settings → General → Login Items → add `KeepAwake.app`.

> First launch: if macOS warns the app is from an unidentified developer, right-click → Open (it's unsigned because you built it yourself).

## Travelling checklist

- Keep the Mac **plugged into AC power** — sleep prevention on battery is limited by design, and long jobs will drain it anyway.
- Prefer `keepawake -- <command>`: the Mac returns to normal by itself the moment your job finishes.
- If the lid must be closed, use `--lid-closed` and AC power.
- Set **System Settings → Lock Screen → Turn display off** as you like; the display can sleep while the system stays awake.
