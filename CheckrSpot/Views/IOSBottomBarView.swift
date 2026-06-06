#if os(iOS)
import SwiftUI

struct IOSBottomBarView: View {
    enum BottomTab {
        case photos
        case selected
    }

    @Binding var selectedBottomTab: BottomTab
    let hasPreciseLocationFix: Bool
    let onOpenCamera: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Picker("View", selection: $selectedBottomTab) {
                Label("Photos", systemImage: "photo.on.rectangle")
                    .tag(BottomTab.photos)
                Label("List", systemImage: "list.bullet")
                    .tag(BottomTab.selected)
            }
            .pickerStyle(.segmented)

            Button {
                onOpenCamera()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "camera")
                    Image(systemName: hasPreciseLocationFix ? "location.fill" : "location.slash")
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(hasPreciseLocationFix ? Color.green : Color.orange)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open camera")
            .accessibilityHint(hasPreciseLocationFix ? "Precise GPS location is available" : "Precise GPS location not available yet")
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}
#endif
