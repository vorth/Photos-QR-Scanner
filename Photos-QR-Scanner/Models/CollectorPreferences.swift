import Foundation

struct CollectorPreferences: Codable {
    var collectorValues: Set<String>
    var lastCollector: String
    
    init() {
        self.collectorValues = Set<String>()
        self.lastCollector = ""
    }
    
    init(collectorValues: Set<String>, lastCollector: String = "") {
        self.collectorValues = collectorValues
        self.lastCollector = lastCollector
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        collectorValues = try container.decode(Set<String>.self, forKey: .collectorValues)
        lastCollector = try container.decodeIfPresent(String.self, forKey: .lastCollector) ?? ""
    }
    
    mutating func addCollector(_ collector: String) {
        let trimmed = collector.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            collectorValues.insert(trimmed)
            lastCollector = trimmed
        }
    }
    
    func getAllCollectors() -> [String] {
        return Array(collectorValues).sorted()
    }
}