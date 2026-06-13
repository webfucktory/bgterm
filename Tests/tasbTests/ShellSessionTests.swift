import XCTest
import SwiftTerm

final class ShellSessionTests: XCTestCase {
    func testEchoReachesTerminalBuffer() {
        let sem = DispatchSemaphore(value: 0)
        let headless = HeadlessTerminal(options: TerminalOptions(cols: 80, rows: 24)) { _ in
            sem.signal()
        }
        headless.process.startProcess(executable: "/bin/echo", args: ["tasb-ok"])
        sem.wait()

        // Give the data callback a moment to flush into the terminal buffer.
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))

        let terminal = headless.terminal!
        var found = false
        for row in 0..<terminal.rows {
            if let line = terminal.getLine(row: row)?.translateToString(trimRight: true),
               line.contains("tasb-ok") {
                found = true
                break
            }
        }
        XCTAssertTrue(found, "expected echoed text in terminal buffer")
    }
}
