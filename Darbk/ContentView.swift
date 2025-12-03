import SwiftUI
import MapKit
import Foundation
import CoreLocation

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
struct MetroStation: Identifiable, Codable, Equatable {
    let id = UUID()
    let metrostationcode: String
    let metrostationname: String
    let metrostationnamear: String
    let metroline: String
    let metrolinename: String
    let geo_point_2d: GeoPoint
    
    static func == (lhs: MetroStation, rhs: MetroStation) -> Bool {
        lhs.metrostationcode == rhs.metrostationcode
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
        case metroline, metrolinename, geo_point_2d
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        metrostationcode = try container.decode(String.self, forKey: .metrostationcode)
        metrostationname = (try? container.decode(String.self, forKey: .metrostationname)) ?? "Unknown"
        metrostationnamear = (try? container.decode(String.self, forKey: .metrostationnamear)) ?? "غير معروف"
        metroline = (try? container.decode(String.self, forKey: .metroline)) ?? "Unknown"
        metrolinename = (try? container.decode(String.self, forKey: .metrolinename)) ?? "Unknown"
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

    var body: some View {
        ZStack {
            Map(position: $cameraPosition) {
                ForEach(lines) { line in
                    MapPolyline(coordinates: line.coordinates)
                        .stroke(line.color, lineWidth: 4)
                }
                
                ForEach(stations) { station in
                    Annotation(station.metrostationname, coordinate: station.coordinate) {
                        Circle()
                            .fill(lineColor(for: station.metroline))
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(lineColor(for: station.metroline), lineWidth: 3)
                            )
                            .shadow(radius: 2)
                            .onTapGesture {
                                selectedStation = station
                            }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .ignoresSafeArea()
            
            // زر البحث والمحطات المفضلة
            VStack {
                HStack(spacing: 8) {
                    Spacer()
                    
                    // المحطات المفضلة (بلون المسار)
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
                    
                    // زر البحث
                    Button(action: {
                        showSearchSheet = true
                    }) {
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
            
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("جاري تحميل بيانات المترو...")
                        .font(.headline)
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
                    Text(error)
                        .font(.headline)
                        .multilineTextAlignment(.center)
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
                    StationCard(station: station, onClose: {
                        selectedStation = nil
                    })
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
    
    // MARK: - Load Data from API
    func loadMetroData() {
        Task {
            await loadStationsFromAPI()
            await loadLinesFromAPI()
        }
    }
    
    func loadStationsFromAPI() async {
        let urlString = "https://opendata.rcrc.gov.sa/api/explore/v2.1/catalog/datasets/metro-stations-in-riyadh-by-metro-line-and-station-type-2024/records?limit=100"
        
        guard let url = URL(string: urlString) else {
            await MainActor.run {
                errorMessage = "رابط غير صحيح"
                isLoading = false
            }
            return
        }
        
        print("🌐 Fetching stations from API...")
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(StationsAPIResponse.self, from: data)
            
            await MainActor.run {
                stations = response.results
                print("✅ Loaded \(stations.count) metro stations from API")
                
                if !stations.isEmpty {
                    let coords = stations.map { $0.coordinate }
                    let center = calculateCenter(coordinates: coords)
                    let span = calculateSpan(coordinates: coords)
                    cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
                    print("📍 Camera centered at: \(center.latitude), \(center.longitude)")
                }
            }
        } catch {
            print("❌ API Error: \(error)")
            await MainActor.run {
                errorMessage = "فشل تحميل المحطات\n\(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    func loadLinesFromAPI() async {
        guard let url = Bundle.main.url(forResource: "metro-lines", withExtension: "geojson"),
              let data = try? Data(contentsOf: url) else {
            print("❌ metro-lines.geojson not found, trying API...")
            await loadLinesFromRemoteAPI()
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
                print("✅ Loaded \(lines.count) metro lines from local file")
                isLoading = false
            }
        } catch {
            print("❌ Error loading lines: \(error)")
            await loadLinesFromRemoteAPI()
        }
    }
    
    func loadLinesFromRemoteAPI() async {
        let urlString = "https://opendata.rcrc.gov.sa/api/explore/v2.1/catalog/datasets/metro-lines-in-riyadh-2024/records?limit=10"
        
        guard let url = URL(string: urlString) else { return }
        
        do {
            let (_, _) = try await URLSession.shared.data(from: url)
            print("📦 Lines data received, needs custom parsing")
            await MainActor.run {
                isLoading = false
            }
        } catch {
            print("❌ Lines API Error: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
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
        
        return filtered
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
                // Header ديناميكي بناءً على الخط المحدد
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
                
                // فلتر الخطوط بأيقونات
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
                
                // شريط البحث
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

                // قائمة المحطات بتصميم الخط العمودي
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
                                Button(action: {
                                    onSelectStation(station)
                                }) {
                                    HStack(spacing: 0) {
                                        // الخط العمودي والدائرة (على اليمين)
                                        VStack(spacing: 0) {
                                            ZStack {
                                                // الدائرة
                                                Circle()
                                                    .stroke(lineColorForCode(station.metroline), lineWidth: 3)
                                                    .frame(width: 24, height: 24)
                                                    .background(Circle().fill(Color.white))
                                                
                                                // أيقونة M للمحطة الأولى
                                                if index == 0 {
                                                    Circle()
                                                        .fill(lineColorForCode(station.metroline))
                                                        .frame(width: 28, height: 28)
                                                    Text("M")
                                                        .font(.caption)
                                                        .fontWeight(.bold)
                                                        .foregroundColor(.white)
                                                }
                                            }
                                            
                                            // الخط العمودي
                                            if index < filteredStations.count - 1 {
                                                Rectangle()
                                                    .fill(lineColorForCode(station.metroline))
                                                    .frame(width: 3)
                                            }
                                        }
                                        .frame(width: 30, height: index < filteredStations.count - 1 ? 64 : 24)
                                        .padding(.leading, 16)
                                        
                                        // اسم المحطة
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
                                        
                                        // زر المفضلة على اليسار
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(station.metrostationname)
                        .font(.headline)
                    Text(station.metrostationnamear)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title2)
                }
            }
            
            HStack {
                Circle()
                    .fill(lineColorForStation(station.metroline))
                    .frame(width: 12, height: 12)
                Text(station.metrolinename)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text(station.metrostationcode)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(4)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(radius: 10)
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

// MARK: - Preview
#Preview {
    ContentView()
}
