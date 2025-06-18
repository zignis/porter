//
//  MainView.swift
//  Porter
//
//  Created by zignis on 15/06/25.
//

import SwiftUI

struct MainView: View {
    @ObservedObject var monitor: ProcessMonitor

    init(_ monitor: ProcessMonitor) {
        self.monitor = monitor
    }

    var body: some View {
        VStack(spacing: 0) {
            ProcessListView(monitor)
            Divider()
            ActionsView(monitor)
        }
        .frame(width: 520)
    }
}

#Preview {
    MainView(ProcessMonitor(true))
}
