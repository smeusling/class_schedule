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
            ZStack {
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.indigo.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Horaires de Cours")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("UNIL - Sciences Infirmières")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 40)
                    
                    VStack(spacing: 24) {
                        // Section Volée
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Volée")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            
                            Button(action: {
                                viewModel.showCursusSelector = true
                            }) {
                                VStack(spacing: 0) {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(viewModel.selectedVolee ?? "Choisissez votre volée")
                                                .foregroundColor(viewModel.selectedVolee == nil ? .gray : .black)
                                                .font(.system(size: 16, weight: .medium))
                                            
                                            // ✅ NOUVEAU : Afficher modalité et option
                                            if viewModel.selectedVolee != nil {
                                                HStack(spacing: 8) {
                                                    // Modalité
                                                    if !viewModel.selectedModalites.isEmpty {
                                                        let modaliteText = viewModel.selectedModalites.map { $0.rawValue }.joined(separator: ", ")
                                                        Text(modaliteText)
                                                            .font(.system(size: 13))
                                                            .foregroundColor(.gray)
                                                    }
                                                    
                                                    // Séparateur si modalité ET option
                                                    if !viewModel.selectedModalites.isEmpty && viewModel.selectedOption != nil {
                                                        Text("•")
                                                            .font(.system(size: 13))
                                                            .foregroundColor(.gray)
                                                    }
                                                    
                                                    // Option
                                                    if let option = viewModel.selectedOption {
                                                        Text(option)
                                                            .font(.system(size: 13))
                                                            .foregroundColor(.gray)
                                                    }
                                                }
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                }
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Section Source de données
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Source des horaires")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                DataSourceRadioButton(
                                    title: "Semestre",
                                    isSelected: selectedDataSource == .semestre
                                ) {
                                    selectedDataSource = .semestre
                                }
                                
                                DataSourceRadioButton(
                                    title: "Examens",
                                    isSelected: selectedDataSource == .examens
                                ) {
                                    selectedDataSource = .examens
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Bouton Valider
                        Button(action: {
                            validateAndContinue()
                        }) {
                            Text("Valider")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    viewModel.selectedVolee != nil ? Color.blue : Color.gray
                                )
                                .cornerRadius(12)
                        }
                        .disabled(viewModel.selectedVolee == nil)
                        .padding(.horizontal)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $viewModel.showCursusSelector) {
                VoleeOnlySelector(viewModel: viewModel)
            }
        }
    }
    
    private func validateAndContinue() {
        // Définir la source de données selon la sélection
        let source = DataSource.automatic(for: selectedDataSource)
        viewModel.setDataSource(source)
        
        // Vérifier que modalité est bien sélectionnée
        if viewModel.selectedModalites.isEmpty {
            viewModel.selectedModalites = [.tempsPlein]
        }
        
        viewModel.showHomeView = false
        Task {
            await viewModel.loadData(forceRefresh: true)
        }
    }
}

// Composant Radio Button pour les sources
struct DataSourceRadioButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.system(size: 24))
                
                Text(title)
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

