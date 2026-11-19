import AppKit
import Carbon.HIToolbox

struct ShotSystemShortcut: Hashable {
    let code: UInt32
    let modifiers: UInt32

    static func enabled() -> Set<Self> {
        var shortcuts: Set<Self> = [Self(code: UInt32(kVK_Tab), modifiers: UInt32(cmdKey)),
                                    Self(code: UInt32(kVK_Tab), modifiers: UInt32(cmdKey | shiftKey))]
        var entries: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&entries) == noErr,
              let array = entries?.takeRetainedValue() as? [[String: NSNumber]] else { return shortcuts }
        for entry in array {
            guard entry["kHISymbolicHotKeyEnabled"]?.boolValue == true,
                  let code = entry["kHISymbolicHotKeyCode"]?.uint32Value, code != UInt32(UInt16.max),
                  let modifiers = entry["kHISymbolicHotKeyModifiers"]?.uint32Value else { continue }
            shortcuts.insert(Self(code: code, modifiers: modifiers))
        }
        return shortcuts
    }

    init(code: UInt32, modifiers: UInt32) {
        self.code = code
        self.modifiers = modifiers
    }

    init(event: CGEvent) {
        let flags = event.flags
        code = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
        let key = Hotkey(keyCode: code, control: flags.contains(.maskControl), option: flags.contains(.maskAlternate),
                         shift: flags.contains(.maskShift), command: flags.contains(.maskCommand))
        modifiers = key.carbonModifiers | (flags.contains(.maskSecondaryFn) ? UInt32(kEventKeyModifierFnMask) : 0)
    }
}
