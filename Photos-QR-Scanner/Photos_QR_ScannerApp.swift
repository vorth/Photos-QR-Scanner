//
//  Photos_QR_ScannerApp.swift
//  Photos-QR-Scanner
//
//  Created by Scott Vorthmann on 8/30/25.
//

import SwiftUI

@main
struct Photos_QR_ScannerApp: App {
    init() {
        // Initialize the collector preferences manager at app startup
        _ = CollectorPreferencesManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(CollectorPreferencesManager.shared)
        }
    }
}
