//
//  ViewModels.swift
//  Darbk
//

import Foundation
import SwiftUI
import MapKit
import CoreLocation
import Observation

// MARK: - Location Manager
@Observable
class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var userLocation: CLLocationCoordinate2D?
    var authorizationStatus: CLAuthorizationStatus?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocationPermission() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.last?.coordinate
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
}

// MARK: - Map ViewModel
@Observable
class MapViewModel {
    var lines: [MetroLine] = []
    var stations: [MetroStation] = []
    var selectedStation: MetroStation?
    var isLoading = true
    var errorMessage: String?
    var favoriteStations: Set<String> = []
    var originStation: MetroStation?
    var destinationStation: MetroStation?
    var routeStations: [MetroStation] = []
    var metroGraph = MetroGraph()
    var stationByCode: [String: MetroStation] = [:]
    var stationNumbering: [String: Int] = [:]
    
    var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 24.7136, longitude: 46.6753),
            span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
        )
    )
    
    func loadMetroData() {
        Task {
            await loadStations()
            await loadLines()
        }
    }
    
    
    @MainActor
    private func loadStations() async {
        // ✅ نقرأ من الملف المحلي بدل API
        guard let url = Bundle.main.url(forResource: "metro-stations", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            errorMessage = "فشل تحميل ملف المحطات"
            isLoading = false
            return
        }
        
        do {
            let response = try JSONDecoder().decode(StationsAPIResponse.self, from: data)
            stations = response.results
            buildGraph()
            generateStationNumbers()
            
            if !stations.isEmpty {
                let coords = stations.map { $0.coordinate }
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: calculateCenter(coords),
                        span: calculateSpan(coords)
                    )
                )
            }
            isLoading = false
        } catch {
            errorMessage = "فشل قراءة بيانات المحطات\n\(error.localizedDescription)"
            isLoading = false
        }
    }
    
    
    
    
    @MainActor
    private func loadLines() async {
        guard let url = Bundle.main.url(forResource: "metro-lines", withExtension: "geojson"),
              let data = try? Data(contentsOf: url),
              let geoJSON = try? JSONDecoder().decode(LinesGeoJSON.self, from: data) else {
            return
        }
        
        lines = geoJSON.features.map { feature in
            let coords = feature.geometry.coordinates.map {
                CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0])
            }
            return MetroLine(
                name: feature.properties.metrolinename,
                nameAr: feature.properties.metrolinenamear,
                color: Color(hex: feature.properties.m_linecolorcode),
                coordinates: coords
            )
        }
    }
    
    func buildGraph() {
        var graph = MetroGraph()
        var codeMap: [String: MetroStation] = [:]
        
        stations.forEach { codeMap[$0.metrostationcode] = $0 }
        
        let byLine = Dictionary(grouping: stations, by: { $0.metroline })
        for (_, lineStations) in byLine {
            let ordered = lineStations.sorted { $0.metrostationcode < $1.metrostationcode }
            if ordered.count >= 2 {
                for i in 0..<(ordered.count - 1) {
                    graph.addEdge(ordered[i].metrostationcode, ordered[i + 1].metrostationcode)
                }
            }
        }
        
        let byNameAr = Dictionary(grouping: stations, by: { $0.metrostationnamear })
        for (_, group) in byNameAr where group.count > 1 {
            for i in 0..<group.count {
                for j in (i + 1)..<group.count {
                    graph.addEdge(group[i].metrostationcode, group[j].metrostationcode)
                }
            }
        }
        
        metroGraph = graph
        stationByCode = codeMap
    }
    
    func generateStationNumbers() {
        var numbering: [String: Int] = [:]
        let groupedByLine = Dictionary(grouping: stations, by: { $0.metroline })
        
        for (line, lineStations) in groupedByLine {
            if line == "Line5" {
                // نرتب المحطات حسب stationseq الأصلي
                let sorted = lineStations.sorted { $0.stationseq < $1.stationseq }
                
                // نلاقي محطة وزارة التعليم
                guard let moEIndex = sorted.firstIndex(where: {
                    $0.metrostationnamear.contains("وزارة التعليم")
                }) else {
                    // لو ما لقيناها، نرتب عادي
                    for (index, station) in sorted.enumerated() {
                        numbering[station.metrostationcode] = 11 + index
                    }
                    continue
                }
                
                // نلاقي محطة المتحف الوطني
                guard let museumIndex = sorted.firstIndex(where: {
                    $0.metrostationnamear.contains("المتحف الوطني") ||
                    $0.metrostationnamear.contains("المتحف")
                }) else {
                    // لو ما لقيناها، نرتب من وزارة التعليم للآخر فقط
                    let reordered = Array(sorted[moEIndex...]) + Array(sorted[..<moEIndex])
                    for (index, station) in reordered.enumerated() {
                        numbering[station.metrostationcode] = 11 + index
                    }
                    continue
                }
                
                // نرتب من وزارة التعليم إلى المتحف الوطني
                var reordered: [MetroStation] = []
                
                if moEIndex <= museumIndex {
                    // الترتيب الطبيعي: من وزارة التعليم للمتحف
                    reordered = Array(sorted[moEIndex...museumIndex])
                } else {
                    // لو وزارة التعليم بعد المتحف في الترتيب الأصلي
                    // نمشي من وزارة التعليم للآخر ثم من الأول للمتحف
                    reordered = Array(sorted[moEIndex...]) + Array(sorted[...museumIndex])
                }
                
                for (index, station) in reordered.enumerated() {
                    numbering[station.metrostationcode] = 11 + index
                }
            } else {
                // باقي الخطوط عادي
                let sorted = lineStations.sorted { $0.stationseq < $1.stationseq }
                for (index, station) in sorted.enumerated() {
                    numbering[station.metrostationcode] = 11 + index
                }
            }
        }
        stationNumbering = numbering
    }
    
    func setDestination(to station: MetroStation, userLocation: CLLocationCoordinate2D?) {
        destinationStation = station
        if let userCoord = userLocation {
            originStation = nearestStation(to: userCoord)
        } else {
            originStation = station
        }
        updateRoute()
    }
    
    func clearRoute() {
        destinationStation = nil
        originStation = nil
        routeStations = []
    }
    
    func updateRoute() {
        guard let origin = originStation, let destination = destinationStation else {
            routeStations = []
            return
        }
        
        let path = metroGraph.shortestPath(from: origin.metrostationcode, to: destination.metrostationcode)
        let mapped = path.compactMap { stationByCode[$0] }
        
        if mapped.count <= 1 {
            clearRoute()
            return
        }
        
        routeStations = mapped
        
        let coords = mapped.map { $0.coordinate }
        if !coords.isEmpty {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: calculateCenter(coords),
                    span: calculateSpan(coords)
                )
            )
        }
    }
    
    func routeProgress(userLocation: CLLocationCoordinate2D?) -> Double {
        guard let userCoord = userLocation, routeStations.count >= 2 else { return 0 }
        let distances = routeStations.map { distance(from: userCoord, to: $0.coordinate) }
        guard let minIndex = distances.indices.min(by: { distances[$0] < distances[$1] }) else { return 0 }
        return Double(minIndex) / Double(max(routeStations.count - 1, 1))
    }
    
    func routePolylineCoordinates() -> [CLLocationCoordinate2D]? {
        guard routeStations.count >= 2,
              let first = routeStations.first,
              let line = lines.first(where: { $0.name == first.metrolinename }),
              let startIndex = closestIndex(on: line.coordinates, to: first.coordinate),
              let last = routeStations.last,
              let endIndex = closestIndex(on: line.coordinates, to: last.coordinate) else {
            return routeStations.map { $0.coordinate }
        }
        
        return startIndex <= endIndex ?
            Array(line.coordinates[startIndex...endIndex]) :
            Array(line.coordinates[endIndex...startIndex].reversed())
    }
    
    func nearestStation(to coord: CLLocationCoordinate2D) -> MetroStation? {
        stations.min { distance(from: coord, to: $0.coordinate) < distance(from: coord, to: $1.coordinate) }
    }
    
    func centerOnUser(location: CLLocationCoordinate2D) {
        cameraPosition = .region(
            MKCoordinateRegion(
                center: location,
                span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
            )
        )
    }
    
    func selectStation(_ station: MetroStation) {
        selectedStation = station
        cameraPosition = .region(
            MKCoordinateRegion(
                center: station.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        )
    }
    
    // Helpers
    private func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: from.latitude, longitude: from.longitude)
            .distance(from: CLLocation(latitude: to.latitude, longitude: to.longitude))
    }
    
    private func calculateCenter(_ coords: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        let totalLat = coords.reduce(0) { $0 + $1.latitude }
        let totalLon = coords.reduce(0) { $0 + $1.longitude }
        return CLLocationCoordinate2D(
            latitude: totalLat / Double(coords.count),
            longitude: totalLon / Double(coords.count)
        )
    }
    
    private func calculateSpan(_ coords: [CLLocationCoordinate2D]) -> MKCoordinateSpan {
        let lats = coords.map { $0.latitude }
        let lons = coords.map { $0.longitude }
        let latDelta = ((lats.max() ?? 0) - (lats.min() ?? 0)) * 1.2
        let lonDelta = ((lons.max() ?? 0) - (lons.min() ?? 0)) * 1.2
        return MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
    }
    
    private func closestIndex(on coords: [CLLocationCoordinate2D], to target: CLLocationCoordinate2D) -> Int? {
        guard !coords.isEmpty else { return nil }
        let targetLoc = CLLocation(latitude: target.latitude, longitude: target.longitude)
        var bestIndex = 0
        var bestDistance = CLLocationDistance.greatestFiniteMagnitude
        
        for (i, c) in coords.enumerated() {
            let d = targetLoc.distance(from: CLLocation(latitude: c.latitude, longitude: c.longitude))
            if d < bestDistance {
                bestDistance = d
                bestIndex = i
            }
        }
        return bestIndex
    }
}
