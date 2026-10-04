import SwiftUI

/// 设置页：API Key 与全部偏好设置（从主页右上角齿轮进入）。
struct SettingsView: View {
    var model: BalanceViewModel
    @Bindable var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        KeySetupView(model: model)
                        PreferencesCardView(model: model, settings: settings)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
