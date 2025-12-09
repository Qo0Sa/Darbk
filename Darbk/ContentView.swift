//
//  ContentView.swift
//  Darbk
//

import SwiftUI
import MapKit
import Foundation
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

// MARK: - Models
struct MetroStation: Identifiable, Codable, Equatable, Hashable {
    let id = UUID()
    let metrostationcode: String
    let metrostationname: String
    let metrostationnamear: String
    let metroline: String
    let metrolinename: String
    let stationseq: Int
    let geo_point_2d: GeoPoint
    
    // الرقم المعروض (يحسب ديناميكياً)
    var displayNumber: Int {
        return stationseq
    }
    
    static func == (lhs: MetroStation, rhs: MetroStation) -> Bool {
        lhs.metrostationcode == rhs.metrostationcode
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(metrostationcode)
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: geo_point_2d.lat, longitude: geo_point_2d.lon)
    }
    
    struct GeoPoint: Codable {
        let lon: Double
        let lat: Double
    }
    
    enum CodingKeys: String, CodingKey {
        case metrostationcode, metrostationname, metrostationnamear
        case metroline, metrolinename, stationseq, geo_point_2d
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        metrostationcode = try container.decode(String.self, forKey: .metrostationcode)
        metrostationname = (try? container.decode(String.self, forKey: .metrostationname)) ?? "Unknown"
        metrostationnamear = (try? container.decode(String.self, forKey: .metrostationnamear)) ?? "غير معروف"
        metroline = (try? container.decode(String.self, forKey: .metroline)) ?? "Unknown"
        metrolinename = (try? container.decode(String.self, forKey: .metrolinename)) ?? "Unknown"
        stationseq = (try? container.decode(Int.self, forKey: .stationseq)) ?? 0
        geo_point_2d = try container.decode(GeoPoint.self, forKey: .geo_point_2d)
    }
}

struct StationsAPIResponse: Codable {
    let results: [MetroStation]
}

struct MetroLineFeature: Codable {
    let type: String
    let geometry: Geometry
    let properties: Properties
    
    struct Geometry: Codable {
        let type: String
        let coordinates: [[Double]]
    }
    
    struct Properties: Codable {
        let metrolinename: String
        let metrolinenamear: String
        let m_linecolorcode: String
    }
}

struct LinesGeoJSON: Codable {
    let type: String
    let features: [MetroLineFeature]
}

struct MetroLine: Identifiable {
    let id = UUID()
    let name: String
    let nameAr: String
    let color: Color
    let coordinates: [CLLocationCoordinate2D]
}

struct SimpleStop: Identifiable {
    let id = UUID()
    let nameAr: String
    let lineCode: String
    let multiLineCodes: [String]
    
    var isInterchange: Bool {
        multiLineCodes.count > 1
    }
}

struct MetroGraph {
    var adjacency: [String: Set<String>] = [:]
    
    mutating func addEdge(_ a: String, _ b: String) {
        adjacency[a, default: []].insert(b)
        adjacency[b, default: []].insert(a)
    }
}

