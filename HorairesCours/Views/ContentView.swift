// Views/ContentView.swift

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase // ✅ NOUVEAU
    @StateObject private var viewModel = ScheduleViewModel()
    
    var body: some View {
        ZStack {
            NavigationView {
                VStack(spacing: 0) {
                    TopBarView(viewModel: viewModel)
                    
                    if viewModel.isOfflineMode {
                        OfflineBanner(lastUpdate: viewModel.lastUpdateDate)
                    }
                    
                    if viewModel.isLoading {
                        Spacer()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Chargement des horaires...")
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    } else if let error = viewModel.errorMessage, viewModel.schedules.isEmpty {
                        ErrorView(message: error) {
                            Task { await viewModel.refreshData() }
                        }
                    } else {
                        if viewModel.selectedView == .week {
                            WeekView(viewModel: viewModel)
                        } else {
                            ListView(viewModel: viewModel)
                        }
                    }
                }
                .navigationBarHidden(true)
            }
            
            if viewModel.showCursusSelector {
                CursusSelectorView(viewModel: viewModel)
                    .transition(.move(edge: .bottom))
            }
        }
        .onAppear {
            viewModel.setup(modelContext: modelContext)
        }
        .task {
            await viewModel.loadData()
        }
        // ✅ NOUVEAU : Détecter les changements de phase de l'app
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                print("📱 App activée - vérification des mises à jour")
                Task {
                    await viewModel.checkForUpdates()
                }
            }
        }
        // ✅ NOUVEAU : Alerte de mise à jour
        .alert("Mise à jour disponible", isPresented: $viewModel.showUpdateAlert) {
            Button("Plus tard", role: .cancel) {
                viewModel.showUpdateAlert = false
            }
            Button("Recharger") {
                viewModel.showUpdateAlert = false
                Task {
                    await viewModel.refreshData()
                }
            }
        } message: {
            Text(viewModel.updateAlertMessage)
        }
    }
}
