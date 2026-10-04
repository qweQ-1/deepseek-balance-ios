import SwiftUI
import UniformTypeIdentifiers

/// 自定义音效区：给点按/喂饭/掉饭三种音效分别导入自己的音频。
struct SoundSectionView: View {
    @State private var customSet: Set<AppSound> = []
    @State private var importingSound: AppSound?

    private let player = SystemSoundPlayer()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("自定义音效（可选）")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            soundRow(title: "点按音效", sound: .pop)
            soundRow(title: "喂饭音效", sound: .eat)
            soundRow(title: "掉饭音效", sound: .ding)
        }
        .onAppear { refreshCustom() }
        .fileImporter(
            isPresented: Binding(
                get: { importingSound != nil },
                set: { if !$0 { importingSound = nil } }
            ),
            allowedContentTypes: [.audio]
        ) { result in
            handleImport(result)
        }
    }

    private func soundRow(title: String, sound: AppSound) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 13))
            if customSet.contains(sound) {
                Text("已自定义")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.orange)
            }
            Spacer()
            Button("试听") { player.play(sound) }
                .font(.system(size: 12))
            Button("选择…") { importingSound = sound }
                .font(.system(size: 12))
            if customSet.contains(sound) {
                Button("重置") {
                    SoundStore.shared.reset(sound)
                    refreshCustom()
                }
                .font(.system(size: 12))
                .foregroundStyle(.red)
            }
        }
    }

    private func refreshCustom() {
        customSet = Set(AppSound.allCases.filter { SoundStore.shared.hasCustom(for: $0) })
    }

    private func handleImport(_ result: Result<URL, Error>) {
        defer { importingSound = nil }
        guard let sound = importingSound, case .success(let url) = result else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        try? SoundStore.shared.importFile(from: url, for: sound)
        refreshCustom()
    }
}
