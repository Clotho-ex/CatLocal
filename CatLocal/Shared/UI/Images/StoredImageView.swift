import SwiftUI
import UIKit

struct StoredImageView<Placeholder: View>: View {
    let path: String
    let contentMode: ContentMode
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var didFailToLoad = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder()
                    .accessibilityLabel(
                        didFailToLoad
                            ? "Stored image unavailable".catLocalized
                            : "Stored image loading".catLocalized
                    )
            }
        }
        .task(id: path) {
            let requestedPath = path
            let cacheKey = requestedPath as NSString
            image = nil
            didFailToLoad = false

            if let cachedImage = StoredImageCache.shared.image(forKey: cacheKey) {
                image = cachedImage
                return
            }

            do {
                let data = try await CatImageStore.shared.data(at: requestedPath)
                let decodedImage = await Task.detached(priority: .utility) {
                    UIImage(data: data)
                }.value
                guard !Task.isCancelled, path == requestedPath else { return }
                image = decodedImage
                if let decodedImage {
                    StoredImageCache.shared.insert(decodedImage, forKey: cacheKey)
                } else {
                    didFailToLoad = true
                }
            } catch {
                guard !Task.isCancelled, path == requestedPath else { return }
                image = nil
                didFailToLoad = true
            }
        }
    }
}

private final class StoredImageCache: @unchecked Sendable {
    static let shared = StoredImageCache()

    private let cache = NSCache<NSString, UIImage>()

    func image(forKey key: NSString) -> UIImage? {
        cache.object(forKey: key)
    }

    func insert(_ image: UIImage, forKey key: NSString) {
        cache.setObject(image, forKey: key)
    }
}
