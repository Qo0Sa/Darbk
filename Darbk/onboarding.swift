import SwiftUI

// MARK: - Onboarding Page Model
struct OnboardingPage: Identifiable {
    let id = UUID()
    let imageName: String
    let title: String
    let description: String
    let imageOnTop: Bool // true = صورة فوق، false = صورة تحت
}

// MARK: - Main Onboarding View
struct OnboardingView: View {
    @State private var currentPage = 0
    @Environment(\.dismiss) var dismiss
    
    let pages = [
        OnboardingPage(
            imageName: "on1",
            title: "تنقل أسهل مع دربك",
            description: "دربك هو مرشدك داخل المترو،\nيوجّهك بدقة ويساعدك في الوصول\nإلى محطتك بسهولة",
            imageOnTop: false // النص فوق والصورة تحت
        ),
        OnboardingPage(
            imageName: "on2",
            title: "وصول أسرع لمحطاتك",
            description: "باختيار محطاتك المفضلة، يمنحك\nالتطبيق نفاذاً أسرع وتجربة مريحة",
            imageOnTop: true // الصورة فوق والنص تحت
        )
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.grlback)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Skip Button / Back Button
                    HStack {
                        if currentPage == 0 {
                            Spacer()
                            // زر تخطي في الصفحة الأولى
                            NavigationLink(destination: ContentView().navigationBarBackButtonHidden(true)) {
                                Text("تخطي")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.lingr)
                            }
                            .padding(.trailing, 24)
                        } else {
                            // زر رجوع في الصفحة الثانية
                            Button(action: {
                                withAnimation {
                                    currentPage -= 1
                                }
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.lingr)
                            }
                            .padding(.leading, 24)
                            Spacer()
                        }
                    }
                    .padding(.top, 16)
                    
                    // Content
                    TabView(selection: $currentPage) {
                        ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                            OnboardingPageView(page: page)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(maxHeight: .infinity)
                    .flipsForRightToLeftLayoutDirection(false)
                    
                    Spacer()
                    
                    // Bottom Section
                    HStack(spacing: 150) {
                        // Page Indicator
                        HStack(spacing: 8) {
                            ForEach((0..<pages.count), id: \.self) { index in
                                Capsule()
                                    .fill(currentPage == index ? Color(.lingr) : Color(red: 0.7, green: 0.7, blue: 0.65))
                                    .frame(width: currentPage == index ? 32 : 8, height: 8)
                                    .animation(.spring(response: 0.3), value: currentPage)
                            }
                        }
                        
                        // Next Button
                        if currentPage < pages.count - 1 {
                            Button(action: {
                                withAnimation {
                                    currentPage += 1
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(.lingr)
                                        .frame(width: 64, height: 64)
                                    
                                    Text("التالي")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                        } else {
                            NavigationLink(destination: ContentView().navigationBarBackButtonHidden(true)) {
                                ZStack {
                                    Circle()
                                        .fill(.lingr)
                                        .frame(width: 64, height: 64)
                                    
                                    Text("التالي")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .flipsForRightToLeftLayoutDirection(true)
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Onboarding Page View
struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 32) {
            if page.imageOnTop {
                // الصورة فوق
                imageView
                textContent
            } else {
                // النص فوق
                textContent
                imageView
            }
        }
    }
    
    // Image Component
    private var imageView: some View {
        ZStack {
            // Placeholder for image
            Image(page.imageName)
                .scaledToFill()
                .frame(width: 350, height: 270)
        }
        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
    }
    
    // Text Content Component
    private var textContent: some View {
        VStack(spacing: 16) {
            Text(page.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.lingr)
                .multilineTextAlignment(.trailing)
            
            Text(page.description)
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(.lingr)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Preview
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}
