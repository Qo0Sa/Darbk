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
    
    var uniqueStations: [MetroStation] {
        Dictionary(
            grouping: stations,
            by: { $0.metrostationcode }
        )
        .compactMap { $0.value.first }
    }

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
    
    
    
    class MetroGraph {
        private var adjacency: [String: Set<String>] = [:]

        func addEdge(_ from: String, _ to: String) {
            adjacency[from, default: []].insert(to)
            adjacency[to, default: []].insert(from)
        }

        func shortestPath(from start: String, to end: String) -> [String] {
            guard start != end else { return [start] }

            var visited: Set<String> = []
            var queue: [(String, [String])] = [(start, [start])]

            while !queue.isEmpty {
                let (current, path) = queue.removeFirst()
                if current == end { return path }

                visited.insert(current)

                for neighbor in adjacency[current] ?? [] {
                    if !visited.contains(neighbor) {
                        queue.append((neighbor, path + [neighbor]))
                        visited.insert(neighbor)
                    }
                }
            }

            return [] // لو ما وصلنا
        }
        
        var allStations: [String] {
            Array(adjacency.keys)
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
<<<<<<< HEAD
            let graph = MetroGraph()
            var codeMap: [String: MetroStation] = [:]
            
            // خزن كل محطة بكودها
            stations.forEach { codeMap[$0.metrostationcode] = $0 }
            
            // 1️⃣ اربط كل محطة بمحطتها التالية في نفس الخط
            let byLine = Dictionary(grouping: stations, by: { $0.metroline })
            for (_, lineStations) in byLine {
                let sorted = lineStations.sorted { $0.stationseq < $1.stationseq }
                for i in 0..<(sorted.count - 1) {
                    graph.addEdge(sorted[i].metrostationcode, sorted[i + 1].metrostationcode)
                }
=======
        let graph = MetroGraph()
        var codeMap: [String: MetroStation] = [:]
        
        // خزن كل محطة بكودها
        Dictionary(
            grouping: stations,
            by: { $0.metrostationcode }
        ).forEach { code, list in
            codeMap[code] = list.first
        }

        
        // 1️⃣ اربط كل محطة بمحطتها التالية في نفس الخط
        let byLine = Dictionary(grouping: stations, by: { $0.metroline })
        for (_, lineStations) in byLine {
            let sorted = lineStations.sorted { $0.stationseq < $1.stationseq }
            for i in 0..<(sorted.count - 1) {
                graph.addEdge(sorted[i].metrostationcode, sorted[i + 1].metrostationcode)
>>>>>>> tes
            }
            
            // 2️⃣ التقاطعات الفعلية فقط
            let intersections: [(String, [String])] = [
                ("المالية", ["Blue", "Yellow", "Purple"]),
                ("STC", ["Blue", "Red"]),
                ("المتحف الوطني", ["Blue", "Green"]),
                ("قصر الحكم", ["Blue", "Orange"]),
                ("النسيم", ["Orange", "Purple"]),
                ("الحمراء", ["Red", "Purple"]),
                ("وزارة التعليم", ["Red", "Green"]),
                ("سابك", ["Yellow", "Purple"]),
                ("عثمان بن عفان", ["Yellow", "Purple"]),
                ("الربيع", ["Yellow", "Purple"])
            ]
            
            for (stationName, lines) in intersections {
                let matchingStations = stations.filter {
                    $0.metrostationnamear.contains(stationName) && lines.contains($0.metroline)
                }
                
                // اربط كل محطة بالثانية في نفس التقاطع
                for i in 0..<matchingStations.count {
                    for j in (i+1)..<matchingStations.count {
                        graph.addEdge(matchingStations[i].metrostationcode, matchingStations[j].metrostationcode)
                    }
                }
            }
            
            metroGraph = graph
            stationByCode = codeMap
        }
    
    
   
    

    func generateStationNumbers() {
        var numbering: [String: Int] = [:]
        
        let groupedByLine = Dictionary(grouping: stations, by: { $0.metroline })
        
        for (_, lineStations) in groupedByLine {
            // ✅ رتب المحطات حسب stationseq داخل كل خط
            let sorted = lineStations.sorted { $0.stationseq < $1.stationseq }
            
            // ✅ رقّم كل محطة حسب موقعها الفعلي في الخط (من 0)
            for (index, station) in sorted.enumerated() {
                // الرقم = 11 + ترتيب المحطة في الخط
                numbering[station.metrostationcode] = 11 + index
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
