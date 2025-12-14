//
//  SearchSheet.swift
//  Darbk
//
//  Created by Sarah on 20/06/1447 AH.
//



import SwiftUI

struct SearchSheet: View {
    let stations: [MetroStation]
    @Binding var favoriteStations: Set<String>
    let onSelectStation: (MetroStation) -> Void
    @State private var searchText = ""
    @State private var selectedLine: String? = nil
    @Environment(\.dismiss) var dismiss
    
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
        return Color.lineName(for: line)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerView
                lineFilterView
                searchBar
                stationsList
            }
            .navigationBarHidden(true)
            .environment(\.layoutDirection, .rightToLeft)
            .background(Color(hex: "#F2F4EB"))
        }
    }
    
    private var headerView: some View {
        ZStack {
            (selectedLine != nil ? Color.lineColor(for: selectedLine!) : Color.grd)
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
    }
    
    private var lineFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(uniqueLines, id: \.self) { line in
                    Button(action: { selectedLine = line == selectedLine ? nil : line }) {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(Color.lineColor(for: line))
                                    .frame(width: 50, height: 50)
                                Image(systemName: "tram.fill")
                                    .foregroundColor(.white)
                                    .font(.title3)
                            }
                            Text(Color.lineName(for: line))
                                .font(.caption)
                                .foregroundColor(Color.lineColor(for: line))
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(hex: "#F2F4EB"))
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("ابحث عن محطة...", text: $searchText)
                .textFieldStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .trailing) // ← هذا
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(.grlb))
        .cornerRadius(10)
        .padding()
    }
    
    private var stationsList: some View {
        Group {
            if filteredStations.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                        ForEach(Array(filteredStations.enumerated()), id: \.element.id) { index, station in
                            stationRow(station: station, index: index)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("لا توجد نتائج")
                .font(.headline)
                .foregroundColor(.gray)
        }
        .frame(maxHeight: .infinity)
    }
    
    private func stationRow(station: MetroStation, index: Int) -> some View {
        Button(action: { onSelectStation(station) }) {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(Color.lineColor(for: station.metroline))
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
                            .fill(Color.lineColor(for: station.metroline))
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
                        .foregroundColor(favoriteStations.contains(station.metrostationcode) ? .lingr : .grd)
                }
                .padding(.trailing, 16)
                .buttonStyle(.plain)
            }
        }
        .buttonStyle(.plain)
    }
}
