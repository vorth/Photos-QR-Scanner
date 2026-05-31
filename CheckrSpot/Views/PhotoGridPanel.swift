import SwiftUI
import Photos

struct PhotoGridPanel: View {
    let allPhotos: [PHAsset]
    let selectedIDs: Set<String>
    @Binding var thumbnailSize: Double
    let qrCodeResults: [String: String]
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

            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: thumbnailSize), spacing: 6)
                ], spacing: 6) {
                    ForEach(allPhotos.indices, id: \.self) { index in
                        let asset = allPhotos[index]
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
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
