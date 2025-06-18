//
//  ProcessMonitor.swift
//  Porter
//
//  Created by zignis on 16/06/25.
//

import AppKit
import Foundation
import SwiftUI

enum NetworkProtocol: String {
    case tcp = "TCP"
    case udp = "UDP"
}

enum IPVersion: String {
    case v4 = "IPv4"
    case v6 = "IPv6"
}

enum TCPState: String {
    case listen = "LISTEN"
    case established = "ESTABLISHED"
    case closed = "CLOSED"
}

struct ProcessData: Identifiable, Equatable, Hashable {
    let name: String
    let user: String
    let pid: Int
    let port: Int
    let proto: NetworkProtocol
    let ipVersion: IPVersion
    let tcpState: TCPState?
    let fileDescriptor: String
    let icon: Image?

    var id: String {
        "\(pid):\(port):\(fileDescriptor):\(proto.rawValue)"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(user)
        hasher.combine(pid)
        hasher.combine(port)
        hasher.combine(proto)
        hasher.combine(ipVersion)
        hasher.combine(tcpState)
        hasher.combine(fileDescriptor)
    }

    static func == (lhs: ProcessData, rhs: ProcessData) -> Bool {
        return lhs.name == rhs.name && lhs.user == rhs.user
            && lhs.pid == rhs.pid && lhs.port == rhs.port
            && lhs.proto == rhs.proto && lhs.ipVersion == rhs.ipVersion
            && lhs.tcpState == rhs.tcpState
            && lhs.fileDescriptor == rhs.fileDescriptor
    }
}

/// Computes the difference between two lists of processes.
///
/// - Parameters:
///   - prev: The previous list of processes to compare from.
///   - curr: The current list of processes to compare against.
/// - Returns: A tuple containing:
///   - added: An array of processes that are present in `curr` but not in `prev`.
///   - removed: An array of processes that are present in `prev` but not in `curr`.
func diffProcesses(_ prev: [ProcessData], _ curr: [ProcessData]) -> (
    added: [ProcessData], removed: [ProcessData]
) {
    let prevSet = Set(prev)
    let currSet = Set(curr)
    let added = Array(currSet.subtracting(prevSet))
    let removed = Array(prevSet.subtracting(currSet))
    return (added, removed)
}

/// Returns the application's icon image using its PID.
///
/// - Parameter pid: The PID of the running application.
/// - Returns: An optional `Image` representing the application's icon, or `nil` if no icon is found.
func getIconForProcess(pid: Int) -> Image? {
    guard
        let app = NSRunningApplication(processIdentifier: pid_t(pid)),
        let icon = app.icon
    else {
        return nil
    }

    return Image(nsImage: icon)
}

/// Monitors and manages running processes.
class ProcessMonitor: ObservableObject {
    @Published var processes: [ProcessData] = []
    @Published var sortOrder = [KeyPathComparator(\ProcessData.name)]
    @Published var selectedProcesses = Set<ProcessData.ID>()
    @Published var searchText: String = ""

    var filteredProcesses: [ProcessData] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !query.isEmpty else { return processes }

