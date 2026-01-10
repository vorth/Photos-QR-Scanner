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
        
        // Set custom app info for the About panel
        configureAboutPanel()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(CollectorPreferencesManager.shared)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Photos QR Scanner") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: createAboutPanelOptions()
                    )
                }
            }
        }
    }
    
    private func configureAboutPanel() {
        // This sets the info for when the standard About panel is shown
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    private func createAboutPanelOptions() -> [NSApplication.AboutPanelOptionKey: Any] {
        var options: [NSApplication.AboutPanelOptionKey: Any] = [:]
        
        // App name
        if let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String {
            options[.applicationName] = appName
        }
        
        // Version string combining version and build
        let version = BuildInfo.marketingVersion
        let build = BuildInfo.buildNumber
        let commitShort = String(BuildInfo.gitCommitSHA.prefix(8))
        options[.applicationVersion] = "\(version)"
        
        // Credits with commit info
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let commitText = "Commit: \(commitShort)"
        let descriptionText = "\n\nA tool for scanning QR codes and extracting metadata from photos."
        
        let credits = NSMutableAttributedString(string: commitText + descriptionText)
        
        // Style for commit line - match version string
        credits.addAttributes([
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ], range: NSRange(location: 0, length: commitText.count))
        
        // Style for description - original styling
        credits.addAttributes([
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ], range: NSRange(location: commitText.count, length: descriptionText.count))
        
        options[.credits] = credits
        
        return options
    }
}
