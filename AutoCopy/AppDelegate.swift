import Cocoa
import Carbon
import ServiceManagement

// ─────────────────────────────────────────────
// AutoCopy — menu bar app that auto-copies any
// selected text by simulating ⌘C after mouse drag.
//
// This is the most reliable approach because it
// uses the same copy mechanism as doing it manually.
// Works with every app that supports ⌘C.
// ─────────────────────────────────────────────

class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var statusItem: NSStatusItem!
    private var toggleMenuItem: NSMenuItem!
    private var launchAtLoginMenuItem: NSMenuItem!

    private var isEnabled = true
    private var isDragging = false
    private var dragStartLocation: NSPoint = .zero
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // Minimum drag distance (points) to count as a text selection
    private let minDragDistance: CGFloat = 8.0

    // We save/restore the clipboard so we don't clobber the user's real clipboard
    // when the selection turns out to be empty
    private var savedClipboard: String?
    private var lastAutoCopiedText: String = ""

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // menu bar only, no dock icon

        setupStatusBar()

        if !acquireAccessibility() {
            return
        }

        startEventTap()

        // Track what's currently on the clipboard
        if let current = NSPasteboard.general.string(forType: .string) {
            lastAutoCopiedText = current
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopEventTap()
    }

    // MARK: - Accessibility Permission

    private func acquireAccessibility() -> Bool {
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        )
        if !trusted {
            // Show alert telling user to grant access and relaunch
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Accessibility Access Required"
                alert.informativeText = """
                AutoCopy needs Accessibility access to detect text selections.

                1. System Settings → Privacy & Security → Accessibility
                2. Find "AutoCopy" and toggle it ON
                3. Then relaunch AutoCopy

                (The system prompt should have appeared — if not, add AutoCopy manually.)
                """
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "Quit")
                NSApp.activate(ignoringOtherApps: true)
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
                NSApp.terminate(nil)
            }
            return false
        }
        return true
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        updateIcon()

        let menu = NSMenu()

        toggleMenuItem = NSMenuItem(title: "Disable AutoCopy", action: #selector(toggleEnabled), keyEquivalent: "")
        toggleMenuItem.target = self
        menu.addItem(toggleMenuItem)

        menu.addItem(NSMenuItem.separator())

        launchAtLoginMenuItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginMenuItem.target = self
        launchAtLoginMenuItem.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(launchAtLoginMenuItem)

        menu.addItem(NSMenuItem.separator())

        let about = NSMenuItem(title: "About AutoCopy", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        menu.addItem(NSMenuItem.separator())

        let quit = NSMenuItem(title: "Quit AutoCopy", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        if #available(macOS 11.0, *) {
            let name = isEnabled ? "doc.on.clipboard" : "doc.on.clipboard"
            if let img = NSImage(systemSymbolName: name, accessibilityDescription: "AutoCopy") {
                img.isTemplate = true
                button.image = img
                button.contentTintColor = isEnabled ? nil : .systemGray
            }
        } else {
            button.title = isEnabled ? "📋" : "⏸"
        }
        button.toolTip = isEnabled ? "AutoCopy: ON" : "AutoCopy: OFF"
    }

    private func flashConfirmation() {
        guard let button = statusItem.button else { return }
        if #available(macOS 11.0, *) {
            if let img = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Copied") {
                img.isTemplate = true
                button.image = img
                button.contentTintColor = .systemGreen
            }
        } else {
            button.title = "✅"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            self?.updateIcon()
        }
    }

    // MARK: - Event Tap (global mouse monitoring)
    //
    // We install a CGEvent tap to see ALL mouse events system-wide.
    // On left-mouse-down we record the start position.
    // On left-mouse-up, if the mouse moved far enough (a drag),
    // we simulate ⌘C to copy whatever was just selected.

    private func startEventTap() {
        let mask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.leftMouseUp.rawValue)

        // Store self in a pointer the C callback can access
        let selfPtr = Unmanaged.passRetained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { (proxy, type, event, userInfo) -> Unmanaged<CGEvent>? in
                guard let userInfo = userInfo else {
                    return Unmanaged.passUnretained(event)
                }
                let me = Unmanaged<AppDelegate>.fromOpaque(userInfo).takeUnretainedValue()
                me.handleCGEvent(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPtr
        ) else {
            print("❌ Failed to create event tap. Accessibility may not be granted.")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func stopEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handleCGEvent(type: CGEventType, event: CGEvent) {
        // If the tap gets disabled by the system (e.g. due to timeout), re-enable it
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return
        }

        guard isEnabled else { return }

        let clickCount = event.getIntegerValueField(.mouseEventClickState)

        if type == .leftMouseDown {
            dragStartLocation = NSPoint(
                x: CGFloat(event.location.x),
                y: CGFloat(event.location.y)
            )
            isDragging = true
        }
        else if type == .leftMouseUp {
            isDragging = false

            // Double-click (selects word) or triple-click (selects line/paragraph)
            if clickCount >= 2 {
                // Slightly longer delay for multi-click so the app finishes
                // expanding the selection to the full word/line
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.simulateCopyAndCheck()
                }
                return
            }

            // Single click release — check if it was a drag-select
            let endLocation = NSPoint(
                x: CGFloat(event.location.x),
                y: CGFloat(event.location.y)
            )
            let dx = endLocation.x - dragStartLocation.x
            let dy = endLocation.y - dragStartLocation.y
            let distance = sqrt(dx * dx + dy * dy)

            if distance >= minDragDistance {
                // Drag-select. Simulate ⌘C after a short delay.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.simulateCopyAndCheck()
                }
            }
        }
    }

    // MARK: - Simulate ⌘C

    private func simulateCopyAndCheck() {
        // Save what's currently on the clipboard
        let pb = NSPasteboard.general
        let previousCount = pb.changeCount
        let previousText = pb.string(forType: .string) ?? ""

        // Simulate Cmd+C
        simulateKeystroke(keyCode: UInt16(kVK_ANSI_C), flags: .maskCommand)

        // Check clipboard after a tiny delay (give the app time to process)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self = self else { return }
            let newCount = pb.changeCount
            let newText = pb.string(forType: .string) ?? ""

            // Only flash if something actually got copied that's new
            if newCount != previousCount && !newText.isEmpty && newText != self.lastAutoCopiedText {
                self.lastAutoCopiedText = newText
                self.flashConfirmation()
            } else if newCount == previousCount {
                // ⌘C didn't change the clipboard — nothing was selected (just a click-drag
                // on a non-text element like scrollbar, window move, etc.)
                // No action needed, clipboard stays as-is.
            }
        }
    }

    private func simulateKeystroke(keyCode: UInt16, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .combinedSessionState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return
        }

        keyDown.flags = flags
        keyUp.flags = flags

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    // MARK: - Toggle

    @objc private func toggleEnabled() {
        isEnabled.toggle()
        toggleMenuItem.title = isEnabled ? "Disable AutoCopy" : "Enable AutoCopy"
        updateIcon()
    }

    // MARK: - Launch at Login

    @objc private func toggleLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                    launchAtLoginMenuItem.state = .off
                } else {
                    try SMAppService.mainApp.register()
                    launchAtLoginMenuItem.state = .on
                }
            } catch {
                let a = NSAlert()
                a.messageText = "Launch at Login"
                a.informativeText = "Could not update: \(error.localizedDescription)\n\nAdd manually via System Settings → General → Login Items."
                a.runModal()
            }
        } else {
            let a = NSAlert()
            a.messageText = "Launch at Login"
            a.informativeText = "On macOS 12 or earlier, add AutoCopy manually:\nSystem Settings → Users & Groups → Login Items"
            a.runModal()
        }
    }

    private func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    // MARK: - About / Quit

    @objc private func showAbout() {
        let a = NSAlert()
        a.messageText = "AutoCopy"
        a.informativeText = "Automatically copies any text you select.\n\nDetects drag-selection, double-click (word), and triple-click (line).\nWorks in any app that supports ⌘C.\n\nVersion 2.1"
        a.alertStyle = .informational
        a.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        a.runModal()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
