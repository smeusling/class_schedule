// Views/VoleeOnlySelector.swift

import SwiftUI

struct VoleeOnlySelector: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @Environment(\.dismiss) private var dismiss
    
    // ✅ NOUVEAU : Computed property pour les options disponibles de la volée sélectionnée
    private var availableOptions: [String] {
        guard let selectedVolee = viewModel.selectedVolee,
              let options = viewModel.optionsByVolee[selectedVolee] else {
            return []
        }
        return options
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.indigo.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "graduationcap.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Sélectionnez votre volée")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Puis choisissez votre modalité et option")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 40)
                    
                    if viewModel.isLoading {
                        Spacer()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Chargement...")
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    } else if viewModel.availableVolees.isEmpty {
                        Spacer()
                        Button("Charger les volées") {
                            Task {
                                await viewModel.loadCursusList()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 20) {
                                // Section Volées
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Volée")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                        .padding(.horizontal)
                                    
                                    ForEach(viewModel.availableVolees, id: \.self) { volee in
                                        VoleeButton(
                                            volee: volee,
                                            isSelected: viewModel.selectedVolee == volee
                                        ) {
                                            viewModel.selectedVolee = volee
                                        }
                                    }
                                }
                                
                                // ✅ NOUVEAU : Section Options EN PREMIER (si disponibles)
                                if !availableOptions.isEmpty {
                                    Divider()
                                        .padding(.vertical, 8)
                                    
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Option")
                                            .font(.headline)
                                            .foregroundColor(.gray)
                                            .padding(.horizontal)
                                        
                                        ForEach(availableOptions, id: \.self) { option in
                                            OptionRadioButton(
                                                option: option,
                                                isSelected: viewModel.selectedOption == option
                                            ) {
                                                viewModel.selectedOption = option
                                            }
                                        }
                                    }
                                }
                                
                                // Séparateur
                                Divider()
                                    .padding(.vertical, 8)
                                
                                // Section Modalités (APRÈS les options)
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Modalité")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                        .padding(.horizontal)
                                    
                                    ModaliteRadioButton(
                                        modalite: .tempsPlein,
                                        isSelected: viewModel.selectedModalites.contains(.tempsPlein) && !viewModel.selectedModalites.contains(.partiel)
                                    ) {
                                        viewModel.selectedModalites = [.tempsPlein]
                                    }
                                    
                                    ModaliteRadioButton(
                                        modalite: .partiel,
                                        isSelected: viewModel.selectedModalites.contains(.partiel) && !viewModel.selectedModalites.contains(.tempsPlein)
                                    ) {
                                        viewModel.selectedModalites = [.partiel]
                                    }
                                }
                                
                                // Bouton Sauvegarder
                                Button(action: {
                                    if viewModel.selectedVolee != nil && !viewModel.selectedModalites.isEmpty {
                                        dismiss()
                                    }
                                }) {
                                    Text("Sauvegarder")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(
                                            (viewModel.selectedVolee != nil && !viewModel.selectedModalites.isEmpty)
                                            ? Color.blue
                                            : Color.gray
                                        )
                                        .cornerRadius(12)
                                }
                                .disabled(viewModel.selectedVolee == nil || viewModel.selectedModalites.isEmpty)
                                .padding(.horizontal)
                                .padding(.top, 8)
                                .padding(.bottom, 32)
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Paramètres")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.light)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if viewModel.availableVolees.isEmpty {
                Task {
                    await viewModel.loadCursusList()
                }
            }
        }
    }
}

// ✅ NOUVEAU : Composant Radio Button pour les options
struct OptionRadioButton: View {
    let option: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.system(size: 24))
                
                Text(option)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(.black)
                
                Spacer()
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        }
        .padding(.horizontal)
    }
}
