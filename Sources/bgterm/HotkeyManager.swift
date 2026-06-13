import AppKit
import Carbon.HIToolbox

/// Registers a single global hotkey via the Carbon Events API.
final class HotkeyManager {
    /// A selectable reveal-hotkey preset.
    struct Option {
        let name: String
        let keyCode: UInt32
        let modifiers: UInt32
    }

    /// Presets offered in the tray menu (index persisted as Settings.hotkeyIndex).
    static let options: [Option] = [
        Option(name: "⌥⌘T", keyCode: UInt32(kVK_ANSI_T), modifiers: UInt32(optionKey | cmdKey)),
        Option(name: "⌃⌘T", keyCode: UInt32(kVK_ANSI_T), modifiers: UInt32(controlKey | cmdKey)),
        Option(name: "⌥⌘`", keyCode: UInt32(kVK_ANSI_Grave), modifiers: UInt32(optionKey | cmdKey)),
        Option(name: "⌥⌘Return", keyCode: UInt32(kVK_Return), modifiers: UInt32(optionKey | cmdKey)),
        Option(name: "⌃⌘Space", keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey | cmdKey)),
    ]

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    var onTrigger: (() -> Void)?

    /// Default: Option+Command+T. `id` must be unique per registered hotkey.
    func register(keyCode: UInt32 = UInt32(kVK_ANSI_T),
                  modifiers: UInt32 = UInt32(optionKey | cmdKey),
                  id: UInt32 = 1) {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { manager.onTrigger?() }
            return noErr
        }, 1, &eventType, selfPtr, &handlerRef)

        let hotKeyID = EventHotKeyID(signature: OSType(0x4247544D /* 'BGTM' */), id: id)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
        hotKeyRef = nil
        handlerRef = nil
    }
}
