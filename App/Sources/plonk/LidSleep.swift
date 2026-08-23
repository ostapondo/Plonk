import Foundation
import IOKit
import IOKit.pwr_mgt

// Sleep on lid close is a forced sleep, not an idle one: no power assertion
// holds it off, and the only lever macOS offers is pmset's system-wide
// SleepDisabled, which needs root. So this is not another assertion beside
// AwakeManager's — it is one admin prompt, and a root guard left behind to put
// the setting back.
//
// The guard is a shell loop running as root watching two things: a flag file
// this app owns, and whether any copy of Plonk is still running. Either one
// going away restores sleep. That is what pays for the prompt: switching the
// toggle off never asks again (the app deletes the flag), and neither does
// quitting or crashing.
//
// It tolerates a minute without Plonk before it gives up, so an update, a
// rebuild or a crash-and-relaunch keeps the hold rather than asking for the
// password again on the way back in. A launch that finds the guard still up
// adopts it and asks for nothing.

final class LidSleep {
    /// How often the root guard checks whether it is still wanted. Two seconds
    /// is a `sleep` in a shell loop; nobody pays for it, and nobody waiting for
    /// their Mac to sleep again notices it either.
    static let pollSeconds = 2
    /// How long the guard waits out a Mac with no Plonk on it before putting
    /// sleep back. Long enough to cover a relaunch, short enough that a Mac
    /// whose Plonk is gone for good is sleeping again within the minute.
    static let graceSeconds = 60

    /// Whether a guard of ours is up. Not the same as `systemSleepDisabled`:
    /// the user may have run `pmset` themselves, and that is not ours to touch.
    private(set) var isArmed = false
    /// Set while the password prompt is up. `apply` runs on every config write,
    /// and a modal dialog is exactly the wrong thing to start twice.
    private var prompting = false
    /// Called when the password prompt is refused, so the switch can go back to
    /// off rather than claim something that did not happen.
    var onRefused: (() -> Void)?
    var onChange: (() -> Void)?

    /// Whether this Mac has a lid at all. A desktop has no clamshell state, and
    /// the switch is hidden there rather than offered and useless.
    static var hasLid: Bool { rootDomainProperty("AppleClamshellState") != nil }

    /// What pmset last wrote, read straight off IOPMrootDomain so it costs
    /// nothing and needs no privileges.
    static var systemSleepDisabled: Bool { rootDomainProperty("SleepDisabled") as? Bool == true }

    /// Whether a guard from an earlier run is still up. Called once at launch,
    /// before the first `apply`: a hold that outlived the app it was made in is
    /// picked back up rather than asked for again.
    func adopt() {
        isArmed = Self.systemSleepDisabled && Self.guardIsRunning
    }

    func apply(_ config: Config) {
        let wanted = config.awakeLidClosed && config.isEnabled(.awake) && Self.hasLid
        guard wanted != isArmed, !prompting else { return }
        if wanted { arm() } else { disarm() }
    }

    private func arm() {
        let flag = Self.flagURL
        guard Self.isShellSafe(flag.path) else { return }
        try? FileManager.default.createDirectory(at: flag.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        guard FileManager.default.createFile(atPath: flag.path, contents: nil) else { return }
        prompting = true
        let ok = Self.runAsRoot(Self.guardScript(flagPath: flag.path))
        prompting = false
        guard ok else {
            try? FileManager.default.removeItem(at: flag)
            onRefused?()
            return
        }
        isArmed = true
        onChange?()
    }

    /// Deleting the flag is the whole of it: the root guard sees it go and puts
    /// sleep back on its own, which is why switching off costs no password.
    private func disarm() {
        try? FileManager.default.removeItem(at: Self.flagURL)
        isArmed = false
        onChange?()
    }

    /// Beside the config rather than in a temporary directory, because the
    /// guard has to find the same file again after the app that made it has
    /// been replaced by a new copy of itself.
    static var flagURL: URL {
        ConfigStore.supportDirectory.appendingPathComponent("lid-guard")
    }

    /// The guard names the flag in its own command line, so asking whether one
    /// is up is a `pgrep` for that path.
    private static var guardIsRunning: Bool {
        let pgrep = Process()
        pgrep.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        pgrep.arguments = ["-f", flagURL.path]
        pgrep.standardOutput = FileHandle.nullDevice
        pgrep.standardError = FileHandle.nullDevice
        do {
            try pgrep.run()
            pgrep.waitUntilExit()
        } catch {
            return false
        }
        return pgrep.terminationStatus == 0
    }

    /// Built as one string so it can be read, and tested, without a password.
    /// stdin and both output streams are closed off the background job because
    /// `do shell script` waits for the pipes rather than for the process.
    static func guardScript(flagPath: String) -> String {
        let pmset = "/usr/bin/pmset -a disablesleep"
        let watch = "missing=0; while [ -f \"\(flagPath)\" ]; do "
            + "if /usr/bin/pgrep -x plonk >/dev/null 2>&1; then missing=0; "
            + "else missing=$((missing+\(pollSeconds))); fi; "
            + "[ \"$missing\" -ge \(graceSeconds) ] && break; /bin/sleep \(pollSeconds); done; "
            + "\(pmset) 0; /bin/rm -f \"\(flagPath)\""
        return "\(pmset) 1\n/bin/sh -c '\(watch)' </dev/null >/dev/null 2>&1 &"
    }

    /// The flag path is ours and never holds any of these, but it is spliced
    /// into a shell command inside an AppleScript literal, so it is checked
    /// rather than trusted.
    static func isShellSafe(_ path: String) -> Bool {
        !path.contains(where: { "'\"\\$`\n".contains($0) })
    }

    /// AppleScript string literals take the same escapes C does, and cannot
    /// span lines, so the newline between the two commands becomes one too.
    static func appleScriptLiteral(_ text: String) -> String {
        var escaped = ""
        for character in text {
            switch character {
            case "\\": escaped += "\\\\"
            case "\"": escaped += "\\\""
            case "\n": escaped += "\\n"
            default: escaped.append(character)
            }
        }
        return "\"\(escaped)\""
    }

    /// Returns false when the prompt is refused, which is the ordinary case and
    /// not an error worth reporting anywhere.
    private static func runAsRoot(_ shell: String) -> Bool {
        let source = "do shell script \(appleScriptLiteral(shell)) with administrator privileges"
        var failure: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&failure)
        return failure == nil
    }

    private static func rootDomainProperty(_ key: String) -> Any? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        return IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue()
    }
}
