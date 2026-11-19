import AppKit
import Carbon.HIToolbox

// Global hotkeys via Carbon RegisterEventHotKey. Bindings come from config, so
// every one of them can be changed; HotkeyAction.defaultHotkey is only the
// starting point.

final class HotkeyManager {
    private var refs: [EventHotKeyRef] = []
    private var actions: [UInt32: HotkeyAction] = [:]
    private var handlerInstalled = false
    private var enabled = false
    private var suspended = false
    private var nextID: UInt32 = 0

    /// Action to key. Assigning re-registers if hotkeys are on.
    var bindings: [HotkeyAction: Hotkey] = [:] {
        didSet {
            guard enabled, !suspended, bindings != oldValue else { return }
            unregister()
            register()
        }
    }

    /// Combinations another app already owns, so Settings can say so.
    private(set) var unavailable: [HotkeyAction] = []

    var onAction: ((HotkeyAction) -> Void)?
    /// Fires when a bound key is released — what makes push-to-talk possible.
    var onActionUp: ((HotkeyAction) -> Void)?

    /// Take the settings as they now stand. Both halves guard on the value
    /// changing, so this is safe after every config write. Bindings first:
    /// enabling registers whatever is bound, and it should be the new set, not
    /// the old one for a moment.
    func apply(_ config: Config) {
        bindings = config.activeHotkeys
        setEnabled(config.hotkeysEnabled)
    }

    func setEnabled(_ on: Bool) {
        guard on != enabled else { return }
        enabled = on
        if on && !suspended {
            installHandlerIfNeeded()
            register()
        } else {
            unregister()
        }
    }

    func setSuspended(_ on: Bool) {
        guard on != suspended else { return }
        suspended = on
        if on {
            unregister()
        } else if enabled {
            installHandlerIfNeeded()
            register()
        }
    }

    private func register() {
        let signature = OSType(0x5348_594B) // 'SHYK'
        var taken: [HotkeyAction] = []
        for action in HotkeyAction.allCases {
            guard let hotkey = bindings[action] else { continue }
            nextID &+= 1
            let id = nextID
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(hotkey.keyCode, hotkey.carbonModifiers,
                                             EventHotKeyID(signature: signature, id: id),
                                             GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref {
                actions[id] = action
                refs.append(ref)
            } else {
                taken.append(action)
            }
        }
        unavailable = taken
        if !taken.isEmpty {
            let list = taken.compactMap { bindings[$0]?.display }.joined(separator: ", ")
            NSLog("Plonk: these hotkeys are already registered by another app: \(list)")
        }
    }

    private func unregister() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
        actions.removeAll()
        unavailable.removeAll()
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return noErr }
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            let id = hkID.id
            guard let action = manager.actions[id] else { return noErr }
            let released = GetEventKind(event) == UInt32(kEventHotKeyReleased)
            DispatchQueue.main.async {
                // A binding queued before a capture cannot fire after it was removed or restored.
                guard manager.actions[id] == action else { return }
                (released ? manager.onActionUp : manager.onAction)?(action)
            }
            return noErr
        }, 2, &eventTypes, selfPtr, nil)
    }
}
