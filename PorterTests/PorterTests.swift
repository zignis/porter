//
//  PorterTests.swift
//  PorterTests
//
//  Created by zignis on 15/06/25.
//

import Testing

@testable import Porter

struct PorterTests {
    @Test("`diffProcesses` returns correct results")
    func diffProcessesDetectsAddedAndRemoved() async throws {
        let p1 = ProcessData(
            name: "App 1",
            user: "zignis",
            pid: 1,
            port: 7000,
            proto: .tcp,
            ipVersion: .v6,
            tcpState: .listen,
            fileDescriptor: "FD1",
            icon: nil,
        )
        let p2 = ProcessData(
            name: "App 2",
            user: "zignis",
            pid: 2,
            port: 8080,
            proto: .tcp,
            ipVersion: .v4,
            tcpState: .established,
            fileDescriptor: "FD2",
            icon: nil,
        )

        let prev = [p1]
        let curr = [p1, p2]

        let diff = diffProcesses(prev, curr)
        #expect(diff.added.contains(p2))
        #expect(diff.removed.isEmpty)

        let diff2 = diffProcesses(curr, prev)
        #expect(diff2.removed.contains(p2))
        #expect(diff2.added.isEmpty)
    }

    @Test("Process monitor filters processes using search query")
    func processMonitorFiltersProcesses() async throws {
        let monitor = ProcessMonitor()
        let p1 = ProcessData(
            name: "Safari",
            user: "zignis",
            pid: 1,
            port: 7943,
            proto: .tcp,
            ipVersion: .v4,
            tcpState: .listen,
            fileDescriptor: "1",
            icon: nil,
        )
        let p2 = ProcessData(
            name: "Mail",
            user: "zignis",
            pid: 2,
            port: 5678,
            proto: .tcp,
            ipVersion: .v6,
            tcpState: nil,
            fileDescriptor: "2",
            icon: nil,
        )
        monitor.processes = [p1, p2]

        monitor.searchText = ""
        #expect(monitor.filteredProcesses.count == 2)

        monitor.searchText = "safari"
        #expect(monitor.filteredProcesses.contains(where: { $0 == p1 }))

        monitor.searchText = "5678"
        #expect(monitor.filteredProcesses.contains(where: { $0 == p2 }))

        monitor.searchText = "random"
        #expect(monitor.filteredProcesses.isEmpty)
    }
}
