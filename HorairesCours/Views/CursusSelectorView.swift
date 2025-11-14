// Views/CursusSelectorView.swift

import SwiftUI

struct CursusSelectorView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    
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
                        
                        Text("Puis choisissez votre modalité")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    if viewModel.isLoading {
                        Spacer()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Chargement...")
                                .foregroundColor(.secondary)
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
                                        .foregroundColor(.secondary)
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
                                
                                // Séparateur
                                Divider()
                                    .padding(.vertical, 8)
                                
                                // Section Modalités (exclusive - comme des radio buttons)
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Modalité")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
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
                                    
                                    // Option "Les deux"
                                    Button(action: {
                                        viewModel.selectedModalites = [.tempsPlein, .partiel]
                                    }) {
                                        HStack(spacing: 12) {
                                            Image(systemName: viewModel.selectedModalites.count == 2 ? "circle.inset.filled" : "circle")
                                                .foregroundColor(viewModel.selectedModalites.count == 2 ? .blue : .gray)
                                                .font(.system(size: 24))
                                            
                                            Text("Les deux")
                                                .font(.system(size: 16, weight: viewModel.selectedModalites.count == 2 ? .semibold : .regular))
                                                .foregroundColor(.primary)
                                            
                                            Spacer()
                                        }
                                        .padding()
                                        .background(viewModel.selectedModalites.count == 2 ? Color.blue.opacity(0.1) : Color.white)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(viewModel.selectedModalites.count == 2 ? Color.blue : Color.clear, lineWidth: 2)
                                        )
                                        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                                    }
                                    .padding(.horizontal)
                                }
                                
                                // Bouton Valider
                                Button(action: {
                                    if viewModel.selectedVolee != nil && !viewModel.selectedModalites.isEmpty {
                                        viewModel.showCursusSelector = false
                                        Task {
                                            await viewModel.loadData(forceRefresh: true)
                                        }
                                    }
                                }) {
                                    Text("Valider")
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
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationBarHidden(true)
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

struct VoleeButton: View {
    let volee: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.system(size: 24))
                
                Text(volee)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
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

// Nouveau composant: Radio button pour les modalités (exclusif)
struct ModaliteRadioButton: View {
    let modalite: Modalite
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.system(size: 24))
                
                Text(modalite.rawValue)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(.primary)
                
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
