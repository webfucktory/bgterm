import XCTest
import SwiftTerm

final class ShellSessionTests: XCTestCase {
    func testEchoReachesTerminalBuffer() {
        let sem = DispatchSemaphore(value: 0)
        let headless = HeadlessTerminal(
            queue: DispatchQueue.global(qos: .userInitiated),
            options: TerminalOptions(cols: 80, rows: 24)
        ) { _ in
            sem.signal()
        }
        headless.process.startProcess(executable: "/bin/echo", args: ["bgterm-ok"])

        let result = sem.wait(timeout: .now() + 10)
        XCTAssertEqual(result, .success, "shell process did not exit within timeout")

        // Allow the final dataReceived callback to flush into the buffer.
        Thread.sleep(forTimeInterval: 0.2)

        let terminal: Terminal = headless.terminal
        var found = false
        for row in 0..<terminal.rows {
            if let line = terminal.getLine(row: row)?.translateToString(trimRight: true),
               line.contains("bgterm-ok") {
                found = true
                break
            }
        }
        XCTAssertTrue(found, "expected echoed text in terminal buffer")
    }
}
