import Foundation
import UserNotifications

protocol NotificationSending {
    /// 请求（或查询）通知权限。已授权返回 true；被拒绝返回 false。
    func requestAuthorization() async -> Bool
    func sendLowBalanceNotification(current: String, threshold: String) async
}

/// 本地通知实现（余额不足提醒）。
final class SystemNotificationSender: NotificationSending {
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        default:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
    }

    func sendLowBalanceNotification(current: String, threshold: String) async {
        let content = UNMutableNotificationContent()
        content.title = "💸 DeepSeek 余额不足"
        content.body = "当前余额 \(current)，已低于提醒阈值 \(threshold)"
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
