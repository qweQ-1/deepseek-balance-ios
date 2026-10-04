import SwiftUI

/// 掉落的“白饭”。
struct RiceItem: Identifiable, Equatable {
    let id = UUID()
    let dropX: CGFloat   // 相对宽度 0...1
    let amount: Double
    let currency: String
}

/// 小饭团互动区：点按说话；检测到充值会掉落白饭，拖给小饭团吃。
struct MascotCardView: View {
    var model: BalanceViewModel
    @State private var rices: [RiceItem] = []
    @State private var mascotFrame: CGRect = .zero

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("小饭团")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if model.lastTopUp != nil {
                    Text("检测到充值，饭来啦 🍚")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                }
            }

            GeometryReader { geo in
                ZStack {
                    playArea
                    ForEach(rices) { rice in
                        RiceView(item: rice,
                                 containerSize: geo.size,
                                 mascotFrame: mascotFrame,
                                 onEat: { eat(rice) })
                    }
                }
                .coordinateSpace(.named("mascotPlay"))
            }
            .frame(height: 170)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .onChange(of: model.lastTopUp?.id) { _, newValue in
            if newValue != nil { dropRice() }
        }
        .onAppear {
            if model.lastTopUp != nil, rices.isEmpty { dropRice() }
        }
    }

    private var playArea: some View {
        VStack(spacing: 8) {
            ZStack {
                if let bubble = model.speechBubble {
                    Text(bubble.text)
                        .font(.system(size: 13))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.deepSeekBlue.opacity(0.14)))
                        .transition(.scale.combined(with: .opacity))
                        .id(bubble.id)
                        .accessibilityIdentifier("mascot.bubble")
                }
            }
            .frame(height: 34)
            .animation(.spring(duration: 0.25), value: model.speechBubble?.id)

            Button {
                model.mascotTapped()
            } label: {
                Text("🍙")
                    .font(.system(size: 72))
                    .shadow(color: .black.opacity(0.15), radius: 10, y: 6)
            }
            .buttonStyle(BounceButtonStyle())
            .accessibilityIdentifier("mascot.button")
            .accessibilityLabel("小饭团")
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { mascotFrame = geo.frame(in: .named("mascotPlay")) }
                        .onChange(of: geo.frame(in: .named("mascotPlay"))) { _, frame in
                            mascotFrame = frame
                        }
                }
            )

            Text("点我说话 · 把饭饭拖给我吃")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func dropRice() {
        guard let topup = model.lastTopUp else { return }
        let rice = RiceItem(dropX: CGFloat.random(in: 0.15...0.85),
                            amount: topup.amount,
                            currency: topup.currency)
        withAnimation(.spring(duration: 0.5)) {
            rices.append(rice)
        }
    }

    private func eat(_ rice: RiceItem) {
        model.feedRice(amount: rice.amount, currency: rice.currency)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation { rices.removeAll { $0.id == rice.id } }
        }
    }
}

/// 点按回弹效果。
struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.82 : 1)
            .animation(.spring(duration: 0.22, bounce: 0.5), value: configuration.isPressed)
    }
}

/// 一碗会掉下来、可以拖动喂饭的白饭。
private struct RiceView: View {
    let item: RiceItem
    let containerSize: CGSize
    let mascotFrame: CGRect
    let onEat: () -> Void

    @State private var dropped = false
    @State private var drag: CGSize = .zero
    @State private var eaten = false

    private var basePoint: CGPoint {
        CGPoint(x: containerSize.width * item.dropX, y: containerSize.height * 0.66)
    }

    private var point: CGPoint {
        CGPoint(x: basePoint.x + drag.width, y: basePoint.y + drag.height)
    }

    var body: some View {
        Text("🍚")
            .font(.system(size: 40))
            .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
            .scaleEffect(eaten ? 0.2 : 1)
            .opacity(eaten ? 0 : 1)
            .position(x: point.x, y: dropped ? point.y : -50)
            .onAppear {
                withAnimation(.spring(duration: 0.65, bounce: 0.4)) { dropped = true }
            }
            .gesture(
                DragGesture(coordinateSpace: .named("mascotPlay"))
                    .onChanged { value in drag = value.translation }
                    .onEnded { value in
                        let end = CGPoint(x: basePoint.x + value.translation.width,
                                          y: basePoint.y + value.translation.height)
                        if mascotFrame.insetBy(dx: -14, dy: -14).contains(end) {
                            withAnimation(.easeIn(duration: 0.15)) { eaten = true }
                            onEat()
                        } else {
                            withAnimation(.spring(duration: 0.3)) { drag = .zero }
                        }
                    }
            )
            .accessibilityIdentifier("mascot.rice")
    }
}
