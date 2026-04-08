//
//  Photos_QR_ScannerApp.swift
//  Photos-QR-Scanner
//
//  Created by Scott Vorthmann on 8/30/25.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct Photos_QR_ScannerApp: App {
    init() {
        // Initialize the collector preferences manager at app startup
        _ = CollectorPreferencesManager.shared
        
        #if os(macOS)
        // Set custom app info for the About panel
        configureAboutPanel()
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(CollectorPreferencesManager.shared)
        }
        #if os(macOS)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Photos QR Scanner") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: createAboutPanelOptions()
                    )
                }
            }
        }
        #endif
    }
    
    #if os(macOS)
    private func configureAboutPanel() {
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    private func createAboutPanelOptions() -> [NSApplication.AboutPanelOptionKey: Any] {
        var options: [NSApplication.AboutPanelOptionKey: Any] = [:]
        
        if let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String {
            options[.applicationName] = appName
        }
        
        let version = BuildInfo.marketingVersion
        let commitShort = String(BuildInfo.gitCommitSHA.prefix(8))
        options[.applicationVersion] = "\(version)"
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let commitText = "Commit: \(commitShort)"
        let descriptionText = "\n\nA tool for scanning QR codes and extracting metadata from photos."
        
        let credits = NSMutableAttributedString(string: commitText + descriptionText)
        
        credits.addAttributes([
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ], range: NSRange(location: 0, length: commitText.count))
        
        credits.addAttributes([
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ], range: NSRange(location: commitText.count, length: descriptionText.count))
        
        options[.credits] = credits
        
        return options
    }
    #endif
}
