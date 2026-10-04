import SwiftUI

struct ContentView: View {
    @State private var model = BalanceViewModel()

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    BalanceCardView(model: model)
                    KeySetupView(model: model)
                }
                .padding(20)
            }
            .refreshable { await model.refresh() }
        }
        .task { await model.refreshIfNeeded() }
    }
}

#Preview {
    ContentView()
}
