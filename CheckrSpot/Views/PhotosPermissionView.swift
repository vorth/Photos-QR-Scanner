import SwiftUI

struct PhotosPermissionView: View {
    let onRequestAccess: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Photos Access Required")
                .font(.title2)

            Text("Please grant access to your Photos library")
                .foregroundColor(.secondary)

            Button("Grant Access") {
                onRequestAccess()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
