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
        content.title = "🎯 وصلت محطتك"
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

        // هزتين قويتين متتاليتين
        vibrateDeviceStrong()
        flashLightBlink()
    }

    // MARK: - اهتزاز قوي (هزتين)
    private func vibrateDeviceStrong() {
        // الهزة الأولى - قوية
        let generator1 = UINotificationFeedbackGenerator()
        generator1.notificationOccurred(.success)
        
        // تأخير بسيط ثم الهزة الثانية
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let generator2 = UINotificationFeedbackGenerator()
            generator2.notificationOccurred(.success)
        }
        
        // إضافة هزات إضافية للأجهزة الداعمة
        if #available(iOS 13.0, *) {
            let impactGenerator = UIImpactFeedbackGenerator(style: .heavy)
            impactGenerator.impactOccurred()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let impactGenerator2 = UIImpactFeedbackGenerator(style: .heavy)
                impactGenerator2.impactOccurred()
            }
        }
    }

    // MARK: - فلاش (يومض مرتين)
    private func flashLightBlink() {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }

        do {
            try device.lockForConfiguration()
            
            // الومضة الأولى
            try device.setTorchModeOn(level: 1.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                device.torchMode = .off
                
                // الومضة الثانية
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    do {
                        try device.setTorchModeOn(level: 1.0)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            device.torchMode = .off
                            device.unlockForConfiguration()
                        }
                    } catch {
                        print("Flash error: \(error)")
                        device.unlockForConfiguration()
                    }
                }
            }

        } catch {
            print("Flash error: \(error)")
        }
    }
}
