import Foundation

struct CollectorPreferences: Codable {
    var collectorValues: Set<String>
    
    init() {
        self.collectorValues = Set<String>()
    }
    
    init(collectorValues: Set<String>) {
        self.collectorValues = collectorValues
    }
    
    mutating func addCollector(_ collector: String) {
        let trimmed = collector.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            collectorValues.insert(trimmed)
        }
    }
    
    func getAllCollectors() -> [String] {
        return Array(collectorValues).sorted()
    }
}