// MARK: - Main View
struct ContentView: View {
    @State private var lines: [MetroLine] = []
    @State private var stations: [MetroStation] = []
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 24.7136, longitude: 46.6753),
            span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
        )
    )
    
    @State private var selectedStation: MetroStation?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var locationManager = LocationManager()
    @State private var showSearchSheet = false
    @State private var favoriteStations: Set<String> = []
    @State private var originStation: MetroStation?
    @State private var destinationStation: MetroStation?
    @State private var routeStations: [MetroStation] = []
    @State private var metroGraph = MetroGraph()
    @State private var stationByCode: [String: MetroStation] = [:]
    @State private var stationNumbering: [String: Int] = [:]  // تخزين الأرقام المخصصة
    
    var body: some View {
        ZStack {
            Map(position: $cameraPosition) {
                if routeStations.isEmpty {
                    ForEach(lines) { line in
                        MapPolyline(coordinates: line.coordinates)
                            .stroke(line.color, lineWidth: 4)
                    }
                }
                
                if routeStations.count >= 2 {
                    let coords = routeStations.map { $0.coordinate }
                    MapPolyline(coordinates: coords)
                        .stroke(.gray, lineWidth: 8)
                }
                
                if let userCoord = locationManager.userLocation, !routeStations.isEmpty {
                    Annotation("Train", coordinate: userCoord) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 30, height: 30)
                                .shadow(radius: 4)
                            Image(systemName: "train.side.front.car")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                        }
                    }
                }
                
                ForEach(stations) { station in
                    let isSelected = (station == selectedStation)
                    Annotation(station.metrostationname, coordinate: station.coordinate) {
                        ZStack {
                            if isSelected {
                                Circle()
                                    .fill(lineColor(for: station.metroline).opacity(0.25))
                                    .frame(width: 40, height: 40)
                            }
                            ZStack {
                                Circle()
                                    .fill(lineColor(for: station.metroline))
                                    .frame(width: isSelected ? 28 : 20, height: isSelected ? 28 : 20)
                                    .overlay(Circle().stroke(Color.white, lineWidth: isSelected ? 3 : 2))
                                    .shadow(radius: isSelected ? 4 : 2)
                                Text("\(stationNumbering[station.metrostationcode] ?? station.stationseq)")
                                    .font(.system(size: isSelected ? 11 : 8, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .onTapGesture {
                            selectedStation = station
                            cameraPosition = .region(
                                MKCoordinateRegion(
                                    center: station.coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                                )
                            )
                        }
                        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .ignoresSafeArea()
            
            VStack(spacing: 12) {
                if !routeStations.isEmpty {
                    CompactUpcomingBanner(
                        routeStations: routeStations,
                        allStations: stations,
                        progress: routeProgress()
                    )
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top))
                }
                
                HStack(spacing: 8) {
                    Spacer()
                    if !favoriteStations.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(stations.filter { favoriteStations.contains($0.metrostationcode) }) { station in
                                    Button(action: {
                                        selectedStation = station
                                        cameraPosition = .region(
                                            MKCoordinateRegion(
                                                center: station.coordinate,
                                                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                                            )
                                        )
                                    }) {
                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(lineColor(for: station.metroline))
                                                .frame(width: 8, height: 8)
                                            Text(station.metrostationnamear)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.lingr)
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(
                                            Capsule()
                                                .fill(lineColor(for: station.metroline))
                                                .shadow(color: lineColor(for: station.metroline).opacity(0.4), radius: 4, y: 2)
                                        )
                                    }
                                }
                            }
                        }
                        .environment(\.layoutDirection, .rightToLeft)
                        .frame(maxWidth: 300)
                    }
                    
                    Button(action: { showSearchSheet = true }) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundColor(.lingr)
                            .padding()
                            .background(Color(hex: "#BAC5A5"))
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding()
                }
                Spacer()
            }
            
            if let origin = originStation, let destination = destinationStation, !routeStations.isEmpty {
                VStack {
                    Spacer()
                    RouteSummaryBar(
                        origin: origin,
                        destination: destination,
                        stopsCount: routeStations.count,
                        accentColor: .black,
                        onClear: clearRoute
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .transition(.move(edge: .bottom))
            }
            
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView().scaleEffect(1.5)
                    Text("جاري تحميل بيانات المترو...").font(.headline)
                }
                .padding(32)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
            }
            
            if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    Text(error).font(.headline).multilineTextAlignment(.center)
                    Button("إعادة المحاولة") {
                        errorMessage = nil
                        isLoading = true
                        loadMetroData()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(32)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
            }
            
            if let station = selectedStation {
                VStack {
                    Spacer()
                    StationCard(
                        station: station,
                        onClose: { selectedStation = nil },
                        onSetAsDestination: {
                            setDestination(to: station)
                            selectedStation = nil
                        }
                    )
                    .padding()
                }
                .transition(.move(edge: .bottom))
                .animation(.spring(), value: selectedStation)
            }
        }
        .sheet(isPresented: $showSearchSheet) {
            SearchSheet(
                stations: stations,
                favoriteStations: $favoriteStations,
                onSelectStation: { station in
                    selectedStation = station
                    showSearchSheet = false
                    cameraPosition = .region(
                        MKCoordinateRegion(
                            center: station.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                    )
                }
            )
        }
        .onAppear {
            locationManager.requestLocationPermission()
            loadMetroData()
        }
    }
    
    func setDestination(to station: MetroStation) {
        destinationStation = station
        if let userCoord = locationManager.userLocation, let nearest = nearestStation(to: userCoord) {
            originStation = nearest
        } else {
            originStation = station
        }
        updateRouteIfPossible()
    }
    
    func clearRoute() {
        destinationStation = nil
        originStation = nil
        routeStations = []
    }
    
    func updateRouteIfPossible() {
        guard let origin = originStation, let destination = destinationStation else {
            routeStations = []
            return
        }
        guard !stations.isEmpty else {
            routeStations = []
            return
        }
        if metroGraph.adjacency.isEmpty {
            buildGraph()
        }
        let codesPath = shortestPath(from: origin.metrostationcode, to: destination.metrostationcode, graph: metroGraph)
        if codesPath.isEmpty {
            routeStations = []
            return
        }
        let mappedStations = codesPath.compactMap { code in stationByCode[code] }
        if mappedStations.count <= 1 {
            originStation = nil
            destinationStation = nil
            routeStations = []
            return
        }
        routeStations = mappedStations
        let coords = routeStations.map { $0.coordinate }
        if !coords.isEmpty {
            let center = calculateCenter(coordinates: coords)
            let span = calculateSpan(coordinates: coords)
            cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
        }
    }
    
    func buildGraph() {
        var graph = MetroGraph()
        var codeMap: [String: MetroStation] = [:]
        stations.forEach { station in
            codeMap[station.metrostationcode] = station
        }
        let byLine = Dictionary(grouping: stations, by: { $0.metroline })
        for (_, lineStations) in byLine {
            let ordered = lineStations.sorted { $0.metrostationcode < $1.metrostationcode }
            if ordered.count >= 2 {
                for i in 0..<(ordered.count - 1) {
                    let a = ordered[i].metrostationcode
                    let b = ordered[i + 1].metrostationcode
                    graph.addEdge(a, b)
                }
            }
        }
        let byNameAr = Dictionary(grouping: stations, by: { $0.metrostationnamear })
        for (_, group) in byNameAr {
            if group.count > 1 {
                for i in 0..<group.count {
                    for j in (i + 1)..<group.count {
                        let a = group[i].metrostationcode
                        let b = group[j].metrostationcode
                        graph.addEdge(a, b)
                    }
                }
            }
        }
        metroGraph = graph
        stationByCode = codeMap
    }
    
    func shortestPath(from start: String, to end: String, graph: MetroGraph) -> [String] {
        if start == end { return [start] }
        var queue: [String] = [start]
        var visited: Set<String> = [start]
        var parent: [String: String] = [:]
        while !queue.isEmpty {
            let current = queue.removeFirst()
            guard let neighbors = graph.adjacency[current] else { continue }
            for n in neighbors {
                if !visited.contains(n) {
                    visited.insert(n)
                    parent[n] = current
                    queue.append(n)
                    if n == end {
                        var path: [String] = [end]
                        var node = end
                        while let p = parent[node], p != start {
                            path.append(p)
                            node = p
                        }
                        path.append(start)
                        return path.reversed()
                    }
                }
            }
        }
        return []
    }
    
    func nearestStation(to coordinate: CLLocationCoordinate2D) -> MetroStation? {
        guard !stations.isEmpty else { return nil }
        return stations.min { a, b in
            distance(from: coordinate, to: a.coordinate) < distance(from: coordinate, to: b.coordinate)
        }
    }
    
    func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance {
        let l1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let l2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return l1.distance(from: l2)
    }
    
    func routeProgress() -> Double {
        guard let userCoord = locationManager.userLocation, routeStations.count >= 2 else {
            return 0
        }
        let distances = routeStations.map { station in
            distance(from: userCoord, to: station.coordinate)
        }
        guard let minIndex = distances.indices.min(by: { distances[$0] < distances[$1] }) else {
            return 0
        }
        let steps = max(routeStations.count - 1, 1)
        return Double(minIndex) / Double(steps)
    }
    
    func loadMetroData() {
        Task {
            await loadStationsFromAPI()
            await loadLinesFromAPI()
        }
    }
    
    func loadStationsFromAPI() async {
        let urlString = "https://opendata.rcrc.gov.sa/api/explore/v2.1/catalog/datasets/metro-stations-in-riyadh-by-metro-line-and-station-type-2024/records?limit=-1"
        guard let url = URL(string: urlString) else {
            await MainActor.run {
                errorMessage = "رابط غير صحيح"
                isLoading = false
            }
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(StationsAPIResponse.self, from: data)
            await MainActor.run {
                stations = response.results
                buildGraph()
                if !stations.isEmpty {
                    let coords = stations.map { $0.coordinate }
                    let center = calculateCenter(coordinates: coords)
                    let span = calculateSpan(coordinates: coords)
                    cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "فشل تحميل المحطات\n\(error.localizedDescription)"
                isLoading = false
            }
        }
        generateStationNumbers()

    }
    
    
    func generateStationNumbers() {
        var numbering: [String: Int] = [:]
        let groupedByLine = Dictionary(grouping: stations, by: { $0.metroline })
        
        for (_, lineStations) in groupedByLine {
            let sortedStations = lineStations.sorted { $0.stationseq < $1.stationseq }
            
            for (index, station) in sortedStations.enumerated() {
                numbering[station.metrostationcode] = 11 + index
            }
        }
        
        stationNumbering = numbering
    }

    
    func loadLinesFromAPI() async {
        guard let url = Bundle.main.url(forResource: "metro-lines", withExtension: "geojson"),
              let data = try? Data(contentsOf: url) else {
            return
        }
        do {
            let geoJSON = try JSONDecoder().decode(LinesGeoJSON.self, from: data)
            await MainActor.run {
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
        } catch { }
    }
    
    func calculateCenter(coordinates: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        let totalLat = coordinates.reduce(0) { $0 + $1.latitude }
        let totalLon = coordinates.reduce(0) { $0 + $1.longitude }
        return CLLocationCoordinate2D(
            latitude: totalLat / Double(coordinates.count),
            longitude: totalLon / Double(coordinates.count)
        )
    }
    
    func calculateSpan(coordinates: [CLLocationCoordinate2D]) -> MKCoordinateSpan {
        let lats = coordinates.map { $0.latitude }
        let lons = coordinates.map { $0.longitude }
        let minLat = lats.min() ?? 0
        let maxLat = lats.max() ?? 0
        let minLon = lons.min() ?? 0
        let maxLon = lons.max() ?? 0
        let latDelta = (maxLat - minLat) * 1.2
        let lonDelta = (maxLon - minLon) * 1.2
        return MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
    }
    
    func lineColor(for lineCode: String) -> Color {
        switch lineCode {
        case "Line1": return Color(hex: "#00ade5")
        case "Line2": return Color(hex: "#f0493a")
        case "Line3": return Color(hex: "#f68d39")
        case "Line4": return Color(hex: "#ffd105")
        case "Line5": return Color(hex: "#43b649")
        case "Line6": return Color(hex: "#984c9d")
        default: return .gray
        }
    }
}

// MARK: - Search Sheet
struct SearchSheet: View {
    let stations: [MetroStation]
    @Binding var favoriteStations: Set<String>
    let onSelectStation: (MetroStation) -> Void
    @State private var searchText = ""
    @State private var selectedLine: String? = nil
    @Environment(\.dismiss) var dismiss
    
    // حساب الأرقام لكل خط (يبدأ من 11)
    var stationNumbering: [String: Int] {
        var numbering: [String: Int] = [:]
        let groupedByLine = Dictionary(grouping: stations, by: { $0.metroline })
        for (_, lineStations) in groupedByLine {
            let sortedStations = lineStations.sorted { $0.stationseq < $1.stationseq }
            for (index, station) in sortedStations.enumerated() {
                numbering[station.metrostationcode] = 11 + index
            }
        }
        return numbering
    }
    
    var filteredStations: [MetroStation] {
        var filtered = stations
        if let line = selectedLine {
            filtered = filtered.filter { $0.metroline == line }
        }
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.metrostationname.localizedCaseInsensitiveContains(searchText) ||
                $0.metrostationnamear.localizedCaseInsensitiveContains(searchText)
            }
        }
        return filtered.sorted { $0.stationseq < $1.stationseq }
    }
    
    var uniqueLines: [String] {
        Array(Set(stations.map { $0.metroline })).sorted()
    }
    
    var selectedLineName: String {
        guard let line = selectedLine else { return "المسارات" }
        return lineNameForCode(line)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ZStack {
                    (selectedLine != nil ? lineColorForCode(selectedLine!) : Color(hex: "#BAC5A5"))
                    HStack {
                        Spacer()
                        Text(selectedLineName)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.lingr)
                        Spacer()
                    }
                }
                .frame(height: 80)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(uniqueLines, id: \.self) { line in
                            Button(action: { selectedLine = line == selectedLine ? nil : line }) {
                                VStack(spacing: 4) {
                                    ZStack {
                                        Circle()
                                            .fill(lineColorForCode(line))
                                            .frame(width: 50, height: 50)
                                        Image(systemName: "tram.fill")
                                            .foregroundColor(.white)
                                            .font(.title3)
                                    }
                                    Text(lineNameForCode(line))
                                        .font(.caption)
                                        .foregroundColor(lineColorForCode(line))
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color(hex: "#F2F4EB"))
                
                HStack {
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("ابحث عن محطة...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .environment(\.layoutDirection, .rightToLeft)
                .padding()
                .background(Color(.grlb))
                .cornerRadius(10)
                .padding()
                
                if filteredStations.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("لا توجد نتائج")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                            ForEach(Array(filteredStations.enumerated()), id: \.element.id) { index, station in
                                Button(action: { onSelectStation(station) }) {
                                    HStack(spacing: 0) {
                                        VStack(spacing: 0) {
                                            ZStack {
                                                Circle()
                                                    .fill(lineColorForCode(station.metroline))
                                                    .frame(width: 28, height: 28)
                                                    .overlay(
                                                        Circle()
                                                            .stroke(Color.white, lineWidth: 2.5)
                                                    )
                                                Text("\(stationNumbering[station.metrostationcode] ?? station.stationseq)")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                            if index < filteredStations.count - 1 {
                                                Rectangle()
                                                    .fill(lineColorForCode(station.metroline))
                                                    .frame(width: 3)
                                            }
                                        }
                                        .frame(width: 30, height: index < filteredStations.count - 1 ? 64 : 28)
                                        .padding(.leading, 16)
                                        
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(station.metrostationnamear)
                                                .font(.body)
                                                .fontWeight(.medium)
                                                .foregroundColor(.primary)
                                            Text(station.metrostationname)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.leading, 16)
                                        .frame(height: 64)
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            if favoriteStations.contains(station.metrostationcode) {
                                                favoriteStations.remove(station.metrostationcode)
                                            } else {
                                                favoriteStations.insert(station.metrostationcode)
                                            }
                                        }) {
                                            Image(systemName: favoriteStations.contains(station.metrostationcode) ? "star.fill" : "star")
                                                .font(.title3)
                                                .foregroundColor(favoriteStations.contains(station.metrostationcode) ? .yellow : .gray)
                                        }
                                        .padding(.trailing, 16)
                                        .buttonStyle(.plain)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .navigationBarHidden(true)
            .environment(\.layoutDirection, .rightToLeft)
            .background(Color(hex: "#F2F4EB"))
        }
    }
    
    func lineColorForCode(_ code: String) -> Color {
        switch code {
        case "Line1": return Color(hex: "#00ade5")
        case "Line2": return Color(hex: "#f0493a")
        case "Line3": return Color(hex: "#f68d39")
        case "Line4": return Color(hex: "#ffd105")
        case "Line5": return Color(hex: "#43b649")
        case "Line6": return Color(hex: "#984c9d")
        default: return .gray
        }
    }
    
    func lineNameForCode(_ code: String) -> String {
        switch code {
        case "Line1": return "المسار الأزرق"
        case "Line2": return "المسار الأحمر"
        case "Line3": return "المسار البرتقالي"
        case "Line4": return "المسار الأصفر"
        case "Line5": return "المسار الأخضر"
        case "Line6": return "المسار البنفسجي"
        default: return code
        }
    }
}

// MARK: - Station Card
struct StationCard: View {
    let station: MetroStation
    let onClose: () -> Void
    let onSetAsDestination: () -> Void
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            HStack(alignment: .top) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(Color.black.opacity(0.35))
                        .clipShape(Circle())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(station.metrostationnamear)
                        .font(.headline)
                    Text(station.metrostationname)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(lineColorForStation(station.metroline))
                        .frame(width: 10, height: 10)
                    Text(station.metrolinename)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(station.metrostationcode)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.18))
                    .cornerRadius(6)
            }
            
            Button(action: onSetAsDestination) {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                    Text("تعيين كوجهة")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundColor(.white)
                .background(Color(hex: "#3A5C37"))
                .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(Color("grlback"))
        .cornerRadius(18)
        .shadow(radius: 10, y: 4)
        .environment(\.layoutDirection, .rightToLeft)
    }
    
    func lineColorForStation(_ lineCode: String) -> Color {
        switch lineCode {
        case "Line1": return Color(hex: "#00ade5")
        case "Line2": return Color(hex: "#f0493a")
        case "Line3": return Color(hex: "#f68d39")
        case "Line4": return Color(hex: "#ffd105")
        case "Line5": return Color(hex: "#43b649")
        case "Line6": return Color(hex: "#984c9d")
        default: return .gray
        }
    }
}

