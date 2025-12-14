//
//  ContentView.swift
//  Darbk
//
//  Created by Sarah on 20/06/1447 AH.
//

import SwiftUI
import MapKit

struct ContentView: View {
    @State private var viewModel = MapViewModel()
    @State private var locationManager = LocationManager()
    @State private var showSearchSheet = false
    
    var body: some View {
        ZStack {
            mapView
            overlayContent
            stationCardView
            locationButton
            
            // ← هنا حطيت الأزرار ثابتة
            fixedTopButtons
        }
        .sheet(isPresented: $showSearchSheet) {
            SearchSheet(
                stations: viewModel.stations,
                favoriteStations: $viewModel.favoriteStations,
                onSelectStation: { station in
                    viewModel.selectStation(station)
                    showSearchSheet = false
                }
            )
        }
        .onAppear {
            locationManager.requestLocationPermission()
            viewModel.loadMetroData()
        }
    }
    
    // MARK: - Map View
    private var mapView: some View {
        Map(position: $viewModel.cameraPosition) {
            ForEach(viewModel.lines) { line in
                MapPolyline(coordinates: line.coordinates)
                    .stroke(line.color, lineWidth: 4)
            }
            
            if let routeCoords = viewModel.routePolylineCoordinates(), routeCoords.count >= 2 {
                MapPolyline(coordinates: routeCoords)
                    .stroke(.gray.opacity(0.65), lineWidth: 7)
            }
            
            if let userCoord = locationManager.userLocation, !viewModel.routeStations.isEmpty {
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
            
            ForEach(viewModel.stations) { station in
                let isSelected = (station == viewModel.selectedStation)
                Annotation(station.metrostationname, coordinate: station.coordinate) {
                    stationAnnotation(station: station, isSelected: isSelected)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .ignoresSafeArea()
    }
    
    // MARK: - Station Annotation
    private func stationAnnotation(station: MetroStation, isSelected: Bool) -> some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(Color.lineColor(for: station.metroline).opacity(0.25))
                    .frame(width: 40, height: 40)
            }
            ZStack {
                Circle()
                    .fill(Color.lineColor(for: station.metroline))
                    .frame(width: isSelected ? 28 : 20, height: isSelected ? 28 : 20)
                    .overlay(Circle().stroke(Color.white, lineWidth: isSelected ? 3 : 2))
                    .shadow(radius: isSelected ? 4 : 2)
                Text("\(viewModel.stationNumbering[station.metrostationcode] ?? station.stationseq)")
                    .font(.system(size: isSelected ? 11 : 8, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .onTapGesture {
            viewModel.selectStation(station)
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
    }
    
    // MARK: - Overlay Content
    private var overlayContent: some View {
        VStack(spacing: 12) {
            if !viewModel.routeStations.isEmpty {
                CompactUpcomingBanner(
                    routeStations: viewModel.routeStations,
                    allStations: viewModel.stations,
                    progress: viewModel.routeProgress(userLocation: locationManager.userLocation),
                    userLocation: locationManager.userLocation
                )
                .padding(.horizontal, 16)
                .transition(.move(edge: .top))
            }
            
            Spacer()
            
            if let origin = viewModel.originStation,
               let destination = viewModel.destinationStation,
               !viewModel.routeStations.isEmpty {
                RouteSummaryBar(
                    origin: origin,
                    destination: destination,
                    stopsCount: viewModel.routeStations.count,
                    accentColor: .black,
                    onClear: viewModel.clearRoute
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom))
            }
        }
    }
    
    // MARK: - Favorite Stations
    private var favoriteStationsView: some View {
        Group {
            if !viewModel.favoriteStations.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.stations.filter { viewModel.favoriteStations.contains($0.metrostationcode) }) { station in
                            Button(action: { viewModel.selectStation(station) }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "star.fill")
                                        .font(.title3)
                                        .foregroundColor(Color.lineColor(for: station.metroline))
                                    Text(station.metrostationnamear)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.lingr)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(Color.grlb)
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.lineColor(for: station.metroline), lineWidth: 2)
                                        )
                                        .shadow(color: Color.lineColor(for: station.metroline).opacity(0.2), radius: 4, y: 2)
                                )
                            }
                        }
                    }
                }
                .environment(\.layoutDirection, .rightToLeft)
                .frame(maxWidth: 300)
            }
        }
    }
    
    // MARK: - Search Button
    private var searchButton: some View {
        Button(action: { showSearchSheet = true }) {
            Image(systemName: "magnifyingglass")
                .font(.title2)
                .foregroundColor(.lingr)
                .padding(14)
                .background(.grd)
                .clipShape(Circle())
                .shadow(color: Color.grd.opacity(0.5), radius: 8, y: 4)
        }
    }
    
    // MARK: - Station Card
    private var stationCardView: some View {
        Group {
            if let station = viewModel.selectedStation {
                VStack {
                    Spacer()
                    StationCard(
                        station: station,
                        onClose: { viewModel.selectedStation = nil },
                        onSetAsDestination: {
                            viewModel.setDestination(to: station, userLocation: locationManager.userLocation)
                            viewModel.selectedStation = nil
                        }
                    )
                    .padding()
                }
                .transition(.move(edge: .bottom))
                .animation(.spring(), value: viewModel.selectedStation)
            }
        }
    }
    
    // MARK: - Location Button
    private var locationButton: some View {
        Group {
            if viewModel.selectedStation == nil && viewModel.routeStations.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            if let loc = locationManager.userLocation {
                                viewModel.centerOnUser(location: loc)
                            }
                        }) {
                            Image(systemName: "location.fill")
                                .font(.title3)
                                .foregroundColor(.lingr)
                                .padding(10)
                                .background(.thinMaterial)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, viewModel.routeStations.isEmpty ? 40 : 110)
                    }
                }
            }
        }
    }
    
    // MARK: - Fixed Top Buttons (البحث + المفضلة)
    private var fixedTopButtons: some View {
        Group {
            if viewModel.selectedStation == nil &&
               viewModel.destinationStation == nil {
                VStack {
                    HStack(spacing: 8) {
                        Spacer()
                        favoriteStationsView
                        searchButton
                    }
                    .padding(.top,0.1 )
                    .padding(.trailing, 16)
                    
                    Spacer()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
