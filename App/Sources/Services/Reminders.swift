import Photos
import UIKit
import UserNotifications

/// Local reminders. Nothing is pending while the app is open;
/// each trip to the background schedules one chain, and an ignored chain ends in a goodbye.
enum Reminders {
    static let enabledKey = "reminders.enabled"
    private static let openHoursKey = "reminders.openHours"
    private static let variantKey = "reminders.lastVariant"
    private static let promptCountKey = "reminders.promptCount"
    private static let lastPromptKey = "reminders.lastPrompt"
    private static let nudgeDateKey = "reminders.nudgeFireDate"
    private static let nudgesSentKey = "reminders.nudgesSent"

    private static var defaults: UserDefaults { .standard }
    private static var center: UNUserNotificationCenter { .current() }

    static func appBecameActive() {
        var hours = defaults.array(forKey: openHoursKey) as? [Int] ?? []
        hours.append(Calendar.current.component(.hour, from: .now))
        defaults.set(Array(hours.suffix(10)), forKey: openHoursKey)
        cancelPending()
    }

    @MainActor static func appEnteredBackground() {
        // Without this the app can be suspended between the async calls and schedule nothing.
        let task = UIApplication.shared.beginBackgroundTask()
        Task {
            await reschedule()
            UIApplication.shared.endBackgroundTask(task)
        }
    }

    // MARK: Permission

    /// The soft card after a delete session; „Nie teraz” twice, 30 days apart, and it's gone for good.
    static func shouldOfferPrompt() async -> Bool {
        let lastPrompt = defaults.object(forKey: lastPromptKey) as? Date ?? .distantPast
        guard !defaults.bool(forKey: enabledKey), defaults.integer(forKey: promptCountKey) < 2,
              Date.now.timeIntervalSince(lastPrompt) > 30 * 86_400 else { return false }
        return await center.notificationSettings().authorizationStatus == .notDetermined
    }

    static func declinePrompt() {
        defaults.set(defaults.integer(forKey: promptCountKey) + 1, forKey: promptCountKey)
        defaults.set(Date.now, forKey: lastPromptKey)
    }

    /// Turns reminders on; false when the system prompt was (or had been) declined.
    @discardableResult
    static func enable() async -> Bool {
        defaults.set(true, forKey: enabledKey)
        return (try? await center.requestAuthorization(options: [.alert])) ?? false
    }

    // MARK: Scheduling

    private static func cancelPending() {
        // A nudge whose date has passed was delivered — that's what "max 2 ever" counts.
        if let date = defaults.object(forKey: nudgeDateKey) as? Date, date < .now {
            defaults.set(defaults.integer(forKey: nudgesSentKey) + 1, forKey: nudgesSentKey)
        }
        defaults.removeObject(forKey: nudgeDateKey)
        center.removeAllPendingNotificationRequests()
    }

    private static func reschedule() async {
        cancelPending()
        guard defaults.bool(forKey: enabledKey),
              await center.notificationSettings().authorizationStatus == .authorized else { return }
        let hour = preferredHour(from: defaults.array(forKey: openHoursKey) as? [Int] ?? [])
        let (keep, delete) = ModelProgress.counts

        if !ModelProgress.isReady(keep: keep, delete: delete), keep + delete > 0,
           defaults.integer(forKey: nudgesSentKey) < 2 {
            let date = fireDate(daysFromNow: 1, hour: hour)
            defaults.set(date, forKey: nudgeDateKey)
            await add(trainingCopy(keep: keep, delete: delete), link: .train, at: date)
            return
        }

        let link: DeepLink = ModelProgress.isReady(keep: keep, delete: delete) ? .delete : .duplicates
        let days = interval(photosPerDay: photosPerDay())
        let variant = defaults.integer(forKey: variantKey)
        defaults.set(variant + 2, forKey: variantKey)
        await add(cleanupCopy(link, variant: variant + 1), link: link, at: fireDate(daysFromNow: days, hour: hour))
        await add(cleanupCopy(link, variant: variant + 2), link: link, at: fireDate(daysFromNow: days * 3, hour: hour))
        await add(localized("Wygląda na to, że przypomnienia nie pomagają, więc na razie przestajemy. Galeria poczeka 🙂"),
                  link: .delete, at: fireDate(daysFromNow: days * 7, hour: hour))
    }

    private static func add(_ body: String, link: DeepLink, at date: Date) async {
        let content = UNMutableNotificationContent()
        content.body = body
        content.threadIdentifier = "reminders"
        content.userInfo = ["link": link.rawValue]
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        try? await center.add(request)
    }

    private static func photosPerDay() -> Double {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "creationDate > %@", Date.now.addingTimeInterval(-30 * 86_400) as NSDate)
        return Double(PHAsset.fetchAssets(with: .image, options: options).count) / 30
    }

    // MARK: Pure parts (tested)

    /// Median of recent app-open hours; 19:00 until we know better, never at night.
    static func preferredHour(from hours: [Int]) -> Int {
        guard !hours.isEmpty else { return 19 }
        return min(max(hours.sorted()[hours.count / 2], 9), 21)
    }

    /// Days until ~100 new photos pile up: weekly for heavy shooters, monthly for light ones.
    static func interval(photosPerDay: Double) -> Int {
        guard photosPerDay > 0 else { return 30 }
        return min(max(Int((100 / photosPerDay).rounded()), 7), 30)
    }

    static func fireDate(daysFromNow days: Int, hour: Int, now: Date = .now) -> Date {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: now))!
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
    }

    // MARK: Copy

    private static func trainingCopy(keep: Int, delete: Int) -> String {
        let needed = ModelProgress.minSamplesPerClass
        let done = min(keep, needed) + min(delete, needed)
        return defaults.integer(forKey: nudgesSentKey) == 0
            ? localized("Zdjęcia do oznaczenia: \(2 * needed - done). Potem model zacznie sprzątać za Ciebie.")
            : localized("Model jest w \(done * 100 / (2 * needed))% gotowy. Dokończymy?")
    }

    /// Rotating index: consecutive notifications never share a variant.
    private static func cleanupCopy(_ link: DeepLink, variant: Int) -> String {
        let variants: [LocalizedStringResource] = [
            "Od ostatniego sprzątania trochę się nazbierało. 2 minuty i po sprawie?",
            "Galeria znowu rośnie. Szybki przegląd?",
            link == .delete
                ? "Zrzuty ekranu same się nie usuną. No, chyba że pozwolisz modelowi."
                : "Kilka duplikatów pewnie już się namnożyło. Sprawdzimy?",
        ]
        return localized(variants[variant % variants.count])
    }

    /// In the language picked in Settings — String(localized:) alone would follow the system.
    private static func localized(_ resource: LocalizedStringResource) -> String {
        var resource = resource
        if let locale = (AppLanguage(rawValue: defaults.string(forKey: SettingsStore.languageKey) ?? "") ?? .system).locale {
            resource.locale = locale
        }
        return String(localized: resource)
    }
}

/// Notification taps reuse the widget's deep links, so routing lives in one place (HomeView).
final class ReminderTapHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ReminderTapHandler()

    /// Not the async variant: it calls the completion handler off the main thread and UIKit aborts.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let raw = response.notification.request.content.userInfo["link"] as? String
        DispatchQueue.main.async {
            if let link = DeepLink(rawValue: raw ?? "") { UIApplication.shared.open(link.url) }
            completionHandler()
        }
    }
}
