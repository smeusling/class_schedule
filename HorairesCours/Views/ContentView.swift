// Views/ContentView.swift

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = ScheduleViewModel()
    
    var body: some View {
        ZStack {
            if viewModel.showHomeView {
                HomeView(viewModel: viewModel)
                    .transition(.move(edge: .bottom))
            } else {
                NavigationView {
                    VStack(spacing: 0) {
                        TopBarView(viewModel: viewModel)
                        
                        if viewModel.isLoading {
                            Spacer()
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                Text("Chargement des horaires...")
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        } else if let error = viewModel.errorMessage, viewModel.schedules.isEmpty {
                            ErrorView(message: error) {
                                Task { await viewModel.refreshData() }
                            }
                        } else {
                            // Bannière avant le contenu
                            if viewModel.lastUpdateDate != nil {
                                OfflineBanner(
                                    lastUpdate: viewModel.lastUpdateDate,
                                    isOffline: viewModel.isOfflineMode,
                                    onRefresh: {
                                        Task { await viewModel.refreshData() }
                                    }
                                )
                            }
                            
                            // Contenu
                            if viewModel.selectedView == .week {
                                WeekView(viewModel: viewModel)
                            } else {
                                ListView(viewModel: viewModel)
                            }
                        }
                    }
                    .navigationBarHidden(true)
                }
            }
        }
        .onAppear {
            viewModel.setup(modelContext: modelContext)
        }
        .task {
            // Ne charger que si pas sur HomeView
            if !viewModel.showHomeView {
                await viewModel.loadData()
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active && !viewModel.showHomeView {
                print("📱 App activée - vérification des mises à jour")
                Task {
                    await viewModel.checkForUpdates()
                }
            }
        }
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
