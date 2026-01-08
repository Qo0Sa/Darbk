import SwiftUI
import CoreLocation

struct CompactUpcomingBanner: View {
    let routeStations: [MetroStation]
    let allStations: [MetroStation]
    let progress: Double
    let userLocation: CLLocationCoordinate2D?
    
    @State private var hasArrived = false
    @State private var showCelebration = false
    @State private var hasNotified = false
  //  @StateObject private var simulator = LocationSimulator.shared
    
    // حساب عدد المحطات المتبقية بدقة
    private var remainingStops: Int {
        guard routeStations.count > 1 else { return 0 }
        
        let clampedProgress = min(max(progress, 0), 1)
        let totalStops = routeStations.count
        
        // حساب المحطة الحالية
        let currentStopIndex = Int(floor(clampedProgress * Double(totalStops - 1)))
        
        // المحطات المتبقية = (آخر محطة - المحطة الحالية)
        return max(totalStops - 1 - currentStopIndex, 0)
    }
    
    // حساب المحطة التالية بدقة بناءً على التقدم
    private var nextStation: MetroStation? {
        guard routeStations.count > 1 else {
            return routeStations.first
        }
        
        let clampedProgress = min(max(progress, 0), 1)
        let totalStops = routeStations.count
        
        // حساب المحطة الحالية
        let currentStopIndex = Int(floor(clampedProgress * Double(totalStops - 1)))
        
        // المحطة التالية هي اللي بعد المحطة الحالية
        let nextStopIndex = min(currentStopIndex + 1, totalStops - 1)
        
        // لو وصلنا آخر محطة، نرجع nil
        if nextStopIndex >= totalStops - 1 && clampedProgress >= 0.95 {
            return nil // وصلنا تقريباً
        }
        
        return routeStations[nextStopIndex]
    }
    
    // حساب أرقام المحطات الحقيقية
    private var stationNumbering: [String: Int] {
        var numbering: [String: Int] = [:]
        let groupedByLine = Dictionary(grouping: allStations, by: { $0.metroline })
        for (_, lineStations) in groupedByLine {
            let sortedStations = lineStations.sorted { $0.stationseq < $1.stationseq }
            for (index, station) in sortedStations.enumerated() {
                numbering[station.metrostationcode] = 11 + index
            }
        }
        return numbering
    }

    private var stopsToShow: [SimpleStop] {
        let maxStops = 6
        let slice = routeStations.prefix(maxStops)
        return slice.map { station in
            let sameNameStations = allStations.filter {
                $0.metrostationnamear == station.metrostationnamear
            }
            let linesSet = Set(sameNameStations.map { $0.metroline })
            let stationNumber = stationNumbering[station.metrostationcode] ?? station.stationseq
            return SimpleStop(
                nameAr: station.metrostationnamear,
                lineCode: station.metroline,
                multiLineCodes: Array(linesSet),
                stationNumber: stationNumber
            )
        }
    }
    
    private var currentLineColor: Color {
        let clampedProgress = min(max(progress, 0), 1)
        let totalStops = routeStations.count
        guard totalStops > 1 else {
            return Color.lineColor(for: routeStations.first?.metroline ?? "")
        }
        let currentIndex = Int(clampedProgress * Double(totalStops - 1))
        let safeIndex = min(max(currentIndex, 0), totalStops - 1)
        return Color.lineColor(for: routeStations[safeIndex].metroline)
    }
    
    private var destinationStation: MetroStation? {
        routeStations.last
    }
    
    // حساب المسافة بين المستخدم والوجهة
    private var distanceToDestination: CLLocationDistance? {
        // استخدام الموقع الحقيقي فقط
        guard let userCoord = userLocation,
              let destination = destinationStation else {
            return nil
        }
        
        let userLoc = CLLocation(latitude: userCoord.latitude, longitude: userCoord.longitude)
        let destLoc = CLLocation(latitude: destination.coordinate.latitude, longitude: destination.coordinate.longitude)
        
        return userLoc.distance(from: destLoc)
    }
    
    // تحقق من الوصول (أقل من 100 متر)
    private var isUserAtDestination: Bool {
        guard let distance = distanceToDestination else { return false }
        return distance < 100
    }
    
