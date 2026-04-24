// Views/VoleeOnlySelector.swift

import SwiftUI

struct VoleeOnlySelector: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isAtBottom = false
    
    private var availableOptions: [String] {
        guard let selectedVolee = viewModel.selectedVolee,
              let options = viewModel.optionsByVolee[selectedVolee] else {
            return []
        }
        return options
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    // ── Header violet ──────────────────────────────────
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
                            Image("SelectVoleeIcon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 70, height: 70)
                            Spacer().frame(height: 70)
                            Text("Sélectionnez votre volée")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.white)
                            Spacer().frame(height: 15)
                            Text("Modalité et option")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.85))
                            Spacer().frame(height: 50)
                        }
                        .frame(width: geometry.size.width, height: 400)
                        
                        // Bouton fermer ✕
                        VStack {
                            HStack {
                                Spacer()
                                Button(action: { dismiss() }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(10)
                                        .background(Color.white.opacity(0.25))
                                        .clipShape(Circle())
                                }
                                .padding(.trailing, 20)
                                .padding(.top, 60)
                            }
                            Spacer()
                        }
                        .frame(width: geometry.size.width, height: 400)
                    }
                    .frame(height: 400)
                    .ignoresSafeArea(edges: .top)
                    
                    // ── Contenu ────────────────────────────────────────
                    if viewModel.isLoading {
                        VStack(spacing: 16) {
                            Spacer()
                            ProgressView().scaleEffect(1.5)
                            Text("Chargement...").foregroundColor(.gray)
                            Spacer()
                        }
                        .frame(height: geometry.size.height - 400 - 100)
                        Spacer().frame(height: 100)
                        
                    } else if viewModel.availableVolees.isEmpty {
                        VStack(spacing: 20) {
                            Spacer()
                            
                            if viewModel.errorMessage != nil {
                                Button(action: {
                                    Task { await viewModel.loadCursusList() }
                                }) {
                                    Text("Charger les volées")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(
                                            LinearGradient(colors: [Color(hex: "7B6FE8"), Color(hex: "5B5BD6")],
                                                           startPoint: .leading, endPoint: .trailing)
                                        )
                                        .cornerRadius(14)
                                        .shadow(color: Color(hex: "7B6FE8").opacity(0.35), radius: 10, y: 4)
                                }
                                .padding(.horizontal)
                                
                                VStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(Color(hex: "7B6FE8").opacity(0.7))
                                        .padding(.top, 8)
                                    
                                    Text("Impossible de charger les volées")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.center)
                                    
                                    Text("Le fichier Excel de l'UNIL est introuvable.\nVérifiez votre connexion ou contactez le support.")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                    
                                    Button(action: {
                                        if let url = URL(string: "mailto:smeusling@gmail.com?subject=Horaires%20de%20Cours%20-%20Erreur%20chargement%20vol%C3%A9es") {
                                            UIApplication.shared.open(url)
                                        }
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "envelope.fill")
                                                .font(.system(size: 14))
                                            Text("Contacter le support")
                                                .font(.system(size: 14, weight: .medium))
                                        }
                                        .foregroundColor(Color(hex: "7B6FE8"))
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(Color(hex: "7B6FE8").opacity(0.1))
                                        .cornerRadius(20)
                                    }
                                }
                                
                            } else {
                                Button(action: {
                                    Task { await viewModel.loadCursusList() }
                                }) {
                                    Text("Charger les volées")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(
                                            LinearGradient(colors: [Color(hex: "7B6FE8"), Color(hex: "5B5BD6")],
                                                           startPoint: .leading, endPoint: .trailing)
                                        )
                                        .cornerRadius(14)
                                        .shadow(color: Color(hex: "7B6FE8").opacity(0.35), radius: 10, y: 4)
                                }
                                .padding(.horizontal)
                            }
                            
                            Spacer()
                        }
                        .frame(height: geometry.size.height - 400 - 100)
                        Spacer().frame(height: 100)
                        
                    } else {
                        let scrollHeight = geometry.size.height - 400 - 100
                        
                        ZStack(alignment: .bottom) {
                            ScrollView(.vertical, showsIndicators: true) {
                                VStack(spacing: 20) {
                                    
                                    // Section Volée
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Volée")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.gray)
                                            .textCase(.uppercase)
                                            .padding(.horizontal, 4)
                                        
                                        VStack(spacing: 0) {
                                            ForEach(viewModel.availableVolees, id: \.self) { volee in
                                                VStack(spacing: 0) {
                                                    VoleeListRow(
                                                        volee: volee,
                                                        isSelected: viewModel.selectedVolee == volee
                                                    ) {
                                                        viewModel.selectedVolee = volee
                                                    }
                                                    if volee != viewModel.availableVolees.last {
                                                        Divider().padding(.leading, 16)
                                                    }
                                                }
                                            }
                                        }
                                        .background(Color(UIColor.secondarySystemGroupedBackground))
                                        .cornerRadius(14)
                                    }
                                    .padding(.horizontal)
                                    
                                    // Section Options (si disponibles)
                                    if !availableOptions.isEmpty {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Option")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(.gray)
                                                .textCase(.uppercase)
                                                .padding(.horizontal, 4)
                                            
                                            VStack(spacing: 0) {
                                                ForEach(availableOptions, id: \.self) { option in
                                                    VStack(spacing: 0) {
                                                        OptionListRow(
                                                            option: option,
                                                            isSelected: viewModel.selectedOption == option
                                                        ) {
                                                            viewModel.selectedOption = option
                                                        }
                                                        if option != availableOptions.last {
                                                            Divider().padding(.leading, 16)
                                                        }
                                                    }
                                                }
                                            }
                                            .background(Color(UIColor.secondarySystemGroupedBackground))
                                            .cornerRadius(14)
                                        }
                                        .padding(.horizontal)
                                    }
                                    
                                    // Section Modalité
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Modalité")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.gray)
                                            .textCase(.uppercase)
                                            .padding(.horizontal, 4)
                                        
                                        VStack(spacing: 0) {
                                            ModaliteListRow(
                                                title: "Temps Plein",
                                                isSelected: viewModel.selectedModalites.contains(.tempsPlein) && !viewModel.selectedModalites.contains(.partiel)
                                            ) {
                                                viewModel.selectedModalites = [.tempsPlein]
                                            }
                                            Divider().padding(.leading, 16)
                                            ModaliteListRow(
                                                title: "Temps Partiel",
                                                isSelected: viewModel.selectedModalites.contains(.partiel) && !viewModel.selectedModalites.contains(.tempsPlein)
                                            ) {
                                                viewModel.selectedModalites = [.partiel]
                                            }
                                        }
                                        .background(Color(UIColor.secondarySystemGroupedBackground))
                                        .cornerRadius(14)
                                    }
                                    .padding(.horizontal)
                                    
                                    Spacer().frame(height: 20)
                                }
                                .padding(.top, 20)
                                .background(
                                    GeometryReader { scrollGeometry -> Color in
                                        let contentHeight = scrollGeometry.size.height
                                        let offsetY = scrollGeometry.frame(in: .named("scrollView")).minY
                                        DispatchQueue.main.async {
                                            isAtBottom = (-offsetY + scrollHeight) >= contentHeight - 10
                                        }
                                        return Color.clear
                                    }
                                )
                            }
                            .coordinateSpace(name: "scrollView")
                            .scrollIndicators(.visible)
                            
                            // Dégradé + flèche
                            if !isAtBottom {
                                VStack {
                                        Spacer()
                                        LinearGradient(
                                            colors: [Color.white.opacity(0), Color.white],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                        .frame(height: 50)
                                    }
                                    .allowsHitTesting(false)
                                    .animation(.easeInOut(duration: 0.2), value: isAtBottom)
                            }
                        }
                        .frame(height: scrollHeight)
                        
                        Spacer().frame(height: 100)
                    }
                }
                
                // ── Bouton Sauvegarder flottant ────────────────────────
                let canSave = viewModel.selectedVolee != nil && !viewModel.selectedModalites.isEmpty
                let showSave = !viewModel.availableVolees.isEmpty && !viewModel.isLoading
                
                Button(action: {
                    if canSave { dismiss() }
                }) {
                    Text("Sauvegarder")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            canSave
                                ? LinearGradient(colors: [Color(hex: "7B6FE8"), Color(hex: "5B5BD6")],
                                                 startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.4)],
                                                 startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(14)
                        .shadow(color: Color(hex: "7B6FE8").opacity(canSave ? 0.35 : 0), radius: 10, y: 4)
                }
                .disabled(!canSave)
                .padding(.horizontal)
                .padding(.bottom, 20)
                .opacity(showSave ? 1 : 0)
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            if viewModel.availableVolees.isEmpty {
                Task { await viewModel.loadCursusList() }
            }
        }
    }
}

// ── Ligne Volée ────────────────────────────────────────────────────────────
struct VoleeListRow: View {
    let volee: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(volee)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "7B6FE8"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}

// ── Ligne Option ───────────────────────────────────────────────────────────
struct OptionListRow: View {
    let option: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(option)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "7B6FE8"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}

// ── Ligne Modalité ─────────────────────────────────────────────────────────
struct ModaliteListRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "7B6FE8"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}
