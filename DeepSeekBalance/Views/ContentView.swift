import SwiftUI

/// 主页：只显示余额卡片和娃娃；API Key 与全部设置收在右上角齿轮里。
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var settings: SettingsStore
    @State private var model: BalanceViewModel
    @State private var showSettings = false

    init() {
        let settings = SettingsStore()
        _settings = State(initialValue: settings)
        _model = State(initialValue: BalanceViewModel(settings: settings))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        BalanceCardView(model: model)
                        MascotCardView(model: model)
                    }
                    .padding(20)
                }
                .refreshable { await model.refresh() }
            }
            .navigationTitle("DeepSeek 余额")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityIdentifier("settings.open")
                    .accessibilityLabel("设置")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(model: model, settings: settings)
            }
        }
        .task { await model.refreshIfNeeded() }
        .task { await model.autoRefreshLoop() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task { await model.refreshOnForeground() }
                model.handleScenePhase(active: true)
            default:
                // .inactive / .background：尽早尝试弹出画中画余额窗（.inactive 时机最关键）
                model.handleScenePhase(active: false)
            }
        }
    }
}

#Preview {
    ContentView()
}
