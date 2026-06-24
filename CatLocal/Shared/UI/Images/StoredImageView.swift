import SwiftUI
import UIKit

struct StoredImageView<Placeholder: View>: View {
    let path: String
    let contentMode: ContentMode
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder()
            }
        }
        .task(id: path) {
            do {
                let data = try await CatImageStore.shared.data(at: path)
                image = UIImage(data: data)
            } catch {
                image = nil
            }
        }
    }
}
