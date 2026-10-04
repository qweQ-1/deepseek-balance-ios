import SwiftUI

/// 偏好设置：娃娃 / 音效 / 台词 / 余额提醒 / 定时刷新 / 画中画。
struct PreferencesCardView: View {
    var model: BalanceViewModel
    @Bindable var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("偏好设置")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            DollSectionView(settings: settings)

            Divider()

            VStack(spacing: 10) {
                Toggle("音效", isOn: $settings.soundEnabled)
                Toggle("语音说话", isOn: $settings.speechEnabled)
            }
            .font(.system(size: 14))

            SoundSectionView()

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

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Toggle("后台余额悬浮窗（画中画）", isOn: Binding(
                    get: { settings.pipEnabled },
                    set: { model.pipToggled($0) }
                ))
                .font(.system(size: 14))

                Text("开启后，划出后台时用画中画小窗显示当前余额；回到 App 自动关闭。没反应时先点『试弹一下』验证，或检查 系统设置 → 通用 → 画中画。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Button("试弹一下") { model.pipPreviewStart() }
                    Button("关闭小窗") { model.pipPreviewStop() }
                }
                .font(.system(size: 12))
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.top, 2)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Toggle("保持后台运行", isOn: Binding(
                    get: { settings.backgroundKeepAliveEnabled },
                    set: { model.backgroundKeepAliveToggled($0) }
                ))
                .font(.system(size: 14))

                Text("开启后 App 划到后台也不被系统挂起：余额定时刷新、余额不足提醒在后台继续工作（靠静音音频保活，会多耗一点电）。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
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
