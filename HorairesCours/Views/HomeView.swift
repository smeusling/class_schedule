// Views/HomeView.swift

import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @State private var selectedDataSource: DataSourceType
    
    init(viewModel: ScheduleViewModel) {
        self.viewModel = viewModel
        _selectedDataSource = State(initialValue: viewModel.currentDataSource.type)
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    Color.white.ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        
                        // ── ROUGE : Header fixe à 400 ──────────────────────
                        ZStack {
                            Image("TopBar")
                                .resizable()
                                .scaledToFill()
                                .frame(width: geometry.size.width, height: 400)
                                .clipped()
                                .clipShape(
                                    RoundedCorner(radius: 50, corners: [.bottomLeft, .bottomRight])
                                )
                            
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
                                
                                Spacer().frame(height: 15)  // pousse les textes vers le bas
                                
                                Text("UNIL - Sciences Infirmières")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.85))
                                
                                Spacer().frame(height: 50)  // pousse les textes vers le bas
                            }
                            .frame(width: geometry.size.width, height: 400)
                        }
                        .frame(height: 400)
                        .ignoresSafeArea(edges: .top)
                        
                        // ── VERT : Zone variable, contenu centré ───────────
                        VStack(spacing: 20) {
                            Spacer()
                            
                            // Section Volée
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Volée")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.gray)
                                    .textCase(.uppercase)
                                    .padding(.horizontal, 4)
                                
                                Button(action: {
                                    viewModel.showCursusSelector = true
                                }) {
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
                        // Hauteur verte = total - rouge(400) - bleu(150)
                        .frame(height: geometry.size.height - 400 - 150)
                        
                        // ── BLEU : Zone bouton fixe à 150 ─────────────────
                        // (espace réservé, le bouton est en overlay ZStack)
                        Spacer().frame(height: 150)
                    }
                    
                    // Bouton Valider dans la zone bleue
                    Button(action: { validateAndContinue() }) {
                        Text("Valider")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                viewModel.selectedVolee != nil
                                    ? LinearGradient(colors: [Color(hex: "7B6FE8"), Color(hex: "5B5BD6")],
                                                     startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.4)],
                                                     startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(14)
                            .shadow(color: Color(hex: "7B6FE8").opacity(viewModel.selectedVolee != nil ? 0.35 : 0), radius: 10, y: 4)
                    }
                    .disabled(viewModel.selectedVolee == nil)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $viewModel.showCursusSelector) {
                VoleeOnlySelector(viewModel: viewModel)
            }
        }
    }
    
    private func validateAndContinue() {
        let source = DataSource.automatic(for: selectedDataSource)
        viewModel.setDataSource(source)
        
        if viewModel.selectedModalites.isEmpty {
            viewModel.selectedModalites = [.tempsPlein]
        }
        
        viewModel.showHomeView = false
        Task {
            await viewModel.loadData(forceRefresh: true)
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

#Preview {
    HomeView(viewModel: ScheduleViewModel())
}
