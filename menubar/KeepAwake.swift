// KeepAwake — menu-bar toggle that stops your Mac from sleeping.
// Uses Apple's IOKit power-assertion API (the same one `caffeinate` uses).
// Build with menubar/build.sh — no Xcode project required.
//
// Features:
//   * Presets: 1h / 4h / 8h / 12h / 1 day / 2 days / 5 days / custom / indefinite
//   * Animated cup icon that drains as the timer counts down (Effects toggle)
//   * Notifications: timer start/15-min-left/finished, sleep interruptions,
//     AC power unplugged, high memory pressure, overheating (Health toggle)
//   * Display can sleep while the system stays awake; "Turn Display Off Now"
//   * Optional disk-idle prevention so HDD/iCloud sync keeps working
//   * "Download iCloud Folder Locally" helper (pulls cloud-only files to disk)

import AppKit
import IOKit.pwr_mgt

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var sysAssertion: IOPMAssertionID = 0
    private var displayAssertion: IOPMAssertionID = 0
    private var diskAssertion: IOPMAssertionID = 0
    private var active = false
    private var endDate: Date?
    private var totalSeconds: TimeInterval = 0
    private var tick: Timer?
    private var warnedNearEnd = false
    private var sleptWhileActive = false
    private var wasOnAC: Bool?
    private var memorySource: DispatchSourceMemoryPressure?
    private var memoryState = "normal"

    private let presets: [(label: String, hours: Double)] = [
        ("1 hour", 1), ("4 hours", 4), ("8 hours", 8), ("12 hours", 12),
        ("1 day", 24), ("2 days", 48), ("5 days", 120),
    ]

    // MARK: - Preferences

    private var effectsOn: Bool {   // cup animation + timer notifications
        get { UserDefaults.standard.object(forKey: "effects") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "effects") }
    }
    private var healthAlertsOn: Bool {   // memory / heat / power / interruption alerts
        get { UserDefaults.standard.object(forKey: "healthAlerts") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "healthAlerts") }
    }
    private var keepDisplayOn: Bool {   // default: let the display sleep, system stays awake
        get { UserDefaults.standard.object(forKey: "keepDisplay") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "keepDisplay") }
    }
    private var keepDiskOn: Bool {   // prevent disk idle so HDD/iCloud sync keeps flowing
        get { UserDefaults.standard.object(forKey: "keepDisk") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "keepDisk") }
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        refreshIcon()

        let wc = NSWorkspace.shared.notificationCenter
        wc.addObserver(self, selector: #selector(systemWillSleep),
                       name: NSWorkspace.willSleepNotification, object: nil)
        wc.addObserver(self, selector: #selector(systemDidWake),
                       name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(thermalChanged),
                                               name: ProcessInfo.thermalStateDidChangeNotification, object: nil)

        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            let critical = source.data.contains(.critical)
            self.memoryState = critical ? "critical" : "high"
            guard self.healthAlertsOn else { return }
            if critical {
                self.notify("Memory pressure critical",
                            "macOS is very low on memory. Close heavy apps or your background job may be killed.")
            } else {
                self.notify("Memory pressure high",
                            "Free memory is low (16 GB Mac). Consider closing browser tabs or apps to protect your job.")
            }
        }
        source.resume()
        memorySource = source
    }

    func applicationWillTerminate(_ notification: Notification) {
        stop(notifyUser: false)
    }

    // MARK: - Keep-awake core

    private func start(seconds: TimeInterval?, label: String) {
        stop(notifyUser: false)
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "KeepAwake menu bar toggle" as CFString, &id)
        guard result == kIOReturnSuccess else { NSSound.beep(); return }
        sysAssertion = id
        active = true
        warnedNearEnd = false
        sleptWhileActive = false
        wasOnAC = onACPower()
        if let seconds = seconds {
            totalSeconds = seconds
            endDate = Date(timeIntervalSinceNow: seconds)
        } else {
            totalSeconds = 0
            endDate = nil
        }
        applyOptionalAssertions()
        tick = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.onTick()
        }
        if effectsOn { notify("Keep Awake on", "Your Mac will stay awake \(label).") }
        refreshIcon()
    }

    private func stop(notifyUser: Bool) {
        tick?.invalidate()
        tick = nil
        endDate = nil
        if active {
            IOPMAssertionRelease(sysAssertion)
            active = false
        }
        releaseOptionalAssertions()
        if notifyUser && effectsOn {
            notify("Keep Awake off", "Normal sleep behavior restored.")
        }
        refreshIcon()
    }

    // Display / disk assertions follow their toggles while active.
    private func applyOptionalAssertions() {
        releaseOptionalAssertions()
        guard active else { return }
        if keepDisplayOn {
            var id: IOPMAssertionID = 0
            if IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                           IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                           "KeepAwake display" as CFString, &id) == kIOReturnSuccess {
                displayAssertion = id
            }
        }
        if keepDiskOn {
            var id: IOPMAssertionID = 0
            // "PreventDiskIdle" == kIOPMAssertPreventDiskIdle (IOPMLib.h)
            if IOPMAssertionCreateWithName("PreventDiskIdle" as CFString,
                                           IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                           "KeepAwake disk/iCloud" as CFString, &id) == kIOReturnSuccess {
                diskAssertion = id
            }
        }
    }

    private func releaseOptionalAssertions() {
        if displayAssertion != 0 { IOPMAssertionRelease(displayAssertion); displayAssertion = 0 }
        if diskAssertion != 0 { IOPMAssertionRelease(diskAssertion); diskAssertion = 0 }
    }

    private func onTick() {
        if let end = endDate {
            let remaining = end.timeIntervalSinceNow
            if remaining <= 0 {
                stop(notifyUser: false)
                if effectsOn { notify("Keep Awake finished", "Timer ended — normal sleep restored.") }
                return
            }
            if remaining <= 15 * 60 && !warnedNearEnd {
                warnedNearEnd = true
                if effectsOn { notify("15 minutes left", "Keep Awake ends soon. Pick a new duration to extend.") }
            }
        }
        let nowAC = onACPower()
        if let was = wasOnAC, was != nowAC, healthAlertsOn {
            notify(nowAC ? "AC power connected" : "Running on battery",
                   nowAC ? "Back on mains power." : "Charger unplugged! Plug in AC or your job may die with the battery.")
        }
        wasOnAC = nowAC
        refreshIcon()
    }

    // MARK: - System events

    @objc private func systemWillSleep(_ note: Notification) {
        if active { sleptWhileActive = true }
    }

    @objc private func systemDidWake(_ note: Notification) {
        guard sleptWhileActive else { return }
        sleptWhileActive = false
        if healthAlertsOn {
            notify("Keep Awake was interrupted",
                   "The Mac slept anyway (lid closed or forced sleep). Background work paused while asleep.")
        }
    }

    @objc private func thermalChanged(_ note: Notification) {
        guard healthAlertsOn else { return }
        switch ProcessInfo.processInfo.thermalState {
        case .serious:
            notify("Mac is running hot", "Performance is being throttled. Improve airflow or lighten the workload.")
        case .critical:
            notify("Mac is overheating", "Thermal state critical — macOS may force sleep. Reduce the load now.")
        default:
            break
        }
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let status = NSMenuItem(title: statusLine(), action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        if memoryState != "normal" {
            let mem = NSMenuItem(title: "Memory pressure: \(memoryState)", action: nil, keyEquivalent: "")
            mem.isEnabled = false
            menu.addItem(mem)
        }
        menu.addItem(.separator())

        let toggle = NSMenuItem(title: active ? "Turn Off" : "Keep Awake (until turned off)",
                                action: #selector(toggleIndefinite), keyEquivalent: "k")
        toggle.target = self
        menu.addItem(toggle)

        let presetMenu = NSMenu()
        for (i, preset) in presets.enumerated() {
            let item = NSMenuItem(title: preset.label, action: #selector(startPreset(_:)), keyEquivalent: "")
            item.target = self
            item.tag = i
            presetMenu.addItem(item)
        }
        presetMenu.addItem(.separator())
        let custom = NSMenuItem(title: "Custom…", action: #selector(startCustom), keyEquivalent: "")
        custom.target = self
        presetMenu.addItem(custom)
        let presetsItem = NSMenuItem(title: "Keep Awake For", action: nil, keyEquivalent: "")
        presetsItem.submenu = presetMenu
        menu.addItem(presetsItem)
        menu.addItem(.separator())

        addToggle(menu, "Effects (cup drains + timer alerts)", effectsOn, #selector(toggleEffects))
        addToggle(menu, "Health Alerts (memory / heat / power)", healthAlertsOn, #selector(toggleHealth))
        addToggle(menu, "Keep Display On", keepDisplayOn, #selector(toggleDisplay))
        addToggle(menu, "Keep Disk Active (HDD / iCloud sync)", keepDiskOn, #selector(toggleDisk))
        menu.addItem(.separator())

        let displayOff = NSMenuItem(title: "Turn Display Off Now", action: #selector(displayOffNow), keyEquivalent: "d")
        displayOff.target = self
        menu.addItem(displayOff)
        let icloud = NSMenuItem(title: "Download iCloud Folder Locally…", action: #selector(downloadICloudFolder), keyEquivalent: "")
        icloud.target = self
        menu.addItem(icloud)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit KeepAwake", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func addToggle(_ menu: NSMenu, _ title: String, _ on: Bool, _ action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.state = on ? .on : .off
        menu.addItem(item)
    }

    private func statusLine() -> String {
        guard active else { return "KeepAwake: off" }
        guard let end = endDate else { return "Awake until turned off" }
        let r = max(0, Int(end.timeIntervalSinceNow))
        let d = r / 86400, h = (r % 86400) / 3600, m = (r % 3600) / 60
        if d > 0 { return "Awake — \(d)d \(h)h left" }
        if h > 0 { return "Awake — \(h)h \(m)m left" }
        return "Awake — \(m)m left"
    }

    // MARK: - Actions

    @objc private func toggleIndefinite() {
        active ? stop(notifyUser: true) : start(seconds: nil, label: "until you turn it off")
    }

    @objc private func startPreset(_ sender: NSMenuItem) {
        let preset = presets[sender.tag]
        start(seconds: preset.hours * 3600, label: "for \(preset.label)")
    }

    @objc private func startCustom() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Custom duration"
        alert.informativeText = "How many hours should the Mac stay awake?\n(e.g. 36 = 1.5 days, 168 = 1 week)"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.placeholderString = "hours"
        alert.accessoryView = field
        alert.addButton(withTitle: "Start")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn,
              let hours = Double(field.stringValue.trimmingCharacters(in: .whitespaces)),
              hours > 0 else { return }
        start(seconds: hours * 3600, label: "for \(field.stringValue) hour(s)")
    }

    @objc private func toggleEffects() { effectsOn.toggle(); refreshIcon() }
    @objc private func toggleHealth() { healthAlertsOn.toggle() }
    @objc private func toggleDisplay() { keepDisplayOn.toggle(); applyOptionalAssertions() }
    @objc private func toggleDisk() { keepDiskOn.toggle(); applyOptionalAssertions() }

    @objc private func displayOffNow() {
        run("/usr/bin/pmset", ["displaysleepnow"])
    }

    // Pull cloud-only (evicted) iCloud files down to the local disk, so e.g. a
    // GitHub backup folder in iCloud Drive is fully copied locally.
    @objc private func downloadICloudFolder() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Download"
        panel.message = "Choose an iCloud Drive folder to fully download to this Mac"
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        var queued = 0
        let fm = FileManager.default
        try? fm.startDownloadingUbiquitousItem(at: url)
        if let walker = fm.enumerator(at: url, includingPropertiesForKeys: nil) {
            for case let file as URL in walker {
                if (try? fm.startDownloadingUbiquitousItem(at: file)) != nil { queued += 1 }
            }
        }
        notify("iCloud download started",
               queued > 0 ? "Requested download of \(queued) item(s). Keep the Mac awake until Finder shows no cloud icons."
                          : "Folder appears to be fully local already (or not in iCloud).")
    }

    // MARK: - Icon

    private func refreshIcon() {
        guard let button = statusItem?.button else { return }
        var fill: CGFloat = 0
        if active {
            if let end = endDate, totalSeconds > 0, effectsOn {
                fill = CGFloat(max(0, min(1, end.timeIntervalSinceNow / totalSeconds)))
            } else {
                fill = 1
            }
        }
        button.image = cupImage(fill: fill)
        button.toolTip = statusLine()
    }

    // Hand-drawn template cup: outline + coffee level (alpha-only, adapts to menu-bar theme).
    private func cupImage(fill: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            NSColor.black.setFill()
            let bodyRect = NSRect(x: 3, y: 4.5, width: 9, height: 9.5)
            let body = NSBezierPath(roundedRect: bodyRect, xRadius: 1.5, yRadius: 1.5)
            body.lineWidth = 1.3
            body.stroke()
            let handle = NSBezierPath()
            handle.appendArc(withCenter: NSPoint(x: 12.5, y: 9.5), radius: 2.7,
                             startAngle: -65, endAngle: 65, clockwise: false)
            handle.lineWidth = 1.3
            handle.stroke()
            let saucer = NSBezierPath()
            saucer.move(to: NSPoint(x: 2, y: 2.2))
            saucer.line(to: NSPoint(x: 14, y: 2.2))
            saucer.lineWidth = 1.3
            saucer.stroke()
            if fill > 0 {
                let inner = bodyRect.insetBy(dx: 1.8, dy: 1.8)
                let height = max(1.2, inner.height * fill)
                let coffee = NSRect(x: inner.minX, y: inner.minY, width: inner.width, height: height)
                NSBezierPath(roundedRect: coffee, xRadius: 0.8, yRadius: 0.8).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    // MARK: - Helpers

    private func onACPower() -> Bool {
        run("/usr/bin/pmset", ["-g", "batt"]).contains("AC Power")
    }

    @discardableResult
    private func run(_ path: String, _ args: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do { try process.run() } catch { return "" }
        process.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }

    // Notification via osascript: works for an unsigned, self-built app bundle.
    private func notify(_ title: String, _ text: String) {
        let escapedTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedText = text.replacingOccurrences(of: "\"", with: "\\\"")
        run("/usr/bin/osascript",
            ["-e", "display notification \"\(escapedText)\" with title \"\(escapedTitle)\""])
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // menu-bar only, no Dock icon
let delegate = AppDelegate()
app.delegate = delegate
app.run()
