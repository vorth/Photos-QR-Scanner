import Foundation

class CollectorPreferencesManager: ObservableObject {
    @Published var preferences: CollectorPreferences
    private let userDefaults = UserDefaults.standard
    private let preferencesKey = "CollectorPreferences"
    
    static let shared = CollectorPreferencesManager()
    
    private init() {
        self.preferences = CollectorPreferences()
        loadPreferences()
    }
    
    private func loadPreferences() {
        if let data = userDefaults.data(forKey: preferencesKey) {
            do {
                let decoder = JSONDecoder()
                self.preferences = try decoder.decode(CollectorPreferences.self, from: data)
                print("Loaded collector preferences from UserDefaults: \(preferences.getAllCollectors())")
            } catch {
                print("Error loading collector preferences from UserDefaults: \(error)")
                // Keep the default empty preferences on error
            }
        } else {
            print("No collector preferences found in UserDefaults, starting with empty preferences")
        }
    }
    
    func savePreferences() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(preferences)
            userDefaults.set(data, forKey: preferencesKey)
            print("Saved collector preferences to UserDefaults: \(preferences.getAllCollectors())")
        } catch {
            print("Error saving collector preferences to UserDefaults: \(error)")
        }
    }
    
    func addCollector(_ collector: String) {
        let trimmed = collector.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            preferences.addCollector(trimmed)
            savePreferences()
        }
    }
    
    func getAllCollectors() -> [String] {
        return preferences.getAllCollectors()
    }
    
    func clearAllCollectors() {
        preferences = CollectorPreferences()
        savePreferences()
    }
    
    // Debug method to show where UserDefaults data is stored
    func getStorageLocation() -> String {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "unknown"
        return "UserDefaults for bundle: \(bundleIdentifier)\nStored in sandbox at: ~/Library/Containers/\(bundleIdentifier)/Data/Library/Preferences/\(bundleIdentifier).plist"
    }
}