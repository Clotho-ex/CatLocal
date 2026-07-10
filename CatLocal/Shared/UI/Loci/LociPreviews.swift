import SwiftUI

#Preview("Loci Poses - Light") {
    ScrollView {
        LazyVGrid(columns: [.init(.adaptive(minimum: 128))], spacing: 24) {
            ForEach(LociPose.allCases) { pose in
                LociPosePreviewRow(pose: pose)
            }
        }
        .padding(32)
    }
    .background(CatLocalTheme.background)
    .preferredColorScheme(.light)
}

#Preview("Loci Poses - Dark") {
    ScrollView {
        LazyVGrid(columns: [.init(.adaptive(minimum: 128))], spacing: 24) {
            ForEach(LociPose.allCases) { pose in
                LociPosePreviewRow(pose: pose)
            }
        }
        .padding(32)
    }
    .background(CatLocalTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Loci Empty Collection") {
    ZStack {
        CatLocalBackground()
        LociStateView(
            context: .emptyCollection,
            showsCard: true,
            buttonTitle: "Capture or Import",
            buttonAction: {}
        )
        .padding(.horizontal, CatLocalTheme.screenHorizontalPadding)
    }
    .preferredColorScheme(.light)
}

#Preview("Loci Warning Dark") {
    ZStack {
        CatLocalBackground()
        LociStateView(context: .noCatFound, mascotSize: 140)
            .padding(.horizontal, CatLocalTheme.screenHorizontalPadding)
    }
    .preferredColorScheme(.dark)
}

#Preview("Loci Motion States") {
    ZStack {
        CatLocalBackground()
        VStack(spacing: 22) {
            ForEach(LociContext.allCases) { context in
                HStack(spacing: 14) {
                    LociMascotView(state: .state(for: context), size: 88)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.title)
                            .font(CatTypography.supportingEmphasized)
                            .foregroundStyle(CatLocalTheme.primaryText)

                        Text(context.motion.rawValue)
                            .font(CatTypography.metadata)
                            .foregroundStyle(CatLocalTheme.secondaryText)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(32)
    }
    .preferredColorScheme(.light)
}

#Preview("Loci Motion States Dark") {
    ZStack {
        CatLocalBackground()
        VStack(spacing: 22) {
            ForEach(LociContext.allCases) { context in
                HStack(spacing: 14) {
                    LociMascotView(state: .state(for: context), size: 88)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.title)
                            .font(CatTypography.supportingEmphasized)
                            .foregroundStyle(CatLocalTheme.primaryText)

                        Text(context.motion.rawValue)
                            .font(CatTypography.metadata)
                            .foregroundStyle(CatLocalTheme.secondaryText)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(32)
    }
    .preferredColorScheme(.dark)
}

private struct LociPosePreviewRow: View {
    let pose: LociPose

    var body: some View {
        VStack(spacing: 8) {
            LociMascotView(pose: pose, size: pose == .icon ? 96 : 140)

            Text(pose.rawValue)
                .font(CatTypography.metadata)
                .foregroundStyle(CatLocalTheme.secondaryText)
        }
    }
}
