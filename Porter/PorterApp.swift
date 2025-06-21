//
//  PorterApp.swift
//  Porter
//
//  Created by zignis on 15/06/25.
//

import Sparkle
import SwiftUI

@main
struct PorterApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @StateObject private var monitor = ProcessMonitor()
    @State private var updaterController: SPUStandardUpdaterController?

    var body: some Scene {
        MenuBarExtra {
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

                if let updaterController {
                    MainView(monitor, updater: updaterController.updater)
                        .task { monitor.startPolling() }
                        .onDisappear {
                            DispatchQueue.main.async {
                                monitor.stopPolling()
                                monitor.resetStates()
                            }
                        }
                } else {
                    Text("Porter update checker has not been initialized yet.")
                        .padding()
                }
            }
        } label: {
            Image("app.zignis.porter")
                .onReceive(appDelegate.$updaterController) { newValue in
                    updaterController = newValue
                }
        }
        .menuBarExtraStyle(.window)
    }
}
