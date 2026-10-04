import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var settings: SettingsStore
    @State private var model: BalanceViewModel

    init() {
        let settings = SettingsStore()
        _settings = State(initialValue: settings)
        _model = State(initialValue: BalanceViewModel(settings: settings))
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    BalanceCardView(model: model)
                    MascotCardView(model: model)
                    KeySetupView(model: model)
                    PreferencesCardView(model: model, settings: settings)
                }
                .padding(20)
            }
            .refreshable { await model.refresh() }
        }
        .task { await model.refreshIfNeeded() }
        .task { await model.autoRefreshLoop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await model.refreshOnForeground() }
            }
        }
    }
}

#Preview {
    ContentView()
}
