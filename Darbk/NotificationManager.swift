//
//  NotificationManager.swift
//  Darbk
//
//  Created by Sarah on 22/06/1447 AH.
//

import Foundation
import UserNotifications
import AVFoundation
import UIKit
class NotificationManager {

    static let shared = NotificationManager()

    private init() {}

    // طلب صلاحية الإشعارات
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if let error = error {
                print("Error requesting notification permission: \(error)")
            } else {
                print("Notification permission granted: \(granted)")
            }
        }
    }

    // إرسال إشعار الوصول للمحطة
    func sendArrivalNotification(stationName: String) {
        let content = UNMutableNotificationContent()
        content.title = "وصلت محطتك"
        content.body = "أنت الآن عند محطة \(stationName)"
        content.sound = UNNotificationSound.default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending notification: \(error)")
            } else {
                print("Arrival notification sent!")
            }
        }

        vibrateDevice()
        flashLightBlink()
    }

    // MARK: - اهتزاز
    private func vibrateDevice() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    // MARK: - فلاش
    private func flashLightBlink() {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }

        do {
            try device.lockForConfiguration()
            try device.setTorchModeOn(level: 1.0)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                device.torchMode = .off
                device.unlockForConfiguration()
            }

        } catch {
            print("Flash error: \(error)")
        }
    }
}
