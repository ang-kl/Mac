// KeepAwake — a tiny menu-bar toggle that stops your Mac from sleeping.
// Uses Apple's IOKit power-assertion API (the same one `caffeinate` uses).
// Build with menubar/build.sh — no Xcode project required.

import AppKit
import IOKit.pwr_mgt

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var assertionID: IOPMAssertionID = 0
    private var active = false
    private var offTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateIcon()
        statusItem.menu = buildMenu()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stop()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        let toggle = NSMenuItem(title: "Keep Awake", action: #selector(toggleIndefinite), keyEquivalent: "k")
        toggle.target = self
        menu.addItem(toggle)
        menu.addItem(.separator())
        for hours in [1, 4, 8] {
            let item = NSMenuItem(title: "Keep Awake for \(hours)h", action: #selector(startTimed(_:)), keyEquivalent: "")
            item.target = self
            item.tag = hours
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit KeepAwake", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        menu.delegate = self
        return menu
    }

    @objc private func toggleIndefinite() {
        active ? stop() : start(hours: nil)
    }

    @objc private func startTimed(_ sender: NSMenuItem) {
        stop()
        start(hours: sender.tag)
    }

    private func start(hours: Int?) {
        var id: IOPMAssertionID = 0
        // PreventUserIdleSystemSleep keeps the system awake; the display may still dim.
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "KeepAwake menu bar toggle" as CFString,
            &id
        )
        guard result == kIOReturnSuccess else {
            NSSound.beep()
            return
        }
        assertionID = id
        active = true
        if let hours = hours {
            offTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(hours * 3600), repeats: false) { [weak self] _ in
                self?.stop()
            }
        }
        updateIcon()
    }

    private func stop() {
        offTimer?.invalidate()
        offTimer = nil
        if active {
            IOPMAssertionRelease(assertionID)
            active = false
        }
        updateIcon()
    }

    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        if #available(macOS 11.0, *) {
            let name = active ? "cup.and.saucer.fill" : "cup.and.saucer"
            if let image = NSImage(systemSymbolName: name, accessibilityDescription: "KeepAwake") {
                image.isTemplate = true
                button.image = image
                button.title = ""
                return
            }
        }
        button.image = nil
        button.title = active ? "☕︎" : "○"
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.items.first?.state = active ? .on : .off
        menu.items.first?.title = active ? "Keep Awake: On" : "Keep Awake"
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // menu-bar only, no Dock icon
let delegate = AppDelegate()
app.delegate = delegate
app.run()
