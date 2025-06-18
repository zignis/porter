//
//  ActionsView.swift
//  Porter
//
//  Created by zignis on 16/06/25.
//

import AppKit
import SwiftUI

struct ActionsView: View {
    @ObservedObject var monitor: ProcessMonitor

    init(_ monitor: ProcessMonitor) {
        self.monitor = monitor
    }

    var body: some View {
        HStack {
            TextField("Search...", text: $monitor.searchText)
                .textFieldStyle(.roundedBorder)
                .disabled(monitor.processes.isEmpty)
                .frame(width: 240)

            Spacer()

            Button(
                monitor.selectedProcesses.count > 1
                    ? "Kill processes" : "Kill process"
            ) {
                monitor.killSelectedProcesses()
            }
            .disabled(monitor.selectedProcesses.isEmpty)

            Menu {
                // TODO: Remove hardcoded version and add About & Update window
                Text("Version: 1.0").font(.callout)
                Button("About Porter", action: { print("about") })
                Button(
                    "Check for Updates",
                    action: { print("check updates") }
                )
                Divider()
                Button(
                    "Quit",
                    action: {
                        NSApp.terminate(nil)
                    }
                )
            } label: {
                Image(systemName: "ellipsis")
            }
            .fixedSize()
            .accessibilityLabel("More options")

        }
        .padding(10)
    }
}

#Preview {
    ActionsView(ProcessMonitor(true))
}
