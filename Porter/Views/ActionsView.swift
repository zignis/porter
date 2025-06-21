//
//  ActionsView.swift
//  Porter
//
//  Created by zignis on 16/06/25.
//

import AppKit
import LaunchAtLogin
import Sparkle
import SwiftUI

struct ActionsView: View {
    @ObservedObject var monitor: ProcessMonitor

    private let updater: SPUUpdater?
    private let build =
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    private let version =
        Bundle.main.infoDictionary?[
            "CFBundleShortVersionString",
        ] as? String

    init(_ monitor: ProcessMonitor, updater: SPUUpdater? = nil) {
        self.monitor = monitor
        self.updater = updater
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
                    ? "Kill processes" : "Kill process",
                role: .destructive,
            ) {
                monitor.killSelectedProcesses()
            }
            .disabled(monitor.selectedProcesses.isEmpty)

            Menu {
                if let version {
                    Text("Version \(version)").font(.callout)
                }

                Button(
                    "About Porter",
                    action: {
                        NSApp.keyWindow?.close()
                        NSApplication.shared.orderFrontStandardAboutPanel(
                            [
                                .version: version ?? "Unknown",
                                .applicationVersion: build ?? "Unknown",
                            ] as [NSApplication.AboutPanelOptionKey: Any],
                        )
                    },
                )

                if let updater {
                    UpdaterView(updater)
                }

                LaunchAtLogin.Toggle()

                Divider()

                Button(
                    "Quit",
                    action: {
                        NSApp.terminate(nil)
                    },
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
