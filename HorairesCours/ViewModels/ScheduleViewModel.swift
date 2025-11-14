// ViewModels/ScheduleViewModel.swift

import Foundation
import SwiftData

@MainActor
class ScheduleViewModel: ObservableObject {
    @Published var schedules: [CourseSchedule] = []
    @Published var courses: [String] = []
    @Published var availableVolees: [String] = []
    @Published var selectedVolee: String? {
        didSet {
            saveVoleePreference()
        }
    }
    @Published var selectedModalites: Set<Modalite> = [.tempsPlein, .partiel] {
        didSet {
            saveModalitesPreference()
        }
    }
    @Published var selectedCourse: String = ""
    @Published var selectedView: ViewType = .week
    @Published var selectedDate = Date()
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdateDate: Date?
    @Published var isOfflineMode = false
    @Published var showCursusSelector = false
    
    private let excelURL = "https://www.unil.ch/files/live/sites/fbm/files/06-espaces/sciences-infirmieres/20251106_Horaire_Automne_2025.xlsx"
    private var storageManager: StorageManager?
    
    var filteredSchedules: [CourseSchedule] {
        let filtered = schedules
        
        switch selectedView {
        case .day:
            return filtered.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
        case .week:
            return filtered.filter { isInCurrentWeek($0.date) }
        case .list, .month:
            return filtered
        }
    }
    
    var groupedByDate: [Date: [CourseSchedule]] {
        Dictionary(grouping: filteredSchedules) { schedule in
            Calendar.current.startOfDay(for: schedule.date)
        }
    }
    
    func setup(modelContext: ModelContext) {
        self.storageManager = StorageManager(modelContext: modelContext)
        self.lastUpdateDate = storageManager?.getLastUpdateDate()
        
        loadVoleePreference()
        loadModalitesPreference()
        
        print("🔧 Setup - Volée chargée: \(selectedVolee ?? "nil")")
        print("🔧 Setup - Modalités: \(selectedModalites.map { $0.rawValue })")
        
        if selectedVolee == nil {
            print("⚠️ Pas de volée sélectionnée, affichage du sélecteur")
            showCursusSelector = true
        } else {
            Task {
                await loadFromCache()
            }
        }
    }
    
    func loadFromCache() async {
        guard let storageManager = storageManager else {
            print("❌ StorageManager non initialisé")
            return
        }
        
        do {
            let cachedSchedules = try storageManager.loadSchedules()
            print("💾 Schedules chargés du cache: \(cachedSchedules.count)")
            
            if !cachedSchedules.isEmpty {
                schedules = cachedSchedules
                courses = Array(Set(cachedSchedules.map { $0.cours })).sorted()
                
                if let firstDate = cachedSchedules.first?.date {
                    selectedDate = firstDate
                }
                
                if !courses.isEmpty && selectedCourse.isEmpty {
                    selectedCourse = courses[0]
                }
                
                isOfflineMode = true
            } else {
                print("⚠️ Cache vide")
            }
        } catch {
            print("❌ Erreur lors du chargement du cache: \(error)")
        }
    }
    
    func loadCursusList() async {
        isLoading = true
        print("🔄 Chargement de la liste des volées...")
        
        do {
            guard let url = URL(string: excelURL) else {
                throw URLError(.badURL)
            }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            let volees = try ExcelParser.extractVolees(data)
            availableVolees = volees
            
            print("✅ Volées disponibles: \(volees)")
            
        } catch {
            errorMessage = "Erreur lors du chargement des volées: \(error.localizedDescription)"
            print("❌ Erreur volées: \(error)")
        }
        
        isLoading = false
    }
    
    func loadData(forceRefresh: Bool = false) async {
        guard let storageManager = storageManager else {
            print("❌ StorageManager non initialisé")
            return
        }
        
        guard let selectedVolee = selectedVolee else {
            print("⚠️ Pas de volée sélectionnée")
            showCursusSelector = true
            return
        }
        
        if selectedModalites.isEmpty {
            print("⚠️ Aucune modalité sélectionnée")
            errorMessage = "Veuillez sélectionner au moins une modalité (Temps Plein ou Partiel)"
            return
        }
        
        print("🔄 LoadData - Volée: \(selectedVolee), Modalités: \(selectedModalites.map { $0.rawValue }), ForceRefresh: \(forceRefresh)")
        
        if !forceRefresh && storageManager.hasData() {
            print("💾 Chargement depuis le cache")
            await loadFromCache()
            return
        }
        
        isLoading = true
        errorMessage = nil
        isOfflineMode = false
        
        do {
            guard let url = URL(string: excelURL) else {
                throw URLError(.badURL)
            }
            
            print("🌐 Téléchargement du fichier Excel...")
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            
            print("✅ Fichier téléchargé, parsing en cours...")
            let modalitesArray = Array(selectedModalites)
            let parsed = try ExcelParser.parse(data, selectedVolee: selectedVolee, modalites: modalitesArray)
            
            print("✅ Parsing terminé: \(parsed.count) cours trouvés")
            
            try storageManager.saveSchedules(parsed)
            storageManager.setLastUpdateDate(Date())
            lastUpdateDate = Date()
            
            schedules = parsed
            courses = Array(Set(parsed.map { $0.cours })).sorted()
            
            if let firstDate = parsed.first?.date {
                selectedDate = firstDate
                print("📅 Date initialisée à: \(firstDate)")
            }
            
        } catch let error as URLError {
            errorMessage = "Erreur réseau: \(error.localizedDescription)"
            print("❌ Erreur réseau: \(error)")
            await loadFromCache()
        } catch {
            errorMessage = "Erreur de parsing: \(error.localizedDescription)"
            print("❌ Erreur parsing: \(error)")
            await loadFromCache()
        }
        
        isLoading = false
    }
    
    func refreshData() async {
        print("🔄 Refresh forcé des données")
        await loadData(forceRefresh: true)
    }
    
    func changeCursus() {
        print("🔄 Changement de cursus demandé")
        showCursusSelector = true
    }
    
    private func saveVoleePreference() {
        if let volee = selectedVolee {
            UserDefaults.standard.set(volee, forKey: "selectedVolee")
            print("💾 Volée sauvegardée: \(volee)")
        }
    }
    
    private func loadVoleePreference() {
        selectedVolee = UserDefaults.standard.string(forKey: "selectedVolee")
        print("📂 Volée chargée des préférences: \(selectedVolee ?? "nil")")
    }
    
    private func saveModalitesPreference() {
        let modalitesStrings = selectedModalites.map { $0.rawValue }
        UserDefaults.standard.set(modalitesStrings, forKey: "selectedModalites")
        print("💾 Modalités sauvegardées: \(modalitesStrings)")
    }
    
    private func loadModalitesPreference() {
        if let saved = UserDefaults.standard.array(forKey: "selectedModalites") as? [String] {
            selectedModalites = Set(saved.compactMap { Modalite(rawValue: $0) })
        }
        print("📂 Modalités chargées: \(selectedModalites.map { $0.rawValue })")
    }
    
    private func isInCurrentWeek(_ date: Date) -> Bool {
        let calendar = Calendar.current
        
        guard let selectedWeekStart = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start,
              let dateWeekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start else {
            return false
        }
        
        return calendar.isDate(selectedWeekStart, equalTo: dateWeekStart, toGranularity: .day)
    }
}
