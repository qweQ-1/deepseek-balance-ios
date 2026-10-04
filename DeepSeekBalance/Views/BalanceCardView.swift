import SwiftUI

/// 余额卡片：标题、状态、大金额、充值/赠送明细、更新时间。
struct BalanceCardView: View {
    var model: BalanceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            content
            if model.isLowBalance {
                lowBalanceBanner
            }
            if case .loaded = model.state {
                footer
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
    }

    // MARK: - 头部

    private var header: some View {
        HStack(spacing: 12) {
            Text("🐋")
                .font(.system(size: 24))
                .frame(width: 44, height: 44)
                .background(
                    LinearGradient(
                        colors: [.deepSeekBlue, .deepSeekBlueLight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 1) {
                Text("DeepSeek")
                    .font(.system(size: 17, weight: .bold))
                Text("API 账户余额")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            statusPill
        }
    }

    @ViewBuilder
    private var statusPill: some View {
        switch model.state {
        case .idle:
            pill(text: "未查询", color: .orange)
        case .loading:
            pill(text: "查询中", color: .orange)
        case .loaded(let response):
            pill(text: response.isAvailable ? "可用" : "不可用",
                 color: response.isAvailable ? .green : .red)
        case .failed:
            pill(text: "异常", color: .red)
        }
    }

    private func pill(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(color)
            .background(color.opacity(0.16), in: Capsule())
    }

    // MARK: - 内容

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle:
            Text("还没有设置 API Key · 点右上角设置")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .padding(.top, 18)
        case .loading:
            HStack(spacing: 8) {
                ProgressView()
                Text("正在查询…")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 18)
        case .failed(let message):
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.red)
                .padding(.top, 14)
        case .loaded(let response):
            VStack(alignment: .leading, spacing: 16) {
                if response.balanceInfos.isEmpty {
                    Text("接口未返回余额信息")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(response.balanceInfos, id: \.self) { info in
                        infoBlock(info)
                    }
                }
            }
            .padding(.top, 18)
        }
    }

    private func infoBlock(_ info: BalanceResponse.Info) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                if !info.currencySymbol.isEmpty {
                    Text(info.currencySymbol)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.deepSeekBlue)
                }
                Text(info.totalBalance)
                    .font(.system(size: 46, weight: .heavy))
                    .monospacedDigit()
                    .accessibilityIdentifier("balance.total")
                if !info.currency.isEmpty {
                    Text(info.currency)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
                if let flash = model.fedFlash, flash.currency == info.currency {
                    Text("+" + CurrencyFormat.display(amount: String(format: "%.2f", flash.amount), currency: info.currency))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.green.opacity(0.15)))
                        .padding(.leading, 6)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.3), value: model.fedFlash?.id)
            Text("总余额")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            VStack(spacing: 0) {
                detailRow(label: "充值余额", value: info.toppedUpBalanceText)
                Divider()
                detailRow(label: "赠送余额", value: info.grantedBalanceText)
            }
            .padding(.top, 8)
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .monospacedDigit()
        }
        .padding(.vertical, 9)
    }

    // MARK: - 低余额横幅

    private var lowBalanceBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("余额低于提醒阈值，记得充值哦")
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.orange)
        .padding(.top, 12)
    }

    // MARK: - 更新时间

    private var footer: some View {
        Group {
            if let updated = model.lastUpdated {
                Text("更新于 \(updated.formatted(date: .numeric, time: .standard))")
            } else {
                Text(" ")
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.top, 14)
    }
}
