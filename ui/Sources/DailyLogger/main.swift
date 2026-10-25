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
        NotificationManager.shared.requestAuthorization()

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
                NotificationManager.shared.removeDeliveredNotifications()
                self?.window?.close()
                NSApp.terminate(nil)
            },
            onSaveSuccess: { [weak self] record in
                NotificationManager.shared.removeDeliveredNotifications()
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
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentViewController = hostingController
        window.center()
        window.isReleasedWhenClosed = false

        self.window = window
        NotificationManager.shared.window = window

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()

        NotificationManager.shared.postPromptNotification()
    }
}

// Status Diagnostic Check
func runStatusCheck() -> Int32 {
    print("=== Daily Logger System Status ===\n")
    var hasIssue = false

    // 1. LaunchAgent registration check
    let uid = getuid()
    let launchctlProc = Process()
    launchctlProc.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    launchctlProc.arguments = ["print", "gui/\(uid)/com.user.dailylogger"]
    launchctlProc.standardOutput = Pipe()
    launchctlProc.standardError = Pipe()

    var isLoaded = false
    do {
        try launchctlProc.run()
        launchctlProc.waitUntilExit()
        isLoaded = (launchctlProc.terminationStatus == 0)
    } catch {
        isLoaded = false
    }

    if isLoaded {
        print("✓ LaunchAgent: Loaded and active in launchd (gui/\(uid))")
    } else {
        print("✗ LaunchAgent: NOT loaded in launchd")
        print("  Fix: Run 'launchctl bootstrap gui/\(uid) ~/Library/LaunchAgents/com.user.dailylogger.plist' or run './setup.sh'")
        hasIssue = true
    }

    // 2. Plist file check
    let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
    let plistPath = "\(homeDir)/Library/LaunchAgents/com.user.dailylogger.plist"

    if FileManager.default.fileExists(atPath: plistPath) {
        let plutilProc = Process()
        plutilProc.executableURL = URL(fileURLWithPath: "/usr/bin/plutil")
        plutilProc.arguments = ["-lint", plistPath]
        plutilProc.standardOutput = Pipe()
        plutilProc.standardError = Pipe()
        var plistValid = false
        do {
            try plutilProc.run()
            plutilProc.waitUntilExit()
            plistValid = (plutilProc.terminationStatus == 0)
        } catch {
            plistValid = false
        }

        if plistValid {
            print("✓ LaunchAgent Plist: Valid (\(plistPath))")
        } else {
            print("✗ LaunchAgent Plist: Invalid syntax (\(plistPath))")
            hasIssue = true
        }
    } else {
        print("✗ LaunchAgent Plist: Missing at \(plistPath)")
        print("  Fix: Run './setup.sh' to generate and install it.")
        hasIssue = true
    }

    // 3. Today's log status
    do {
        let hasLogged = try ProcessRunner.shared.hasLogged()
        if hasLogged {
            print("✓ Today's Log: Recorded")
        } else {
            print("ℹ Today's Log: Pending (prompt will trigger at scheduled time)")
        }
    } catch {
        print("✗ Today's Log: Error checking status (\(error.localizedDescription))")
        hasIssue = true
    }

    // 4. Log files check
    let stdoutLog = "/tmp/DailyLogger.stdout.log"
    let stderrLog = "/tmp/DailyLogger.stderr.log"
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .short
    dateFormatter.timeStyle = .medium

    if FileManager.default.fileExists(atPath: stdoutLog) {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: stdoutLog),
           let modDate = attrs[.modificationDate] as? Date {
            print("✓ Stdout Log: \(stdoutLog) (last modified: \(dateFormatter.string(from: modDate)))")
        } else {
            print("✓ Stdout Log: \(stdoutLog)")
        }
    } else {
        print("- Stdout Log: \(stdoutLog) (no logs yet)")
    }

    if FileManager.default.fileExists(atPath: stderrLog) {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: stderrLog),
           let modDate = attrs[.modificationDate] as? Date {
            print("✓ Stderr Log: \(stderrLog) (last modified: \(dateFormatter.string(from: modDate)))")
        } else {
            print("✓ Stderr Log: \(stderrLog)")
        }
    } else {
        print("- Stderr Log: \(stderrLog) (no errors logged)")
    }

    print("")
    if hasIssue {
        print("Result: System issues detected. Please check the items marked with ✗ above.")
        return 1
    } else {
        print("Result: All systems operational.")
        return 0
    }
}

// Entry Point
let args = CommandLine.arguments

if args.contains("--status") {
    let code = runStatusCheck()
    exit(code)
}

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
