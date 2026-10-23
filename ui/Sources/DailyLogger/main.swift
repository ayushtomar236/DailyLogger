import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    let force: Bool

    init(force: Bool) {
        self.force = force
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unless --force is passed, verify if already logged for the current cycle
        if !force {
            do {
                let hasLogged = try ProcessRunner.shared.hasLogged()
                if hasLogged {
                    print("Daily log already recorded for the current cycle. Suppressing prompt.")
                    NSApp.terminate(nil)
                    return
                }
            } catch {
                print("Warning: could not verify previous log status: \(error). Proceeding with prompt.")
            }
        }

        showPromptWindow()
    }

    func showPromptWindow() {
        let contentView = FloatingPromptView(
            onDismiss: { [weak self] in
                self?.window?.close()
                NSApp.terminate(nil)
            },
            onSaveSuccess: { [weak self] record in
                print("Daily log successfully saved with id: \(record.id)")
                self?.window?.close()
                NSApp.terminate(nil)
            }
        )

        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 380),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "Daily Logger"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.contentViewController = hostingController
        window.center()
        window.isReleasedWhenClosed = false

        self.window = window

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

// Entry Point
let args = CommandLine.arguments

if args.contains("--check") {
    do {
        let hasLogged = try ProcessRunner.shared.hasLogged()
        if hasLogged {
            print("Today's log has been recorded.")
            exit(0)
        } else {
            print("No log recorded yet for today.")
            exit(1)
        }
    } catch {
        print("Error checking log status: \(error)")
        exit(2)
    }
}

let isForce = args.contains("--force")

let app = NSApplication.shared
let delegate = AppDelegate(force: isForce)
app.delegate = delegate
app.run()