    var body: some View {
        ZStack {
            // البانر الأصلي - ينزل ويختفي عند الوصول
            progressBannerView
                .offset(y: hasArrived ? 100 : 0)
                .opacity(hasArrived ? 0 : 1)
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: hasArrived)
            
            // شاشة الاحتفال - تظهر بعد الوصول
            if showCelebration {
                arrivalCelebrationView
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showCelebration)
            }
        }
        .onChange(of: isUserAtDestination) { oldValue, newValue in
            if newValue && !hasArrived {
                // إرسال الإشعار والاهتزاز عند الوصول
                if !hasNotified, let destination = destinationStation {
                    NotificationManager.shared.sendArrivalNotification(
                        stationName: destination.metrostationnamear
                    )
                    hasNotified = true
                }
                
                withAnimation {
                    hasArrived = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation {
                        showCelebration = true
                    }
                }
            } else if !newValue && hasArrived {
                withAnimation {
                    showCelebration = false
                    hasArrived = false
                }
                // إعادة تعيين حالة الإشعار عند الابتعاد عن الوجهة
                hasNotified = false
            }
        }
    }
    
    // MARK: - Progress Banner View
    private var progressBannerView: some View {
        VStack(alignment: .trailing, spacing: 10) {
            VStack(alignment: .trailing, spacing: 2) {
                Text("متبقي \(remainingStops) محطات")
                    .font(.headline)
                
                if let next = nextStation {
                    Text("المحطة التالية: \(next.metrostationnamear)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("أنت على وشك الوصول!")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            .multilineTextAlignment(.trailing)
            .environment(\.layoutDirection, .rightToLeft)
            .frame(maxWidth: .infinity, alignment: .trailing)
            
            GeometryReader { geo in
                let trackY = geo.size.height / 2
                let startX: CGFloat = geo.size.width - 30
                let endX: CGFloat = 30
                let travelWidth = startX - endX
                let clampedProgress = min(max(progress, 0), 1)
                let trainX = startX - travelWidth * clampedProgress
                
                ZStack(alignment: .leading) {
                    Path { path in
                        path.move(to: CGPoint(x: startX, y: trackY))
                        path.addLine(to: CGPoint(x: endX, y: trackY))
                    }
                    .stroke(Color.gray.opacity(0.25), lineWidth: 6)
                    
                    Path { path in
                        path.move(to: CGPoint(x: startX, y: trackY))
                        path.addLine(to: CGPoint(x: trainX, y: trackY))
                    }
                    .stroke(currentLineColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    
                    HStack(spacing: 0) {
                        ForEach(stopsToShow.indices.reversed(), id: \.self) { index in
                            stopView(stop: stopsToShow[index])
                            if index != 0 {
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, 30)
                    
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 28, height: 28)
                            .shadow(color: .black.opacity(0.15), radius: 3)
                        
                        Image(systemName: "tram.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(currentLineColor)
                    }
                    .position(x: trainX, y: trackY)
                }
            }
            .frame(height: 55)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.grlb)
        )
        .padding(.horizontal, 12)
        .environment(\.layoutDirection, .leftToRight)
    }
    
    // MARK: - Arrival Celebration View
    private var arrivalCelebrationView: some View {
        VStack(spacing: 16) {
            // أيقونة النجاح مع أنيميشن
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.lingr, .lingr.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: .green.opacity(0.4), radius: 12, y: 6)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(.grlb)
                    .symbolEffect(.bounce, value: showCelebration)
            }
            
            // النص الرئيسي
            VStack(spacing: 8) {
              
                Text("🎉 لقد وصلت إلى وجهتك")
                    .font(.title2)
                    .fontWeight(.bold)
                    
                
                if let destination = destinationStation {
                    Text(destination.metrostationnamear)
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
            .multilineTextAlignment(.center)
            .environment(\.layoutDirection, .rightToLeft)
            
         
            Text("نتمنى لك رحلة سعيدة")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .environment(\.layoutDirection, .rightToLeft)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.grlback)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(currentLineColor.opacity(0.3), lineWidth: 2)
                )
                .shadow(color: currentLineColor.opacity(0.3), radius: 20, y: 10)
        )
        .padding(.horizontal, 12)
    }
    
    @ViewBuilder
    private func stopView(stop: SimpleStop) -> some View {
        let color = Color.lineColor(for: stop.lineCode)
        
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 24, height: 24)
            
            Text("\(stop.stationNumber)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.lingr)
        }
    }
}
