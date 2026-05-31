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
        HStack(spacing: 12) {
            Picker("View", selection: $selectedBottomTab) {
                Label("Photos", systemImage: "photo.on.rectangle")
                    .tag(BottomTab.photos)
                Label("Selected", systemImage: "list.bullet")
                    .tag(BottomTab.selected)
            }
            .pickerStyle(.segmented)

            Button {
                onOpenCamera()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "camera")
                    Image(systemName: hasPreciseLocationFix ? "location.fill" : "location.slash")
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
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
