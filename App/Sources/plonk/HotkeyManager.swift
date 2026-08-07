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

    /// Action to key. Assigning re-registers if hotkeys are on.
    var bindings: [HotkeyAction: Hotkey] = [:] {
        didSet {
            guard enabled, bindings != oldValue else { return }
            unregister()
            register()
        }
    }

    /// Combinations another app already owns, so Settings can say so.
    private(set) var unavailable: [HotkeyAction] = []

    var onAction: ((HotkeyAction) -> Void)?

    func setEnabled(_ on: Bool) {
        guard on != enabled else { return }
        enabled = on
        if on {
            installHandlerIfNeeded()
            register()
        } else {
            unregister()
        }
    }

    private func register() {
        let signature = OSType(0x5348_594B) // 'SHYK'
        var taken: [HotkeyAction] = []
        for (index, action) in HotkeyAction.allCases.enumerated() {
            guard let hotkey = bindings[action] else { continue }
            let id = UInt32(index + 1)
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
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return noErr }
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            guard let action = manager.actions[hkID.id] else { return noErr }
            DispatchQueue.main.async { manager.onAction?(action) }
            return noErr
        }, 1, &eventType, selfPtr, nil)
    }
}
