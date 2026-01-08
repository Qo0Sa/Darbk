//
//  StationCard.swift
//  Darbk
//
//  Created by Sarah on 20/06/1447 AH.
//

//
//  StationCard.swift
//  Darbk
//

import SwiftUI

struct StationCard: View {
    let station: MetroStation
    let onClose: () -> Void
    let onSetAsDestination: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Button(action: onClose) {
                    ZStack {
                        Circle()
                            .fill(Color.grlback)
                            .frame(width: 28, height: 28)
                            //.shadow(color: .red.opacity(0.3), radius: 4, y: 2)
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.lingr)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(station.metrostationnamear)
                        .font(.headline)
                    Text(station.metrostationname)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .environment(\.layoutDirection, .rightToLeft)
            }
            
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.lineColor(for: station.metroline))
                        .frame(width: 10, height: 10)
                    Text(Color.lineName(for: station.metroline))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
//                Text(station.metrostationcode)
//                    .font(.caption)
//                    .padding(.horizontal, 10)
//                    .padding(.vertical, 4)
//                    .background(Color.gray.opacity(0.18))
//                    .cornerRadius(6)
            }
            .environment(\.layoutDirection, .rightToLeft)
            
            Button(action: onSetAsDestination) {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                    Text("تعيين كوجهة")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundColor(.lingr)
                .background(.grlback)
                .clipShape(Capsule())
            }
            .environment(\.layoutDirection, .rightToLeft)
        }
        
        .padding(16)
        .background(.grlb)
        .cornerRadius(18)
        .shadow(radius: 10, y: 4)
        
        .environment(\.layoutDirection, .leftToRight)
    }
}
