import SwiftUI

struct RouteSummaryBar: View {
    let origin: MetroStation
    let destination: MetroStation
    let stopsCount: Int
    let accentColor: Color
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // زر الإغلاق
            Button(action: onClear) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.lingr)
                    .frame(width: 40, height: 40)
                    .background(
                        LinearGradient(
                            colors: [.grlback],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    //.shadow(color: .red.opacity(0.4), radius: 4, y: 2)
            }
            
            // معلومات الرحلة
            VStack(spacing: 12) {
                // محطة البداية
                HStack(spacing: 10) {
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("من")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(origin.metrostationnamear)
                            .font(.body)
                            .fontWeight(.bold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    
                    Circle()
                        .fill(Color.lineColor(for: origin.metroline))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                        )
                        .shadow(color: Color.lineColor(for: origin.metroline).opacity(0.4), radius: 3)
                }
                
//                // الخط الفاصل مع عدد المحطات
//                HStack(spacing: 8) {
//                    Spacer()
//                    
//                    Text("\(stopsCount) محطة")
//                        .font(.caption)
//                        .fontWeight(.semibold)
//                        .foregroundColor(.white)
//                        .padding(.horizontal, 12)
//                        .padding(.vertical, 4)
//                        .background(
//                            Capsule()
//                                .fill(Color.secondary.opacity(0.7))
//                        )
//                    
//                    Image(systemName: "arrow.down")
//                        .font(.system(size: 14, weight: .bold))
//                        .foregroundColor(.secondary)
//                }
                
                // محطة الوجهة
                HStack(spacing: 10) {
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("إلى")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(destination.metrostationnamear)
                            .font(.body)
                            .fontWeight(.bold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    
                    ZStack {
                        Circle()
                            .fill(Color.lineColor(for: destination.metroline))
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 3)
                            )
                            .shadow(color: Color.lineColor(for: destination.metroline).opacity(0.4), radius: 3)
                        
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            //.environment(\.layoutDirection, .rightToLeft)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.grlb)
            //    .stroke(Color.lingr.opacity(0.25), lineWidth: 1)

        )


    }
}
