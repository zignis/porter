//
//  ProcessMonitorTests.swift
//  Porter
//
//  Created by zignis on 23/06/25.
//

import Testing

@testable import Porter

struct ProcessMonitorTests {
    @Test("`diffProcesses` returns correct results")
    func testDiffProcesses() async throws {
        let p1 = mockProcess(name: "App 1", pid: 1, port: 7000)
        let p2 = mockProcess(name: "App 2", pid: 2, port: 8080)
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
    func filtersProcesses() async throws {
        let monitor = TestableProcessMonitor()
        let p1 = mockProcess(name: "Safari", pid: 1, port: 7943)
        let p2 = mockProcess(name: "Mail", pid: 2, port: 5678)
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

    @Test("Kills processes in selection")
    func killsSelectedProcesses() {
        let monitor = TestableProcessMonitor()
        let p1 = mockProcess(pid: 1)
        let p2 = mockProcess(pid: 2)
        let p3 = mockProcess(pid: 3)
        let p4 = mockProcess(pid: 4)

        monitor.processes = [p1, p2, p3, p4]
        monitor.selectedProcesses = [p1.id, p3.id]
        monitor.killSelectedProcesses()

        #expect(monitor.processes == [p2, p4])
        #expect(monitor.selectedProcesses.isEmpty)
        #expect(monitor.killedPids.sorted() == [1, 3])
    }

    @Test("Kills a process by its ID")
    func killsProcessById() {
        let monitor = TestableProcessMonitor()
        let p1 = mockProcess(pid: 1)
        let p2 = mockProcess(pid: 2)

        monitor.processes = [p1, p2]
        monitor.selectedProcesses = [p1.id, p2.id]
        monitor.killProcessById(p1.id)

        #expect(monitor.processes == [p2])
        #expect(monitor.selectedProcesses == [p2.id])
        #expect(monitor.killedPids == [1])
    }

    @Test("Killing selected processes removes all entries with the same PID")
    func killingSelectedProcessesRemovesAllWithSamePid() {
        let monitor = TestableProcessMonitor()
        let p1a = mockProcess(pid: 1, port: 5000)
        let p1b = mockProcess(pid: 1, port: 6200)
        let p2 = mockProcess(pid: 2, port: 7890)

        monitor.processes = [p1a, p1b, p2]
        monitor.selectedProcesses = [p1a.id]
        monitor.killSelectedProcesses()

        #expect(monitor.processes == [p2])
        #expect(monitor.killedPids == [1])
    }

    @Test("Killing a process by its ID removes all entries with the same PID")
    func killingProcessByIdRemovesAllWithSamePid() {
        let monitor = TestableProcessMonitor()
        let p1a = mockProcess(pid: 1, port: 5000)
        let p1b = mockProcess(pid: 1, port: 6200)
        let p2 = mockProcess(pid: 2, port: 7890)

        monitor.processes = [p1a, p1b, p2]
        monitor.selectedProcesses = [p1a.id, p1b.id, p2.id]
        monitor.killProcessById(p1b.id)

        #expect(monitor.processes == [p2])
        #expect(monitor.selectedProcesses == [p2.id])
        #expect(monitor.killedPids == [1])
    }
}

func mockProcess(name: String = "Test Process", pid: Int, port: Int = 7800)
    -> ProcessData
{
    .init(
        name: name,
        user: "zignis",
        pid: pid,
        port: port,
        proto: .tcp,
        ipVersion: .v4,
        tcpState: .listen,
        fileDescriptor: "\(pid)-\(port)",
        icon: nil,
    )
}
