import Foundation
import SwiftTerm

/// Thin façade over the user's login shell for the on-screen terminal.
/// The interactive terminal uses LocalProcessTerminalView (Task 6); this type
/// centralises the shell-resolution logic shared by both paths.
enum ShellSession {
    static func loginShell() -> String {
        ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    }

    static func defaultEnvironment() -> [String] {
        var env = Terminal.getEnvironmentVariables(termName: "xterm-256color")
        env.append("BGTERM=1")
        return env
    }
}
