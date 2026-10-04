import PhotosUI
import SwiftUI
import UIKit

/// 娃娃选择区：内置默认娃娃 + 从相册添加 + 点选切换 + 删除自定义。
struct DollSectionView: View {
    @Bindable var settings: SettingsStore
    @State private var dolls: [String] = []
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("娃娃形象")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(dolls, id: \.self) { dollID in
                        dollCell(dollID)
                    }

                    PhotosPicker(selection: $photoItem, matching: .images) {
                        VStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .semibold))
                            Text("从相册添加")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(Color.deepSeekBlue)
                        .frame(width: 64, height: 88)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.deepSeekBlue.opacity(0.5),
                                              style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .onAppear { reload() }
        .onChange(of: photoItem) { _, item in
            Task { await addDoll(from: item) }
        }
    }

    private func dollCell(_ dollID: String) -> some View {
        ZStack(alignment: .topTrailing) {
            DollThumbView(dollID: dollID,
                          selected: DollStore.shared.resolvedID(stored: settings.activeDollID) == dollID)
                .onTapGesture { settings.activeDollID = dollID }

            if dollID != DollStore.defaultDollID {
                Button {
                    deleteDoll(dollID)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white, .black.opacity(0.55))
                        .padding(4)
                }
                .accessibilityLabel("删除这个娃娃")
            }
        }
    }

    private func reload() {
        dolls = DollStore.shared.allDollIDs()
    }

    private func addDoll(from item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        if let name = try? DollStore.shared.add(image: image) {
            settings.activeDollID = name
        }
        reload()
        photoItem = nil
    }

    private func deleteDoll(_ dollID: String) {
        DollStore.shared.delete(dollID: dollID)
        if settings.activeDollID == dollID {
            settings.activeDollID = DollStore.defaultDollID
        }
        reload()
    }
}

/// 单个娃娃缩略图。
struct DollThumbView: View {
    let dollID: String
    let selected: Bool

    var body: some View {
        Group {
            if let url = DollStore.shared.url(for: dollID),
               let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(.tertiarySystemGroupedBackground)
                    .overlay(Text("🍙").font(.system(size: 28)))
            }
        }
        .frame(width: 64, height: 88)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(selected ? Color.deepSeekBlue : Color.clear, lineWidth: 2.5)
        )
    }
}
