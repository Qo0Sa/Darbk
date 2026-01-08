////
////  LocationSimulator.swift
////  Darbk
////
////  Created by Sarah on 23/06/1447 AH.
////
//
////
////  LocationSimulator.swift
////  Darbk
////
//
//import Foundation
//import CoreLocation
//import Combine
//
//class LocationSimulator: ObservableObject {
//    static let shared = LocationSimulator()
//    
//    @Published var isSimulating = false
//    @Published var simulatedLocation: CLLocationCoordinate2D?
//    @Published var targetStation: MetroStation?
//    @Published var secondsRemaining: Int = 0
//    
//    private var timer: Timer?
//    
//    private init() {}
//    
//    // تحديد المحطة للمحاكاة (يبدأ العد التنازلي تلقائياً)
//    func setTargetStation(_ station: MetroStation, arrivalDelay: Int = 5) {
//        stopSimulation()
//        
//        targetStation = station
//        secondsRemaining = arrivalDelay
//        
//        print("🎯 محاكاة الوصول لـ: \(station.metrostationnamear)")
//        print("⏱️ الوصول بعد \(arrivalDelay) ثانية")
//        
//        startCountdown()
//    }
//    
//    private func startCountdown() {
//        timer?.invalidate()
//        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
//            guard let self = self else { return }
//            
//            if self.secondsRemaining > 0 {
//                self.secondsRemaining -= 1
//            } else {
//                self.activateSimulation()
//            }
//        }
//    }
//    
//    private func activateSimulation() {
//        timer?.invalidate()
//        timer = nil
//        
//        guard let station = targetStation else { return }
//        
//        isSimulating = true
//        simulatedLocation = station.coordinate
//        
//        print("✅ وصلت للمحطة: \(station.metrostationnamear)")
//    }
//    
//    func stopSimulation() {
//        timer?.invalidate()
//        timer = nil
//        isSimulating = false
//        simulatedLocation = nil
//        targetStation = nil
//        secondsRemaining = 0
//    }
//    
//    func getLocation(realLocation: CLLocationCoordinate2D?) -> CLLocationCoordinate2D? {
//        if isSimulating {
//            return simulatedLocation
//        }
//        return realLocation
//    }
//    
//    var statusText: String {
//        if isSimulating {
//            return "✅ وصلت للمحطة"
//        } else if secondsRemaining > 0 {
//            return "⏱️ الوصول بعد \(secondsRemaining) ثانية"
//        }
//        return ""
//    }
//}
