//
//  ProcessListView.swift
//  Porter
//
//  Created by zignis on 16/06/25.
//

import SwiftUI

struct ProcessListView: View {
    @ObservedObject var monitor: ProcessMonitor

    init(_ monitor: ProcessMonitor) {
        self.monitor = monitor
    }

    var body: some View {
        Table(
            of: ProcessData.self,
            selection: $monitor.selectedProcesses,
            sortOrder: $monitor.sortOrder
        ) {
            TableColumn("Process Name", value: \.name) { item in
                HStack {
                    if let icon = item.icon {
                        icon
                            .resizable()
                            .frame(width: 18, height: 18)
                            .clipShape(
                                RoundedRectangle(cornerRadius: 8)
                            )
                    }

                    Text(item.name).padding(
                        .leading,
                        item.icon == nil ? 26 : 0
                    )
                    .textSelection(.enabled)
                }
                .padding(.leading, 5)
            }

            TableColumn("Port", value: \.port) { item in
                Text(String(item.port))
                    .textSelection(.enabled)
            }

            TableColumn("Protocol") { item in
                if let tcpState = item.tcpState {
                    let stateColor: Color =
                        switch tcpState {
                        case .listen: .blue
                        case .established: .green
                        case .closed: .red
                        }

                    HStack(alignment: .center) {
                        Text(item.proto.rawValue)
                        Text(tcpState.rawValue)
                            .font(.caption)
                            .fontDesign(.monospaced)
                            .fontWeight(.medium)
                            .foregroundStyle(
                                tcpState == .established ? .black : .white
                            )
                            .padding(.vertical, 0.75)
                            .padding(.horizontal, 4.25)
                            .background(stateColor)
                            .cornerRadius(4)
                    }
                } else {
                    Text(item.proto.rawValue)
                }
            }

            TableColumn("PID", value: \.pid) { item in
                Text(String(item.pid))
                    .textSelection(.enabled)
            }

            TableColumn("IP Version", value: \.ipVersion.rawValue)
        } rows: {
            ForEach(monitor.filteredProcesses) { process in
                TableRow(process)
                    .contextMenu {
                        Button("Copy PID") {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(
                                String(process.pid),
                                forType: .string
                            )
                        }
                        Button("Copy Port") {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(
                                String(process.port),
                                forType: .string
                            )
                        }
                        Divider()
                        Button("Kill process") {
                            monitor.killProcessById(process.id)
                        }
                    }
            }
        }
        .onChange(of: monitor.sortOrder) { _, sortOrder in
            monitor.processes.sort(using: sortOrder)
        }
        .tableStyle(.bordered)
        .scrollContentBackground(.visible)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .frame(maxWidth: .infinity)
        .frame(height: 240)
    }
}

#Preview {
    ProcessListView(ProcessMonitor(true))
}
