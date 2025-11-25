// Views/CustomURLInputView.swift

import SwiftUI

struct CustomURLInputView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @Binding var isPresented: Bool
    
    @State private var customURL: String = ""
    @State private var selectedFileType: FileType = .cours
    @State private var isValidating: Bool = false
    @State private var validationError: String?
    @State private var showError: Bool = false
    
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
                        Image(systemName: "link.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("URL Personnalisée")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Entrez l'URL de votre fichier Excel")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // TextField URL
                        VStack(alignment: .leading, spacing: 8) {
                            Text("URL du fichier")
                                .font(.headline)
                                .foregroundColor(.gray)
                            
                            TextField("https://example.com/horaire.xlsx", text: $customURL)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                                .autocapitalization(.none)
                                .keyboardType(.URL)
                        }
                        
                        // Type de fichier
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Type de fichier")
                                .font(.headline)
                                .foregroundColor(.gray)
                            
                            HStack(spacing: 16) {
                                FileTypeButton(
                                    title: "Horaire de cours",
                                    fileType: .cours,
                                    isSelected: selectedFileType == .cours
                                ) {
                                    selectedFileType = .cours
                                }
                                
                                FileTypeButton(
                                    title: "Horaire d'examens",
                                    fileType: .examens,
                                    isSelected: selectedFileType == .examens
                                ) {
                                    selectedFileType = .examens
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Bouton Valider
                    if isValidating {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding()
                    } else {
                        Button(action: {
                            validateURL()
                        }) {
                            Text("Valider et sauvegarder")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    !customURL.isEmpty ? Color.blue : Color.gray
                                )
                                .cornerRadius(12)
                        }
                        .disabled(customURL.isEmpty)
                        .padding(.horizontal)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") {
                        isPresented = false
                    }
                }
            }
            .alert("Erreur de validation", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationError ?? "Une erreur est survenue")
            }
        }
    }
    
    private func validateURL() {
        guard let url = URL(string: customURL), customURL.hasSuffix(".xlsx") else {
            validationError = "URL invalide. Veuillez entrer une URL valide se terminant par .xlsx"
            showError = true
            return
        }
        
        isValidating = true
        
        Task {
            do {
                // Télécharger et valider le fichier
                let (data, response) = try await URLSession.shared.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                
                // Valider la structure du fichier
                let isValid = try ExcelParser.validateFileStructure(data, fileType: selectedFileType)
                
                if isValid {
                    // Sauvegarder l'URL personnalisée
                    let customSource = DataSource(
                        type: .customURL,
                        url: customURL,
                        fileType: selectedFileType
                    )
                    viewModel.setDataSource(customSource)
                    
                    await MainActor.run {
                        isValidating = false
                        isPresented = false
                    }
                } else {
                    throw NSError(
                        domain: "ValidationError",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "La structure du fichier ne correspond pas au format attendu"]
                    )
                }
                
            } catch {
                await MainActor.run {
                    isValidating = false
                    validationError = "Impossible de valider le fichier : \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

struct FileTypeButton: View {
    let title: String
    let fileType: FileType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: fileType == .cours ? "book.fill" : "doc.text.fill")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .black)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? Color.blue : Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue, lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}
