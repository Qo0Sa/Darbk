//
//  Models.swift
//  Darbk
//
//  Created by Sarah on 20/06/1447 AH.
//

//
//  Models.swift
//  Darbk
//

import Foundation
import SwiftUI
import CoreLocation

// MARK: - Metro Station
struct MetroStation: Identifiable, Codable, Equatable, Hashable {
    let id = UUID()
    let metrostationcode: String
    let metrostationname: String
    let metrostationnamear: String
    let metroline: String
    let metrolinename: String
    let stationseq: Int
    let geo_point_2d: GeoPoint
    
    var displayNumber: Int { stationseq }
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: geo_point_2d.lat, longitude: geo_point_2d.lon)
    }
    
    static func == (lhs: MetroStation, rhs: MetroStation) -> Bool {
        lhs.metrostationcode == rhs.metrostationcode
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(metrostationcode)
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

// MARK: - Metro Line
struct MetroLine: Identifiable {
    let id = UUID()
    let name: String
    let nameAr: String
    let color: Color
    let coordinates: [CLLocationCoordinate2D]
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

// MARK: - API Responses
struct StationsAPIResponse: Codable {
    let results: [MetroStation]
}

struct LinesGeoJSON: Codable {
    let type: String
    let features: [MetroLineFeature]
}

// MARK: - Graph
struct MetroGraph {
    var adjacency: [String: Set<String>] = [:]
    
    mutating func addEdge(_ a: String, _ b: String) {
        adjacency[a, default: []].insert(b)
        adjacency[b, default: []].insert(a)
    }
    
    func shortestPath(from start: String, to end: String) -> [String] {
        if start == end { return [start] }
        var queue: [String] = [start]
        var visited: Set<String> = [start]
        var parent: [String: String] = [:]
        
        while !queue.isEmpty {
            let current = queue.removeFirst()
            guard let neighbors = adjacency[current] else { continue }
            
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
}

// MARK: - Simple Stop
struct SimpleStop: Identifiable {
    let id = UUID()
    let nameAr: String
    let lineCode: String
    let multiLineCodes: [String]
    var isInterchange: Bool { multiLineCodes.count > 1 }

    
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
    
    static func lineColor(for lineCode: String) -> Color {
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
    
    static func lineName(for lineCode: String) -> String {
        switch lineCode {
        case "Line1": return "المسار الأزرق"
        case "Line2": return "المسار الأحمر"
        case "Line3": return "المسار البرتقالي"
        case "Line4": return "المسار الأصفر"
        case "Line5": return "المسار الأخضر"
        case "Line6": return "المسار البنفسجي"
        default: return "مسار غير معروف"
        }
    }
}