        return processes.filter { process in
            process.name.lowercased().contains(query)
                || "\(process.port)".contains(query)
        }
    }

    private var timer: Timer?
    private var isBusyKilling: Bool = false
    private var lastProcesses: [ProcessData] = []
    private let timerInterval: TimeInterval = 1.0
    private let queue = DispatchQueue(
        label: "ProcessMonitorQueue",
        qos: .background
    )

    private static let lsofExecutablePath = "/usr/sbin/lsof"
    private static let killExecutablePath = "/bin/kill"
    private static let osascriptExecutablePath = "/usr/bin/osascript"

    /// Initializes a new `ProcessMonitor` instance.
    ///
    /// - Parameter startPollingImmediately: If `true`, starts polling processes immediately.
    init(_ startPollingImmediately: Bool = false) {
        checkLsofInstallation()

        if startPollingImmediately {
            startPolling()
        }
    }

    deinit {
        timer?.invalidate()
    }

    /// Starts polling for processes at regular intervals.
    public func startPolling() {
        if timer != nil { return }

        // Poll immediately for the first time
        pollProcesses()

        timer = Timer.scheduledTimer(
            withTimeInterval: timerInterval,
            repeats: true
        ) {
            [weak self] _ in
            self?.pollProcesses()
        }
    }

    /// Stops polling for processes and clears the search filter.
    public func stopPolling() {
        timer?.invalidate()
        timer = nil
        searchText = ""
    }

    /// Checks if `lsof` command is present and callable, prompting installation if missing.
    public func checkLsofInstallation() {
        guard
            !FileManager.default.isExecutableFile(
                atPath: Self.lsofExecutablePath
            )
        else { return }

        let alert = NSAlert()
        alert.messageText = "Required tool or permission missing"
        alert.informativeText =
            "Porter needs Xcode Command Line Tools (lsof), either not installed or lacking disk access. Click Install or grant access manually."
        alert.addButton(withTitle: "Install")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            let task = Process()
            task.launchPath = "/usr/bin/xcode-select"
            task.arguments = ["--install"]

            do {
                try task.run()

                let quitAlert = NSAlert()
                quitAlert.messageText = "Installation started"
                quitAlert.informativeText =
                    "Porter will now quit. Please reopen after the installation finishes."
                quitAlert.addButton(withTitle: "OK")
                quitAlert.runModal()
            } catch {
                print(
                    "failed to install Xcode Command Line Tools: \(error)"
                )

                let errorAlert = NSAlert()
                errorAlert.messageText = "Installation failed"
                errorAlert.informativeText =
                    "Porter was unable to install the Xcode Command Line Tools. Please install them manually and relaunch Porter."
                errorAlert.addButton(withTitle: "OK")
                errorAlert.runModal()
            }

            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }

    /// Resets temporary state variables.
    public func resetStates() {
        selectedProcesses.removeAll()
    }

    /// Kills a process identified by the given ID.
    ///
    /// - Parameter id: The ID of the process to kill.
    public func killProcessById(_ id: String) {
        guard let process = processes.first(where: { $0.id == id }) else {
            return
        }

        isBusyKilling = true

        defer {
            isBusyKilling = false
        }

        if let index = lastProcesses.firstIndex(where: { $0.id == id }) {
            lastProcesses.remove(at: index)
        }

        if let index = processes.firstIndex(where: { $0.id == id }) {
            processes.remove(at: index)
        }

        selectedProcesses.remove(process.id)

        runKill([process.pid])
    }

    /// Kills all processes currently selected.
    public func killSelectedProcesses() {
        guard !selectedProcesses.isEmpty else { return }

        isBusyKilling = true

        defer {
            isBusyKilling = false
        }

        let pidsToKill = processes.filter { selectedProcesses.contains($0.id) }
            .map { $0.pid }

        lastProcesses.removeAll { selectedProcesses.contains($0.id) }
        processes.removeAll { selectedProcesses.contains($0.id) }
        selectedProcesses.removeAll()
        runKill(pidsToKill)
    }

    /* Private methods */

    /// Polls the current running processes by executing the `lsof` command asynchronously.
    ///
    /// Parses the output and updates the process list if changes are detected.
    private func pollProcesses() {
        self.queue.async { [weak self] in
            guard let self = self else { return }
            guard !self.isBusyKilling else { return }

            let output = self.runLsof()
            var parsed = self.parseLsofOutput(output)
            let diff = diffProcesses(self.lastProcesses, parsed)

            parsed.sort(using: self.sortOrder)

            self.lastProcesses = parsed

            if !diff.added.isEmpty || !diff.removed.isEmpty {
                DispatchQueue.main.async {
                    self.processes = parsed
                }
            }
        }
    }

    /// Runs the `lsof` command to get a snapshot of open network connections.
    ///
    /// - Returns: The raw string output from the `lsof` command.
    private func runLsof() -> String {
        let task = Process()
        let pipe = Pipe()

        task.standardOutput = pipe
        task.executableURL = URL(fileURLWithPath: Self.lsofExecutablePath)
        task.arguments = ["-i", "-n", "-P"]

        do {
            try task.run()
        } catch {
            print("failed to exec `lsof`: \(error)")
            return ""
        }

        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Parses the output of the `lsof` command into an array of `ProcessData`.
    ///
    /// - Parameter output: The raw string output from `lsof`.
    /// - Returns: An array of `ProcessData` representing active processes.
    private func parseLsofOutput(_ output: String) -> [ProcessData] {
        var processes: [ProcessData] = []
        let lines = output.split(separator: "\n").dropFirst()

        for line in lines {
            let columns = line.split(
                separator: " ",
                omittingEmptySubsequences: true
            )

            guard columns.count >= 9 else { continue }

            let process = String(columns[0])
            let pid = Int(columns[1]) ?? -1
            let user = String(columns[2])
            let fileDescriptor = String(columns[3])
            let rawIpVersion = String(columns[4])
            let rawProto = String(columns[7])
            let addr = String(columns[8])
            let rawTcpState = columns.count >= 10 ? String(columns[9]) : nil

            guard let ipVersion = IPVersion(rawValue: rawIpVersion) else {
                continue
            }

            guard let proto = NetworkProtocol(rawValue: rawProto.uppercased())
            else { continue }

            if let portString = addr.split(separator: ":").last,
                let port = Int(portString.split(separator: " ").first ?? "")
            {
                let tcpState: TCPState? =
                    if let stateString = rawTcpState,
                        let state = TCPState(
                            rawValue:
                                // Replace `(` and `)` around TCP state value from `lsof`
                                stateString
                                .replacingOccurrences(of: "(", with: "")
                                .replacingOccurrences(of: ")", with: "")
                        )
                    {
                        state
                    } else { nil }

                processes.append(
                    ProcessData(
                        name: process,
                        user: user,
                        pid: pid,
                        port: port,
                        proto: proto,
                        ipVersion: ipVersion,
                        tcpState: tcpState,
                        fileDescriptor: fileDescriptor,
                        icon: getIconForProcess(pid: pid)
                    )
                )

            }
        }

        return processes
    }

    /// Sends the kill signal to the given PIDs.
    ///
    /// - Parameter pids: Array of PIDs to kill.
    private func runKill(_ pids: [Int]) {
        let serializedPids = pids.map { "\($0)" }
        let task = Process()

        task.executableURL = URL(fileURLWithPath: Self.killExecutablePath)
        task.arguments = ["-9"] + serializedPids

        do {
            try task.run()
            task.waitUntilExit()

            if task.terminationStatus != 0 {
                print("`kill` failed with exit code \(task.terminationStatus)")
                runKillUsingSudo(serializedPids)
            }
        } catch {
            print("failed to exec `kill`: \(error)")
            runKillUsingSudo(serializedPids)
        }
    }

    /// Tries to run the `kill` command with administrator privileges.
    ///
    /// - Parameter pids: Array of serialized PIDs to kill.
    private func runKillUsingSudo(_ pids: [String]) {
        let alert = NSAlert()
        alert.messageText = "Permission Required"
        alert.informativeText =
            "Porter lacks permission to kill \(pids.count == 1 ? "this process" : "some processes"). Admin privileges are required."
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")

        // Close menu window before showing alert
        NSApp.keyWindow?.close()

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let appleScript =
            "do shell script \"kill -9 \(pids.joined(separator: " "))\" with administrator privileges"
        let task = Process()
        task.launchPath = Self.osascriptExecutablePath
        task.arguments = ["-e", appleScript]

        do {
            try task.run()
            task.waitUntilExit()

            if task.terminationStatus != 0 {
                print(
                    "`sudo kill` failed with exit code \(task.terminationStatus)"
                )
                showKillFailedAlert(pids)
            }
        } catch {
            print("failed to exec `sudo kill`: \(error)")
            showKillFailedAlert(pids)
        }
    }

    /// Displays an alert when killing processes fails.
    ///
    /// - Parameter pids: Array of PIDs that failed to be killed.
    private func showKillFailedAlert(_ pids: [String]) {
        let alert = NSAlert()
        alert.messageText =
            "Failed to kill \(pids.count == 1 ? "process" : "processes")"
        alert.informativeText =
            "Porter was unable to terminate the selected \(pids.count == 1 ? "process" : "processes")."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
