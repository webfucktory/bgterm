import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // menu-bar agent, no Dock icon
let coordinator = AppCoordinator()
app.delegate = coordinator
app.run()
