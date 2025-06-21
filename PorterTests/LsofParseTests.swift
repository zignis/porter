//
//  LsofParseTests.swift
//  Porter
//
//  Created by zignis on 20/06/25.
//

import Testing

@testable import Porter

struct LsofParseTests {
    @Test(
        "Parses valid `lsof` command output",
        arguments: [
            // Single whitespaces
            """
            COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
            Porter 99 zignis 10u IPv4 0x0 0t0 TCP 127.0.0.1:8080 (LISTEN)
            """,
            // Multiple whitespaces
            """
            COMMAND    PID    USER    FD    TYPE    DEVICE    SIZE/OFF    NODE NAME
            Porter      99  zignis    10u   IPv4       0x0         0t0     TCP 127.0.0.1:8080 (LISTEN)
            """,
        ],
    )
    func parsesValidOutput(_ cmdOutput: String) throws {
        let result = parseLsofOutput(
            cmdOutput,
        )

        #expect(result.count == 1)

        let process = result.first!

        #expect(process.name == "Porter")
        #expect(process.pid == 99)
        #expect(process.user == "zignis")
        #expect(process.port == 8080)
        #expect(process.proto == .tcp)
        #expect(process.ipVersion == .v4)
        #expect(process.tcpState == .listen)
        #expect(process.fileDescriptor == "10u")
    }

    @Test(
        "Parses valid ports",
        arguments: [
            "*:7000", // Wildcard
            "127.0.0.1:7000", // IPv4
            "[2a04:4e42:0042:0000:0000:0000:0000:0396]:7000", // IPv6
            "[2a04:4e42:42::396]:7000", // IPv6 compressed
            "[2a02:aa09:1001:664c:68e1:3ce1:888f:463]:7000->[2a04:4e42:42::396]:443", // Local->Remote IPv6 entry
        ],
    )
    func parsesValidPorts(_ addr: String) throws {
        let result = parseLsofOutput(
            """
            COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
            Porter 99 zignis 10u IPv4 0x0 0t0 TCP \(addr) (LISTEN)
            """,
        )

        let process = result.first!
        #expect(process.port == 7000)
    }

    @Test(
        "Parses valid IP versions",
        arguments: IPVersion.allCases,
    )
    func parsesValidIPVersion(_ ipVersion: IPVersion) {
        let result = parseLsofOutput(
            """
            COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
            Porter 99 zignis 10u \(ipVersion.rawValue) 0x0 0t0 TCP 127.0.0.1:8080 (LISTEN)
            """,
        )

        let process = result.first!
        #expect(process.ipVersion == ipVersion)
    }

    @Test(
        "Parses valid network protocols",
        arguments: NetworkProtocol.allCases,
    )
    func parsesValidNetworkProtocol(_ proto: NetworkProtocol) {
        let result = parseLsofOutput(
            """
            COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
            Porter 99 zignis 10u IPv4 0x0 0t0 \(proto.rawValue.uppercased()) 127.0.0.1:8080\(proto == .tcp ? " (LISTEN)" : "")
            """,
        )

        let process = result.first!
        #expect(process.proto == proto)
    }

    @Test(
        "Parses valid TCP states",
        arguments: TCPState.allCases,
    )
    func parsesValidTCPStates(_ tcpState: TCPState) {
        let result = parseLsofOutput(
            """
            COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
            Porter 99 zignis 10u IPv4 0x0 0t0 TCP 127.0.0.1:8080 (\(tcpState.rawValue.uppercased()))
            """,
        )

        let process = result.first!
        #expect(process.tcpState == tcpState)
    }

    @Test("Skips invalid lines with missing columns")
    func skipsInvalidLines() {
        let result = parseLsofOutput(
            """
            COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
            not enough columns in this line
            Porter 99 zignis 10u IPv4 0x0 0t0 TCP 127.0.0.1:8080 (LISTEN)
            """,
        )

        #expect(result.count == 1)

        let process = result.first!
        #expect(process.name == "Porter")
    }

    @Test("Skips output with invalid header")
    func skipsInvalidHeader() {
        let result = parseLsofOutput(
            """
            COMMAND NODE NAME
            Porter TCP *:7000 (LISTEN)
            """,
        )
        #expect(result.isEmpty)
    }

    @Test("Skips lines with unknown network protocol")
    func skipsLinesWithUnknownNetProtocol() {
        let result = parseLsofOutput(
            """
            COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
            Porter 99 zignis 10u IPv4 0x0 0t0 XYZ 127.0.0.1:8080 (LISTEN)
            """,
        )
        #expect(result.isEmpty)
    }

    @Test("Skips lines with unknown IP version")
    func skipsLinesWithUnknownIPVersion() {
        let result = parseLsofOutput(
            """
            COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
            Porter 99 zignis 10u IPv0 0x0 0t0 TCP 127.0.0.1:8080 (LISTEN)
            """,
        )
        #expect(result.isEmpty)
    }

    @Test("Skips line if port can't be parsed")
    func skipsLineIfPortInvalid() {
        let result = parseLsofOutput(
            """
            COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
            Porter 99 zignis 10u IPv4 0x0 0t0 TCP *:* (CLOSED)
            """,
        )
        #expect(result.isEmpty)
    }
}
