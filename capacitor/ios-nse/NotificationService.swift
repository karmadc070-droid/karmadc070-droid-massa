// 알림에 실린 image_url 사진을 받아 iOS 알림에 붙이는 확장 (massa '오늘의 테라피스트' 저녁 푸시, 2026-10-28)
import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var best: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        best = request.content.mutableCopy() as? UNMutableNotificationContent
        guard let best = best,
              let s = request.content.userInfo["image_url"] as? String, !s.isEmpty,
              let url = URL(string: s) else {
            contentHandler(request.content)
            return
        }
        // 사진을 못 받아도 알림은 글자로 그대로 보낸다
        URLSession.shared.downloadTask(with: url) { tmp, _, _ in
            if let tmp = tmp {
                let dst = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".png")
                try? FileManager.default.moveItem(at: tmp, to: dst)
                if let a = try? UNNotificationAttachment(identifier: "photo", url: dst, options: nil) {
                    best.attachments = [a]
                }
            }
            contentHandler(best)
        }.resume()
    }

    // 시간이 다 되면 받은 데까지(사진 없이라도) 보낸다
    override func serviceExtensionTimeWillExpire() {
        if let h = contentHandler, let b = best { h(b) }
    }
}