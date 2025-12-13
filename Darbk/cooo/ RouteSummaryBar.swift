//
//   RouteSummaryBar.swift
//  Darbk
//
//  Created by Sarah on 20/06/1447 AH.
//

//
//  RouteSummaryBar.swift
//  Darbk
//

import SwiftUI

struct RouteSummaryBar: View {
    let origin: MetroStation
    let destination: MetroStation
    let stopsCount: Int
    let accentColor: Color
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onClear) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.red.opacity(0.9))
                    .clipShape(Circle())
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("من: \(origin.metrostationnamear)   إلى: \(destination.metrostationnamear)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
               
                
            }
            .environment(\.layoutDirection, .rightToLeft)
            
            Spacer()
        }
        .environment(\.layoutDirection, .leftToRight)
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
        )
    }
}

