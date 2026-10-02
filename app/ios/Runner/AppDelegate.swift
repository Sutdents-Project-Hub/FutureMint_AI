import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var reminders: FlutterMethodChannel?
  private var owner: String?
  private var generation = 0
  private var pendingOpenOwner: String?
  private var pendingPermission: (generation: Int, result: FlutterResult)?
  private let reminderPrefix = "futuremint.subscription."

  override func application(_ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(name: "futuremint/subscription-reminders",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    reminders = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      self.handleReminder(call, result: result)
    }
  }

  private func enabled(_ account: String) -> Bool {
    UserDefaults.standard.bool(forKey: "futuremint.reminders.enabled.\(account)")
  }
  private func state(_ result: @escaping FlutterResult, account: String?, expected: Int) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      DispatchQueue.main.async {
        guard expected == self.generation, account == self.owner else { result(nil); return }
        let allowed = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        let permission = settings.authorizationStatus == .notDetermined ? "notDetermined" : (allowed ? "authorized" : "denied")
        result(["enabled": account.map { self.enabled($0) && allowed } ?? false, "permission": permission])
      }
    }
  }
  private func removeOwned(expected: Int, completion: @escaping () -> Void) {
    let center = UNUserNotificationCenter.current()
    center.getPendingNotificationRequests { requests in
      DispatchQueue.main.async {
        guard expected == self.generation else { completion(); return }
        center.removePendingNotificationRequests(withIdentifiers: requests.filter { $0.identifier.hasPrefix(self.reminderPrefix) }.map(\.identifier))
        center.getDeliveredNotifications { notifications in
          DispatchQueue.main.async {
            guard expected == self.generation else { completion(); return }
            center.removeDeliveredNotifications(withIdentifiers: notifications.filter { $0.request.identifier.hasPrefix(self.reminderPrefix) }.map { $0.request.identifier })
            completion()
          }
        }
      }
    }
  }
  private func handleReminder(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    if call.method == "shareExport" {
      guard let text = args["text"] as? String,
        let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
        var presenter = scene.windows.first(where: \.isKeyWindow)?.rootViewController else {
        result(FlutterError(code: "share_unavailable", message: "無法開啟分享", details: nil)); return
      }
      while let presented = presenter.presentedViewController { presenter = presented }
      let file = FileManager.default.temporaryDirectory.appendingPathComponent("futuremint-export-\(UUID().uuidString).json")
      do { try text.write(to: file, atomically: true, encoding: .utf8) }
      catch { result(FlutterError(code: "export_write_failed", message: "無法建立匯出檔", details: nil)); return }
      let share = UIActivityViewController(activityItems: [file], applicationActivities: nil)
      share.completionWithItemsHandler = { _, _, _, _ in try? FileManager.default.removeItem(at: file) }
      share.popoverPresentationController?.sourceView = presenter.view
      presenter.present(share, animated: true)
      result(nil); return
    }
    if call.method == "bind" {
      generation += 1
      pendingPermission?.result(nil)
      pendingPermission = nil
      owner = args["owner"] as? String
      let expected = generation
      removeOwned(expected: expected) {
        self.state(result, account: self.owner, expected: expected)
        if let pending = self.pendingOpenOwner, pending == self.owner {
          self.pendingOpenOwner = nil
          self.reminders?.invokeMethod("open", arguments: pending)
        } else { self.pendingOpenOwner = nil }
      }
      return
    }
    guard let account = args["owner"] as? String, account == owner else { result(nil); return }
    let expected = generation
    if call.method == "status" {
      state(result, account: account, expected: expected)
      return
    }
    if call.method == "openSettings" {
      let settingsURL: String
      if #available(iOS 16.0, *) { settingsURL = UIApplication.openNotificationSettingsURLString }
      else { settingsURL = UIApplication.openSettingsURLString }
      guard let url = URL(string: settingsURL) else { result(false); return }
      UIApplication.shared.open(url, options: [:]) { opened in result(opened) }
      return
    }
    if call.method == "setEnabled", let value = args["enabled"] as? Bool {
      if !value {
        UserDefaults.standard.set(false, forKey: "futuremint.reminders.enabled.\(account)")
        removeOwned(expected: expected) { self.state(result, account: account, expected: expected) }
      } else {
        // Permission is requested only after the user explicitly toggles on.
        pendingPermission = (generation: expected, result: result)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { allowed, _ in
          DispatchQueue.main.async {
            guard self.pendingPermission?.generation == expected else { return }
            self.pendingPermission = nil
            guard expected == self.generation, account == self.owner else { result(nil); return }
            UserDefaults.standard.set(allowed, forKey: "futuremint.reminders.enabled.\(account)")
            self.state(result, account: account, expected: expected)
          }
        }
      }
      return
    }
    if call.method == "replace" {
      let occurrences = args["occurrences"] as? [[String: Any]] ?? []
      removeOwned(expected: expected) {
        guard expected == self.generation, account == self.owner, self.enabled(account) else { result(nil); return }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
          DispatchQueue.main.async {
            guard expected == self.generation, account == self.owner,
              settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { result(nil); return }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let group = DispatchGroup()
            var failed = false
            for occurrence in occurrences.prefix(60) {
              guard let id = occurrence["id"] as? String, id.hasPrefix(self.reminderPrefix),
                let iso = occurrence["at"] as? String, let at = formatter.date(from: iso), at > Date() else { continue }
              let request = SubscriptionReminderRequest.make(identifier: id, at: at, owner: account)
              group.enter()
              UNUserNotificationCenter.current().add(request) { error in
                DispatchQueue.main.async {
                  if expected != self.generation || account != self.owner {
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
                    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
                  } else if error != nil { failed = true }
                  group.leave()
                }
              }
            }
            group.notify(queue: .main) {
              result(failed ? FlutterError(code: "schedule_failed", message: "本機提醒未全部建立", details: nil) : nil)
            }
          }
        }
      }
      return
    }
    result(FlutterMethodNotImplemented)
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    if notification.request.identifier.hasPrefix(reminderPrefix) {
      guard notification.request.content.userInfo["futuremintOwner"] as? String == owner else {
        completionHandler([]); return
      }
      if #available(iOS 14.0, *) { completionHandler([.banner, .list, .sound]) }
      else { completionHandler([.alert, .sound]) }
    } else {
      super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
    }
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void) {
    if response.notification.request.identifier.hasPrefix(reminderPrefix),
      let tappedOwner = response.notification.request.content.userInfo["futuremintOwner"] as? String {
      if tappedOwner == owner { reminders?.invokeMethod("open", arguments: tappedOwner) }
      else { pendingOpenOwner = tappedOwner }
      completionHandler()
    } else { super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler) }
  }
}

struct SubscriptionReminderRequest {
  static func make(identifier: String, at: Date, owner: String) -> UNNotificationRequest {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Taipei")!
    let content = UNMutableNotificationContent()
    content.title = "訂閱續訂提醒"
    content.body = "續訂前先看看最近的使用情況，再決定下一步。"
    content.sound = .default
    content.userInfo = ["futuremintOwner": owner, "route": "/subscriptions"]
    var date = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: at)
    date.timeZone = calendar.timeZone
    return UNNotificationRequest(identifier: identifier, content: content,
      trigger: UNCalendarNotificationTrigger(dateMatching: date, repeats: false))
  }
}
