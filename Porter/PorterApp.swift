//
//  PorterApp.swift
//  Porter
//
//  Created by zignis on 15/06/25.
//

import SwiftUI

@main
struct PorterApp: App {
    @StateObject private var monitor = ProcessMonitor()

    var body: some Scene {
        MenuBarExtra(
            "Porter",
            systemImage: "powerplug.portrait.fill"
        ) {
            ZStack {
                // See https://stackoverflow.com/a/78250554
                Color.clear
                    .contentShape(Rectangle())
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        DispatchQueue.main.async {
                            NSApp.keyWindow?.makeFirstResponder(nil)
                        }
                    }

                MainView(monitor)
                    .task {
                        monitor.startPolling()
                    }.onDisappear {
                        DispatchQueue.main.async {
                            monitor.stopPolling()
                            monitor.resetStates()
                        }
                    }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
