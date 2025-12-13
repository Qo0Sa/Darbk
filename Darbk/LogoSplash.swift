import SwiftUI

struct LogoSplashView: View {
    // اللوقو
    @State private var logoOpacity: Double = 0.0
    @State private var logoScale: CGFloat = 0.7
    @State private var logoOffsetY: CGFloat = 30
    
    // القطار
    @State private var trainProgress: CGFloat = 0.0
    @State private var showTrainLine: Bool = true
    
    @State private var isActive: Bool = false
    
    var body: some View {
        ZStack {
            Color(hex: "F1EFE7")
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // 🚆 القطار + السكة
                if showTrainLine {
                    TrainLineWithTrainIcon(progress: trainProgress)
                        .frame(height: 80)
                        .padding(.horizontal, 40)
                        .transition(.opacity)
                }
                
                // 🟩 اللوقو
                Image("DarbakSplash")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220)
                    .opacity(logoOpacity)
                    .scaleEffect(logoScale)
                    .offset(y: logoOffsetY)
                
                Spacer()
            }
        }
        .onAppear {
            startAnimation()
        }
        .fullScreenCover(isPresented: $isActive) {
            OnboardingView()
        }
    }
    
    private func startAnimation() {
        // 1) القطار يمشي من اليسار لليمين (أسرع)
        withAnimation(.easeInOut(duration: 1.0)) {  // ← كان 1.6، صار 1.0
            trainProgress = 1.0
        }
        
        // 2) بعد ما يخلص → نخفي القطار ونطلع اللوقو (أسرع)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {  // ← كان 1.6، صار 1.0
            withAnimation(.easeOut(duration: 0.2)) {  // ← كان 0.3، صار 0.2
                showTrainLine = false
            }
            
            withAnimation(.easeIn(duration: 0.6)) {  // ← كان 1.0، صار 0.6
                logoOpacity = 1.0
                logoScale   = 1.0
                logoOffsetY = 0
            }
            
            // حركة خفيفة فوق/تحت (أسرع)
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {  // ← كان 1.2، صار 1.0
                logoOffsetY = -8
            }
        }
        
        // 3) نروح للتطبيق (أسرع بكثير)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {  // ← كان 3.0، صار 2.0
            isActive = true
        }
    }
}

struct TrainLineWithTrainIcon: View {
    let progress: CGFloat
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            let startX = w * 0.07
            let endX   = w * 0.93
            let y      = h * 0.55
            let travel = endX - startX
            let clamped = min(max(progress, 0), 1)
            let trainX = startX + travel * clamped
            
            ZStack {
                // السكة (خط مستقيم)
                Path { path in
                    path.move(to: CGPoint(x: startX, y: y))
                    path.addLine(to: CGPoint(x: endX, y: y))
                }
                .stroke(Color(hex: "6F8F74"), lineWidth: 3)
                
                // القطار من الـ Assets
                Image("TrainIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 70)
                    .position(x: trainX, y: y - 16)
            }
        }
        .frame(height: 100)
    }
}

#Preview {
    LogoSplashView()
}