// MARK: - Route Summary Bar
struct RouteSummaryBar: View {
    let origin: MetroStation
    let destination: MetroStation
    let stopsCount: Int
    let accentColor: Color
    let onClear: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("من: ").bold()
                    Text(origin.metrostationnamear)
                }
                HStack {
                    Text("إلى: ").bold()
                    Text(destination.metrostationnamear)
                }
                Text("عدد المحطات في الطريق: \(stopsCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: { onClear() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.red)
                    .clipShape(Circle())
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.ultraThinMaterial))
        .shadow(radius: 4, y: 2)
    }
}

// MARK: - Compact Upcoming Banner
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
            return lineColorForCode(routeStations.first?.metroline ?? "")
        }
        let currentIndex = Int(clampedProgress * Double(totalStops - 1))
        let safeIndex = min(max(currentIndex, 0), totalStops - 1)
        return lineColorForCode(routeStations[safeIndex].metroline)
    }
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            VStack(alignment: .trailing, spacing: 2) {
                Text("متبقي \(remainingStops) محطات")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                if let next = nextStation {
                    Text("المحطة التالية: \(next.metrostationnamear)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("المحطة التالية: -")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .multilineTextAlignment(.trailing)
            
            GeometryReader { geo in
                let trackY = geo.size.height / 2
                let startX: CGFloat = 24
                let endX: CGFloat = geo.size.width - 24
                let travelWidth = endX - startX
                let clampedProgress = min(max(progress, 0), 1)
                let trainX = startX + travelWidth * clampedProgress
                
                ZStack(alignment: .leading) {
                    Path { path in
                        path.move(to: CGPoint(x: startX, y: trackY))
                        path.addLine(to: CGPoint(x: endX, y: trackY))
                    }
                    .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                    
                    Path { path in
                        path.move(to: CGPoint(x: startX, y: trackY))
                        path.addLine(to: CGPoint(x: trainX, y: trackY))
                    }
                    .stroke(currentLineColor, lineWidth: 6)
                    
                    HStack(spacing: 0) {
                        ForEach(Array(stopsToShow.enumerated()), id: \.element.id) { index, stop in
                            stopView(stop: stop)
                            if index < stopsToShow.count - 1 {
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 26, height: 26)
                            .shadow(color: .black.opacity(0.2), radius: 3)
                        Image(systemName: "tram.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(currentLineColor)
                    }
                    .position(x: trainX, y: trackY)
                }
            }
            .frame(height: 50)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "#BAC5A5"))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 3)
        )
        .environment(\.layoutDirection, .rightToLeft)
    }
    
    @ViewBuilder
    private func stopView(stop: SimpleStop) -> some View {
        if stop.isInterchange, stop.multiLineCodes.count >= 2 {
            let colors = stop.multiLineCodes.map { lineColorForCode($0) }
            Capsule()
                .fill(Color.white)
                .frame(width: 24, height: 16)
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: colors,
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 3
                        )
                )
                .shadow(color: .black.opacity(0.1), radius: 2)
        } else {
            Circle()
                .fill(lineColorForCode(stop.lineCode))
                .frame(width: 18, height: 18)
                .overlay(Circle().stroke(Color.white, lineWidth: 2.5))
                .shadow(color: .black.opacity(0.15), radius: 2)
        }
    }
    
    private func lineColorForCode(_ code: String) -> Color {
        switch code {
        case "Line1": return Color(hex: "#00ade5")
        case "Line2": return Color(hex: "#f0493a")
        case "Line3": return Color(hex: "#f68d39")
        case "Line4": return Color(hex: "#ffd105")
        case "Line5": return Color(hex: "#43b649")
        case "Line6": return Color(hex: "#984c9d")
        default: return .gray
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

#Preview {
    ContentView()
}
