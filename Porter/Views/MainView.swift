//
//  MainView.swift
//  Porter
//
//  Created by zignis on 15/06/25.
//

import Sparkle
import SwiftUI

struct MainView: View {
    @ObservedObject var monitor: ProcessMonitor
    private let updater: SPUUpdater?

    init(_ monitor: ProcessMonitor, updater: SPUUpdater? = nil) {
        self.monitor = monitor
        self.updater = updater
    }

    var body: some View {
        VStack(spacing: 0) {
            ProcessListView(monitor)
            Divider()
            ActionsView(monitor, updater: updater)
        }
        .frame(width: 520)
    }
}

#Preview {
    MainView(ProcessMonitor(true))
}
