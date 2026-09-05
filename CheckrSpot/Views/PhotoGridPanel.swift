import SwiftUI
import Photos

struct PhotoGridPanel: View {
    let allPhotos: [PHAsset]
    let selectedIDs: Set<String>
    @Binding var thumbnailSize: Double
    let qrCodeResults: [String: String]
    /// Photo to bring into view when the grid appears. The grid is rebuilt from
    /// scratch every time the user returns from another tab, so without this it
    /// would always restart at the top on the newest photos.
    let scrollTargetPhotoID: String?
    let onToggleSelection: (PHAsset) -> Void
    let onEditSelectedPhoto: (PHAsset) -> Void

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Recent Photos (\(allPhotos.count))")
                    .font(.headline)

                Spacer()

                Text("Size:")
                    .font(.caption)
                Slider(value: $thumbnailSize, in: 80...300, step: 20)
                    .frame(width: 100)
                Text("\(Int(thumbnailSize))px")
                    .font(.caption)
                    .frame(width: 40)
            }
            .padding()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: thumbnailSize), spacing: 6)
                    ], spacing: 6) {
                        ForEach(allPhotos, id: \.localIdentifier) { asset in
                            let isSelected = selectedIDs.contains(asset.localIdentifier)

                            ThumbnailView(
                                asset: asset,
                                isSelected: isSelected,
                                size: thumbnailSize,
                                onTap: {
                                    onToggleSelection(asset)
                                },
                                qrCodeResult: qrCodeResults[asset.localIdentifier],
                                onEdit: isSelected ? {
                                    onEditSelectedPhoto(asset)
                                } : nil
                            )
                            .id(asset.localIdentifier)
                        }
                    }
                    .padding(.horizontal)
                }
                .onAppear {
                    scrollToTarget(using: proxy)
                }
            }
        }
    }

    /// Scrolls without animation so returning to the tab looks like the grid was
    /// simply left in that position. Deferred to the next runloop pass because a
    /// LazyVGrid has not built its rows yet at `onAppear`, and `scrollTo` cannot
    /// reach a row that does not exist.
    private func scrollToTarget(using proxy: ScrollViewProxy) {
        guard let scrollTargetPhotoID else { return }

        DispatchQueue.main.async {
            proxy.scrollTo(scrollTargetPhotoID, anchor: .center)
        }
    }
}
