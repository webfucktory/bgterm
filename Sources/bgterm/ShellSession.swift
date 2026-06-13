import Foundation

/// Resolves the user's login shell and the environment to launch it with.
enum ShellSession {
    static func loginShell() -> String {
        ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    }

    /// argv[0] for the shell. A leading "-" makes it a login shell, which sources
    /// the user's profile (and macOS path_helper) so PATH and friends are set —
    /// otherwise a bundle-launched shell has a stripped environment and every
    /// command is "not found".
    static func loginArgv0() -> String {
        "-" + (loginShell() as NSString).lastPathComponent
    }

    /// Preferred starting directory: ~/repositories if it exists, else the
    /// shell's default (nil → home).
    static func startDirectory() -> String? {
        let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let repositories = (home as NSString).appendingPathComponent("repositories")
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: repositories, isDirectory: &isDir), isDir.boolValue {
            return repositories
        }
        return nil
    }

    /// Inherit the process environment (HOME, USER, …) and ensure terminal vars
    /// are set. PATH is populated by the login shell sourcing the profile.
    static func defaultEnvironment() -> [String] {
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        env["BGTERM"] = "1"
        return env.map { "\($0.key)=\($0.value)" }
    }
}
