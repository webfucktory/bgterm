import Foundation

public enum TasbCore {
    public static let version = "0.1.0"
}

/// Minimal persistence seam so Settings can be unit-tested without UserDefaults.
public protocol KeyValueStore: AnyObject {
    func double(forKey key: String) -> Double?
    func integer(forKey key: String) -> Int?
    func bool(forKey key: String) -> Bool?
    func string(forKey key: String) -> String?
    func set(_ value: Any?, forKey key: String)
}

public struct Settings {
    private let store: KeyValueStore

    public init(store: KeyValueStore) {
        self.store = store
    }

    public var opacity: Double {
        get { store.double(forKey: "opacity") ?? 1.0 }
        set { store.set(min(1.0, max(0.1, newValue)), forKey: "opacity") }
    }

    public var fontSize: Int {
        get { store.integer(forKey: "fontSize") ?? 14 }
        set { store.set(max(6, newValue), forKey: "fontSize") }
    }

    public var fontName: String {
        get { store.string(forKey: "fontName") ?? "SF Mono" }
        set { store.set(newValue, forKey: "fontName") }
    }

    public var enabledOnLaunch: Bool {
        get { store.bool(forKey: "enabledOnLaunch") ?? true }
        set { store.set(newValue, forKey: "enabledOnLaunch") }
    }
}
