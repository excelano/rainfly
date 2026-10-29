// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import UserNotifications

enum DiaryReminder {
    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    static func schedule(after night: NightForecast, packByMinutes: Int, now: Date = .now) async {
        let packBy = NightWindow(night, packByMinutes: packByMinutes).packBy
        let at = max(packBy.addingTimeInterval(-30 * 60), night.sunrise.addingTimeInterval(15 * 60))
        guard at > now else { return }
        let content = UNMutableNotificationContent()
        content.title = "Dew diary"
        content.body = "What did you find this morning? One tap in Rainfly."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: at.timeIntervalSince(now), repeats: false)
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    static func cancel() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    private static let identifier = "dewDiaryMorning"
}
