import UIKit
import Flutter
import UserNotifications

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, UNUserNotificationCenterDelegate {
  private let channelName = "thristify/native_exact"
  private let iosIdPrefix = "thristify_window_"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)

    let center = UNUserNotificationCenter.current()
    center.delegate = self
    center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getStatus":
        self.getStatus(result: result)
      case "scheduleWindow":
        guard let args = call.arguments as? [String: Any],
              let minutes = args["minutes"] as? Int,
              let title = args["title"] as? String,
              let body = args["body"] as? String,
              let sh = args["startHour"] as? Int,
              let sm = args["startMinute"] as? Int,
              let eh = args["endHour"] as? Int,
              let em = args["endMinute"] as? Int else {
          result(FlutterError(code: "BAD_ARGS", message: "Missing args", details: nil)); return
        }
        self.scheduleDailyWindow(minutes: minutes, title: title, body: body,
                                 startHour: sh, startMinute: sm, endHour: eh, endMinute: em,
                                 result: result)
      case "cancelExact":
        self.cancelAllWindow()
        result("cancelled")
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Foreground presentation
  func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.banner, .sound, .list])
  }

  private func scheduleDailyWindow(minutes: Int, title: String, body: String,
                                   startHour: Int, startMinute: Int,
                                   endHour: Int, endMinute: Int,
                                   result: @escaping FlutterResult) {
    cancelAllWindow() // clear previous

    // Build all daily times inside [start, end) at given interval
    var times: [(Int, Int)] = []
    func next(h:Int, m:Int, add:Int)->(Int,Int) {
      var total = h*60 + m + add
      total = (total + 24*60) % (24*60)
      return (total/60, total%60)
    }
    func minutesBetween(_ sh:Int,_ sm:Int,_ eh:Int,_ em:Int,_ crosses:Bool) -> Int {
      let s = sh*60 + sm
      let e = eh*60 + em
      return crosses ? ((24*60 - s) + e) : (e - s)
    }

    let sTotal = startHour*60 + startMinute
    let eTotal = endHour*60 + endMinute
    let crosses = eTotal <= sTotal
    let span = minutesBetween(startHour, startMinute, endHour, endMinute, crosses)
    if span <= 0 { result(FlutterError(code:"BAD_WINDOW", message:"Empty window", details:nil)); return }

    // Generate all minute slots
    var curH = startHour
    var curM = startMinute
    var remain = span
    while remain > 0 {
      times.append((curH, curM))
      let (nh, nm) = next(curH, curM, minutes)
      // compute delta forward
      var delta = minutes
      if crosses {
        // when crossing midnight, we still just subtract minutes; loop breaks by remain.
      }
      curH = nh; curM = nm
      remain -= minutes
      if remain <= 0 { break }
    }

    if times.count > 64 {
      result(FlutterError(code: "TOO_MANY", message: "iOS can schedule up to 64 daily notifications. Reduce interval or window.", details: "\(times.count) > 64"))
      return
    }

    let center = UNUserNotificationCenter.current()
    for (idx, t) in times.enumerated() {
      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      content.sound = .default

      var date = DateComponents()
      date.hour = t.0
      date.minute = t.1

      let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
      let req = UNNotificationRequest(identifier: "\(iosIdPrefix)\(idx)", content: content, trigger: trigger)
      center.add(req, withCompletionHandler: nil)
    }

    // Done
    result("scheduled")
  }

  private func cancelAllWindow() {
    let center = UNUserNotificationCenter.current()
    center.getPendingNotificationRequests { reqs in
      let ids = reqs.filter { $0.identifier.hasPrefix(self.iosIdPrefix) }.map { $0.identifier }
      center.removePendingNotificationRequests(withIdentifiers: ids)
    }
  }

  private func getStatus(result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().getPendingNotificationRequests { reqs in
      let active = reqs.contains { $0.identifier.hasPrefix(self.iosIdPrefix) }
      // iOS doesn’t persist our interval/window values anywhere globally;
      // Flutter UI will keep last-used values unless you store them in UserDefaults.
      result([
        "scheduled": active,
        "minutes": 0,
        "title": "",
        "body": "",
        "startHour": 0,
        "startMinute": 0,
        "endHour": 0,
        "endMinute": 0,
      ])
    }
  }
}
