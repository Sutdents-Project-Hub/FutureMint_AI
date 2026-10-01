import XCTest
import UserNotifications
@testable import Runner

class RunnerTests: XCTestCase {
  func testLocalReminderUsesTaipeiCalendarAndDoesNotRepeat() {
    let at = ISO8601DateFormatter().date(from: "2026-10-16T01:00:00Z")!
    let request = SubscriptionReminderRequest.make(identifier: "futuremint.subscription.test.2026-10-17", at: at, owner: "synthetic-user")
    let trigger = request.trigger as! UNCalendarNotificationTrigger
    XCTAssertEqual(trigger.dateComponents.timeZone?.identifier, "Asia/Taipei")
    XCTAssertEqual(trigger.dateComponents.day, 16)
    XCTAssertEqual(trigger.dateComponents.hour, 9)
    XCTAssertEqual(trigger.dateComponents.minute, 0)
    XCTAssertFalse(trigger.repeats)
  }
  func testReminderContentIsGenericAndTapIsAccountBound() {
    let request = SubscriptionReminderRequest.make(identifier: "futuremint.subscription.synthetic", at: Date(), owner: "synthetic-user")
    XCTAssertEqual(request.content.title, "訂閱續訂提醒")
    XCTAssertEqual(request.content.body, "續訂前先看看最近的使用情況，再決定下一步。")
    XCTAssertEqual(request.content.userInfo["futuremintOwner"] as? String, "synthetic-user")
    XCTAssertEqual(request.content.userInfo["route"] as? String, "/subscriptions")
    XCTAssertEqual(request.content.userInfo.count, 2)
  }
}
