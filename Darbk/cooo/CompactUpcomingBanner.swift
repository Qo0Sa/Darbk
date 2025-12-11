//
//  CompactUpcomingBanner.swift
//  Darbk
//
//  Created by Sarah on 20/06/1447 AH.
//

//
//  CompactUpcomingBanner.swift
//  Darbk
//

import SwiftUI

struct CompactUpcomingBanner: View {
    let routeStations: [MetroStation]
    let allStations: [MetroStation]
    let progress: Double
    
    private var remainingStops: Int {
        max(routeStations.count - 1, 0)
    }
    
    private var nextStation: MetroStation? {
        if routeStations.count > 1 {
            return routeStations[1]
        } else {
            return routeStations.first
        }
    }
    
    private var stopsToShow: [SimpleStop] {
        let maxStops = 6
        let slice = routeStations.prefix(maxStops)
        return slice.map { station in
            let sameNameStations = allStations.filter {
                $0.metrostationnamear == station.metrostationnamear
            }
            let linesSet = Set(sameNameStations.map { $0.metroline })
            return SimpleStop(
                nameAr: station.metrostationnamear,
                lineCode: station.metroline,
                multiLineCodes: Array(linesSet)
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
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            VStack(alignment: .trailing, spacing: 2) {
                Text("متبقي \(remainingStops) محطات")
                    .font(.headline)
                
                Text("المحطة التالية: \(nextStation?.metrostationnamear ?? "-")")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                            .frame(width: 26, height: 26)
                            .shadow(color: .black.opacity(0.15), radius: 3)
                        
                        Image(systemName: "tram.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(currentLineColor)
                    }
                    .position(x: trainX, y: trackY)
                }
            }
            .frame(height: 45)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        )
        .padding(.horizontal, 12)
        .environment(\.layoutDirection, .leftToRight)
    }
    
    @ViewBuilder
    private func stopView(stop: SimpleStop) -> some View {
        let color = Color.lineColor(for: stop.lineCode)
        
        Circle()
            .fill(.white)
            .frame(width: 16, height: 16)
            .overlay(
                Circle()
                    .stroke(color, lineWidth: 4)
            )
            .shadow(color: .black.opacity(0.1), radius: 1)
    }
}
