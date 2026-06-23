import SwiftUI

struct CaptureView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            CatLocalTheme.ink
                .ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.thinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Close camera")

                    Spacer()

                    Label("On-device only", systemImage: "lock.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))
                }

                Spacer()

                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 78, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.88))

                Text("Meet them where they are")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)

                Text("Cat detection and card creation happen on this iPhone. Your photo is not uploaded or used to train a model.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.68))
                    .frame(maxWidth: 310)

                Spacer()

                Circle()
                    .stroke(.white, lineWidth: 4)
                    .frame(width: 76, height: 76)
                    .overlay {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .padding(7)
                    }
                    .accessibilityHidden(true)
            }
            .padding(24)
        }
    }
}

#Preview {
    CaptureView()
}
