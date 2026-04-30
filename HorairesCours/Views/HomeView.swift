// Views/HomeView.swift

import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @State private var selectedDataSource: DataSourceType
    @State private var showInfoPanel = false
    @State private var showDonationInPanel = false
    @StateObject private var storeManager = StoreManager()
    
    init(viewModel: ScheduleViewModel) {
        self.viewModel = viewModel
        _selectedDataSource = State(initialValue: viewModel.currentDataSource.type)
    }
    
    func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let identifier = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "Unknown"
            }
        }
        return identifier
    }
    
    private func sendSupportEmail() {
        let logs = LogManager.shared.getLogs()
        let deviceInfo = LogManager.shared.getDeviceInfo()
        
        let body = """
        Bonjour,
        
        Je rencontre un problème avec l'application Horaires de Cours.
        
        \(deviceInfo)
        
        ═══════════════════════════
        LOGS DE DIAGNOSTIC
        ═══════════════════════════
        \(logs.isEmpty ? "Aucun log disponible" : logs)
        """
        
        let subject = "Horaires de Cours - Support"
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let url = URL(string: "mailto:smeusling@gmail.com?subject=\(encodedSubject)&body=\(encodedBody)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func validateAndContinue() {
        let source = DataSource.automatic(for: selectedDataSource)
        viewModel.setDataSource(source)
        if viewModel.selectedModalites.isEmpty {
            viewModel.selectedModalites = [.tempsPlein]
        }
        viewModel.showHomeView = false
        Task { await viewModel.loadData(forceRefresh: true) }
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    Color.white.ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        
                        // ── Header ─────────────────────────────────────────
                        ZStack {
                            Image("TopBar")
                                .resizable()
                                .scaledToFill()
                                .frame(width: geometry.size.width, height: 400)
                                .clipped()
                                .clipShape(RoundedCorner(radius: 50, corners: [.bottomLeft, .bottomRight]))
                            
                            VStack(spacing: 0) {
                                Spacer()
                                Image("HoraireCoursIcon")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 70, height: 70)
                                Spacer().frame(height: 70)
                                Text("Horaires de Cours")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer().frame(height: 15)
                                Text("UNIL - Sciences Infirmières")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.85))
                                Spacer().frame(height: 50)
                            }
                            .frame(width: geometry.size.width, height: 400)
                        }
                        .frame(height: 400)
                        .ignoresSafeArea(edges: .top)
                        
                        // ── Zone verte ─────────────────────────────────────
                        VStack(spacing: 20) {
                            Spacer()
                            
                            // Section Volée
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Volée")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.gray)
                                    .textCase(.uppercase)
                                    .padding(.horizontal, 4)
                                
                                Button(action: { viewModel.showCursusSelector = true }) {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(viewModel.selectedVolee ?? "Choisissez votre volée")
                                                .foregroundColor(viewModel.selectedVolee == nil ? .gray : .primary)
                                                .font(.system(size: 16, weight: .medium))
                                            if viewModel.selectedVolee != nil {
                                                HStack(spacing: 6) {
                                                    if !viewModel.selectedModalites.isEmpty {
                                                        Text(viewModel.selectedModalites.map { $0.rawValue }.joined(separator: ", "))
                                                            .font(.system(size: 13))
                                                            .foregroundColor(.gray)
                                                    }
                                                    if !viewModel.selectedModalites.isEmpty && viewModel.selectedOption != nil {
                                                        Text("•").font(.system(size: 13)).foregroundColor(.gray)
                                                    }
                                                    if let option = viewModel.selectedOption {
                                                        Text(option).font(.system(size: 13)).foregroundColor(.gray)
                                                    }
                                                }
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.gray)
                                    }
                                    .padding(16)
                                    .background(Color(UIColor.secondarySystemGroupedBackground))
                                    .cornerRadius(14)
                                }
                            }
                            .padding(.horizontal)
                            
                            // Section Source des horaires
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Source des horaires")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.gray)
                                    .textCase(.uppercase)
                                    .padding(.horizontal, 4)
                                
                                VStack(spacing: 10) {
                                    DataSourceRadioButton(
                                        title: "Semestre",
                                        icon: "book.fill",
                                        isSelected: selectedDataSource == .semestre
                                    ) { selectedDataSource = .semestre }
                                    
                                    DataSourceRadioButton(
                                        title: "Examens",
                                        icon: "pencil.and.list.clipboard",
                                        isSelected: selectedDataSource == .examens
                                    ) { selectedDataSource = .examens }
                                }
                            }
                            .padding(.horizontal)
                            
                            Spacer()
                        }
                        .frame(height: geometry.size.height - 400 - 150)
                        
                        Spacer().frame(height: 150)
                    }
                    
                    // ── Bouton Valider flottant ────────────────────────────
                    VStack(spacing: 8) {
                        PrimaryButton(title: "Valider") { validateAndContinue() }
                            .padding(.horizontal)
                        Button(action: { showInfoPanel = true }) {
                            Text("À propos")
                                .font(.system(size: 13))
                                .foregroundColor(.gray.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.bottom, 20)
                }
                .overlay {
                    if showInfoPanel {
                        ZStack {
                            Color.black.opacity(0.5)
                                .ignoresSafeArea()
                                .onTapGesture {
                                    withAnimation {
                                        showInfoPanel = false
                                        showDonationInPanel = false
                                    }
                                }
                            
                            VStack(spacing: 20) {
                                
                                // Header
                                HStack {
                                    if showDonationInPanel {
                                        Button(action: { withAnimation { showDonationInPanel = false } }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "chevron.left")
                                                    .font(.system(size: 14, weight: .semibold))
                                                Text("Retour")
                                                    .font(.system(size: 14))
                                            }
                                            .foregroundColor(Color(hex: "7B6FE8"))
                                        }
                                    } else {
                                        Text("À propos")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(.primary)
                                    }
                                    Spacer()
                                    Button(action: {
                                        withAnimation {
                                            showInfoPanel = false
                                            showDonationInPanel = false
                                        }
                                    }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.gray)
                                            .padding(8)
                                            .background(Color.gray.opacity(0.1))
                                            .clipShape(Circle())
                                    }
                                }
                                
                                Divider()
                                
                                if showDonationInPanel {
                                    // ── Vue Don ───────────────────────────
                                    DonationInlineView(storeManager: storeManager, onBack: {
                                        withAnimation { showDonationInPanel = false }
                                    })
                                    
                                } else {
                                    // ── Vue À propos ──────────────────────
                                    VStack(spacing: 8) {
                                        HStack {
                                            Text("Application")
                                                .font(.system(size: 14))
                                                .foregroundColor(.gray)
                                            Spacer()
                                            Text("Horaires de Cours")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.primary)
                                        }
                                        HStack {
                                            Text("Version")
                                                .font(.system(size: 14))
                                                .foregroundColor(.gray)
                                            Spacer()
                                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.primary)
                                        }
                                        HStack {
                                            Text("Appareil")
                                                .font(.system(size: 14))
                                                .foregroundColor(.gray)
                                            Spacer()
                                            Text(UIDevice.current.name)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.primary)
                                        }
                                        HStack {
                                            Text("iOS")
                                                .font(.system(size: 14))
                                                .foregroundColor(.gray)
                                            Spacer()
                                            Text(UIDevice.current.systemVersion)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.primary)
                                        }
                                    }
                                    
                                    Divider()
                                    
                                    VStack(spacing: 10) {
                                        PrimaryButton(title: "Contacter le support") {
                                            sendSupportEmail()
                                        }
                                        
                                        Button(action: { withAnimation { showDonationInPanel = true } }) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "heart.fill")
                                                    .font(.system(size: 14))
                                                Text("Faire un don")
                                                    .font(.system(size: 16, weight: .medium))
                                            }
                                            .foregroundColor(Color(hex: "7B6FE8"))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .background(Color(hex: "7B6FE8").opacity(0.08))
                                            .cornerRadius(14)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14)
                                                    .stroke(Color(hex: "7B6FE8").opacity(0.2), lineWidth: 1)
                                            )
                                        }
                                    }
                                }
                            }
                            .padding(24)
                            .background(Color.white)
                            .cornerRadius(20)
                            .shadow(color: .black.opacity(0.2), radius: 20)
                            .padding(.horizontal, 24)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showInfoPanel)
                    }
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $viewModel.showCursusSelector) {
                VoleeOnlySelector(viewModel: viewModel)
            }
        }
    }
}

// ── Radio Button ───────────────────────────────────────────────────────────
struct DataSourceRadioButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(isSelected ? Color(hex: "7B6FE8") : .gray)
                Text(title)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .gray)
                Spacer()
                Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                    .foregroundColor(isSelected ? Color(hex: "7B6FE8") : .gray)
                    .font(.system(size: 20))
            }
            .padding(14)
            .background(
                isSelected
                    ? Color(hex: "7B6FE8").opacity(0.08)
                    : Color(UIColor.secondarySystemGroupedBackground)
            )
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color(hex: "7B6FE8") : Color.clear, lineWidth: 1.5)
            )
        }
        .frame(maxWidth: .infinity)
    }
}

// ── Coins arrondis custom ──────────────────────────────────────────────────
struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// ── Extension couleur hex ──────────────────────────────────────────────────
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
