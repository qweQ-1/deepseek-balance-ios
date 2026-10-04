import SwiftUI

/// 设置区块：API Key 输入/保存/清除 + 说明。
struct KeySetupView: View {
    @Bindable var model: BalanceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("设置")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            SecureField("DeepSeek API Key（sk-…）", text: $model.apiKeyInput)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(.system(size: 14))
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.tertiarySystemGroupedBackground))
                )

            Button {
                Task { await model.saveKeyAndRefresh() }
            } label: {
                Text("保存并查询")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.deepSeekBlue)
            .disabled(model.apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            HStack(spacing: 16) {
                if model.hasStoredKey {
                    Button("刷新余额") {
                        Task { await model.refresh() }
                    }
                    Button("清除已保存的 Key", role: .destructive) {
                        model.clearKey()
                    }
                }
                Spacer()
            }
            .font(.system(size: 13))

            Text("Key 仅保存在本机 Keychain，只发送给 api.deepseek.com。可在 [platform.deepseek.com](https://platform.deepseek.com/api_keys) 获取。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineSpacing(2)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}
