// ViewModels/ScheduleViewModel.swift

import Foundation
import SwiftData

@MainActor
class ScheduleViewModel: ObservableObject {
    @Published var schedules: [CourseSchedule] = []
    @Published var courses: [String] = []
    @Published var availableVolees: [String] = []
    @Published var selectedModalites: Set<Modalite> = [.tempsPlein, .partiel] {
        didSet {
            saveModalitesPreference()
        }
    }
    @Published var optionsByVolee: [String: [String]] = [:]  // ✅ NOUVEAU
    @Published var selectedOption: String? {  // ✅ NOUVEAU
        didSet {
            saveOptionPreference()
        }
    }
    @Published var selectedVolee: String? {
        didSet {
            saveVoleePreference()
            
            // ✅ CORRECTION : Ne réinitialiser l'option que si on change vraiment de volée
            // Pas au premier chargement
            if oldValue != nil && oldValue != selectedVolee {
                // La volée a changé (pas juste le chargement initial)
                if let volee = selectedVolee, let options = optionsByVolee[volee], !options.isEmpty {
                    // Si l'option actuelle n'est pas valide pour cette volée, réinitialiser
                    if let current = selectedOption, !options.contains(current) {
                        selectedOption = nil
                    }
                } else {
                    selectedOption = nil
                }
            }
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
    
    // ✅ SIMPLIFIÉ : Gestion des écrans
    @Published var showHomeView = false
    @Published var currentDataSource: DataSource = DataSource.automatic(for: .semestre)
    @Published var currentFileType: FileType = .cours
    
    // Alertes de mise à jour
    @Published var showUpdateAlert = false
    @Published var updateAlertMessage = ""
    
    
    
    private var storageManager: StorageManager?
    
    var filteredSchedules: [CourseSchedule] {
        let filtered = schedules
        
        switch selectedView {
        case .list:
            return filtered.filter { isInCurrentWeek($0.date) }
        case .week:
            return filtered.filter { isInCurrentWeek($0.date) }
        }
    }
    
    var groupedByDate: [Date: [CourseSchedule]] {
        Dictionary(grouping: filteredSchedules) { schedule in
            Calendar.current.startOfDay(for: schedule.date)
        }
    }
    
    // ✅ NOUVEAU : Obtenir le nom du semestre actuel
    var currentSemestreName: String {
        if currentDataSource.type == .examens {
            return "Examens"
        }
        let semestre = SemestreType.current()
        return "Semestre \(semestre.rawValue)"
    }
    
    func setup(modelContext: ModelContext) {
            self.storageManager = StorageManager(modelContext: modelContext)
            self.lastUpdateDate = storageManager?.getLastUpdateDate()
            
            loadVoleePreference()
            loadModalitesPreference()
            loadOptionPreference()  // ✅ NOUVEAU
            loadDataSourcePreference()
            
            print("🔧 Setup - Volée chargée: \(selectedVolee ?? "nil")")
            print("🔧 Setup - Modalités: \(selectedModalites.map { $0.rawValue })")
            print("🔧 Setup - Option: \(selectedOption ?? "nil")")  // ✅ NOUVEAU
            
            if selectedVolee == nil {
                print("⚠️ Pas de volée sélectionnée, affichage de HomeView")
                showHomeView = true
            } else {
                if !showHomeView {
                    Task {
                        await loadFromCache()
                    }
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
    
    // ✅ SIMPLIFIÉ : Définir la source de données
    func setDataSource(_ source: DataSource) {
        currentDataSource = source
        currentFileType = source.fileType
        saveDataSourcePreference(source)
    }
    
    private func saveDataSourcePreference(_ source: DataSource) {
        if let encoded = try? JSONEncoder().encode(source) {
            UserDefaults.standard.set(encoded, forKey: "currentDataSource")
        }
    }
    
    private func loadDataSourcePreference() {
        if let data = UserDefaults.standard.data(forKey: "currentDataSource"),
           let source = try? JSONDecoder().decode(DataSource.self, from: data) {
            currentDataSource = source
            currentFileType = source.fileType
        } else {
            // Par défaut, utiliser le semestre automatique
            currentDataSource = DataSource.automatic(for: .semestre)
        }
    }
    
    // ✅ SIMPLIFIÉ : Vérifier les mises à jour
    func checkForUpdates() async {
        guard let storageManager = storageManager else { return }
        guard selectedVolee != nil else { return }
        
        print("🔍 Vérification des mises à jour...")
        
        DataSourceManager.clearCache()
        
        let mostRecentURL: String?
        switch currentDataSource.type {
        case .examens:
            mostRecentURL = await DataSourceManager.getMostRecentExamenURL()
        case .semestre:
            mostRecentURL = await DataSourceManager.getMostRecentSemestreURL()
        }
        
        guard let urlString = mostRecentURL, let url = URL(string: urlString) else {
            print("⚠️ Impossible de trouver le fichier le plus récent")
            return
        }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 10
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("⚠️ Impossible de vérifier les mises à jour")
                return
            }
            
            if let lastModifiedString = httpResponse.value(forHTTPHeaderField: "Last-Modified") {
                print("📅 Date serveur (HTTP): \(lastModifiedString)")
                
                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
                dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
                
                if let serverDate = dateFormatter.date(from: lastModifiedString) {
                    let savedDate = storageManager.getFileModificationDate()
                    
                    print("📅 Date sauvegardée: \(savedDate?.description ?? "aucune")")
                    print("📅 Date serveur: \(serverDate.description)")
                    
                    if let savedDate = savedDate {
                        if serverDate > savedDate {
                            print("🆕 Nouvelle version disponible!")
                            
                            let displayFormatter = DateFormatter()
                            displayFormatter.locale = Locale(identifier: "fr_FR")
                            displayFormatter.dateStyle = .long
                            displayFormatter.timeStyle = .short
                            
                            updateAlertMessage = "Une nouvelle version des horaires est disponible (mise à jour le \(displayFormatter.string(from: serverDate))).\n\nVoulez-vous recharger les horaires ?"
                            showUpdateAlert = true
                        } else {
                            print("✅ Fichier à jour")
                        }
                    } else {
                        print("ℹ️ Première vérification, pas de date sauvegardée")
                    }
                }
            }
            
        } catch {
            print("❌ Erreur lors de la vérification: \(error)")
        }
    }
    
    // ✅ SIMPLIFIÉ : Charger la liste des volées ET les options
    func loadCursusList() async {
        isLoading = true
        print("📄 Chargement de la liste des volées et options...")
        
        do {
            // ✅ CORRECTION : Toujours charger les volées depuis le fichier de semestre
            // (peu importe si l'utilisateur a choisi Semestre ou Examens)
            print("📥 Chargement des volées depuis le fichier semestre...")
            let mostRecentURL = await DataSourceManager.getMostRecentSemestreURL()
            
            guard let urlString = mostRecentURL, let url = URL(string: urlString) else {
                throw NSError(domain: "DataSourceError", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Impossible de trouver le fichier sur le serveur"
                ])
            }
            
            print("📥 Chargement des volées depuis: \(url.lastPathComponent)")
            
            let (data, _) = try await URLSession.shared.data(from: url)
            let volees = try ExcelParser.extractVolees(data)
            availableVolees = volees
            
            print("✅ Volées disponibles: \(volees)")
            
            // ✅ NOUVEAU : Extraire aussi les options par volée
            let optionsDict = try ExcelParser.extractOptionsForVolees(data)
            
            // Convertir Set<String> en [String] trié
            var optionsArray: [String: [String]] = [:]
            for (volee, optionsSet) in optionsDict {
                optionsArray[volee] = optionsSet.sorted()
            }
            
            optionsByVolee = optionsArray
            print("✅ Options chargées pour \(optionsArray.count) volées")
            
        } catch {
            errorMessage = "Erreur lors du chargement des volées: \(error.localizedDescription)"
            print("❌ Erreur volées: \(error)")
        }
        
        isLoading = false
    }
    
    // ✅ SIMPLIFIÉ : Charger les données
    func loadData(forceRefresh: Bool = false) async {
        guard let storageManager = storageManager else {
            print("❌ StorageManager non initialisé")
            return
        }
        
        guard let selectedVolee = selectedVolee else {
            print("⚠️ Pas de volée sélectionnée")
            showHomeView = true
            return
        }
        
        if selectedModalites.isEmpty {
            print("⚠️ Aucune modalité sélectionnée")
            errorMessage = "Veuillez sélectionner au moins une modalité (Temps Plein ou Partiel)"
            return
        }
        
        print("📄 LoadData - Volée: \(selectedVolee), Modalités: \(selectedModalites.map { $0.rawValue }), Type: \(currentFileType.rawValue), ForceRefresh: \(forceRefresh)")
        
        if !forceRefresh && storageManager.hasData() {
            print("💾 Chargement depuis le cache")
            await loadFromCache()
            return
        }
        
        isLoading = true
        errorMessage = nil
        isOfflineMode = false
        
        do {
            let mostRecentURL: String?
            switch currentDataSource.type {
            case .examens:
                mostRecentURL = await DataSourceManager.getMostRecentExamenURL()
            case .semestre:
                mostRecentURL = await DataSourceManager.getMostRecentSemestreURL()
            }
            
            guard let urlString = mostRecentURL, let url = URL(string: urlString) else {
                throw NSError(domain: "DataSourceError", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Impossible de trouver le fichier sur le serveur. Le fichier a peut-être été déplacé ou renommé."
                ])
            }
            
            print("🌐 Téléchargement depuis: \(url.lastPathComponent)")
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            
            if let lastModifiedString = httpResponse.value(forHTTPHeaderField: "Last-Modified") {
                print("📅 Date de dernière modification (HTTP): \(lastModifiedString)")
                
                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
                dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
                
                if let fileModificationDate = dateFormatter.date(from: lastModifiedString) {
                    let displayFormatter = DateFormatter()
                    displayFormatter.locale = Locale(identifier: "fr_FR")
                    displayFormatter.dateFormat = "dd/MM/yyyy à HH:mm"
                    print("✅ Fichier HTTP modifié le: \(displayFormatter.string(from: fileModificationDate))")
                    
                    storageManager.setFileModificationDate(fileModificationDate)
                }
            }
            
            if let excelHeaderDate = ExcelParser.extractUpdateDate(data) {
                let displayFormatter = DateFormatter()
                displayFormatter.locale = Locale(identifier: "fr_FR")
                displayFormatter.dateFormat = "dd/MM/yyyy"
                print("📅 Date dans l'en-tête Excel: \(displayFormatter.string(from: excelHeaderDate))")
                
                storageManager.setExcelHeaderDate(excelHeaderDate)
            }
            
            print("✅ Fichier téléchargé, parsing en cours...")
            let modalitesArray = Array(selectedModalites)
            
            let parsed = try ExcelParser.parse(data, selectedVolee: selectedVolee, modalites: modalitesArray,selectedOption: selectedOption, fileType: currentFileType)
            
            print("✅ Parsing terminé: \(parsed.count) éléments trouvés")
            
            try storageManager.saveSchedules(parsed)
            storageManager.setLastUpdateDate(Date())
            lastUpdateDate = Date()
            
            schedules = parsed
            courses = Array(Set(parsed.map { $0.cours })).sorted()
            
        } catch let error as URLError {
            errorMessage = "Erreur réseau: \(error.localizedDescription)"
            print("❌ Erreur réseau: \(error)")
            await loadFromCache()
        } catch {
            errorMessage = "Erreur: \(error.localizedDescription)"
            print("❌ Erreur: \(error)")
            await loadFromCache()
        }
        
        isLoading = false
    }
    
    func refreshData() async {
        print("🔄 Refresh forcé des données")
        await loadData(forceRefresh: true)
    }
    
    func changeCursus() {
        print("🔄 Retour à la page d'accueil")
        showHomeView = true
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
    
    // ✅ NOUVEAU : Sauvegarder/charger l'option
        private func saveOptionPreference() {
            UserDefaults.standard.set(selectedOption, forKey: "selectedOption")
            print("💾 Option sauvegardée: \(selectedOption ?? "nil")")
        }
        
        private func loadOptionPreference() {
            selectedOption = UserDefaults.standard.string(forKey: "selectedOption")
            print("📂 Option chargée: \(selectedOption ?? "nil")")
        }
}
