import SwiftUI

/// 偏好设置：音效 / 语音 / 台词 / 余额提醒 / 定时刷新。
struct PreferencesCardView: View {
    var model: BalanceViewModel
    @Bindable var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("偏好设置")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                Toggle("音效", isOn: $settings.soundEnabled)
                Toggle("语音说话", isOn: $settings.speechEnabled)
            }
            .font(.system(size: 14))

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("小饭团台词（每行一句，留空用默认）")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                TextEditor(text: $settings.customLinesText)
                    .font(.system(size: 13))
                    .frame(height: 84)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.tertiarySystemGroupedBackground))
                    )
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Toggle("余额不足时提醒", isOn: Binding(
                    get: { settings.lowBalanceReminderEnabled },
                    set: { newValue in
                        Task { await model.reminderToggled(newValue) }
                    }
                ))
                .font(.system(size: 14))

                HStack {
                    Text("提醒阈值")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField("10.00", text: $settings.lowBalanceThresholdText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 96)
                }

                if let note = model.reminderNote {
                    Text(note)
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Toggle("自动定时刷新", isOn: $settings.autoRefreshEnabled)
                    .font(.system(size: 14))

                HStack {
                    Text("刷新间隔")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("刷新间隔", selection: $settings.autoRefreshSeconds) {
                        ForEach(SettingsStore.refreshOptions) { option in
                            Text(option.label).tag(option.seconds)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}
