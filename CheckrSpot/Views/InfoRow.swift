import SwiftUI

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.headline)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.body)
                .textSelection(.enabled)
        }
        .frame(maxWidth: 400, alignment: .leading)
    }
}