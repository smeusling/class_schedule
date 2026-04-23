// ViewModels/ScheduleViewModel.swift

import Foundation
import SwiftData

@MainActor
class ScheduleViewModel: ObservableObject {

    // MARK: - Published properties

    @Published var schedules: [CourseSchedule] = []
    @Published var courses: [String] = []
    @Published var availableVolees: [String] = []
    @Published var optionsByVolee: [String: [String]] = [:]
    @Published var selectedOption: String? { didSet { saveOptionPreference() } }
    @Published var selectedModalites: Set<Modalite> = [.tempsPlein, .partiel] { didSet { saveModalitesPreference() } }
    @Published var selectedVolee: String? {
        didSet {
            saveVoleePreference()
            // Réinitialiser l'option seulement si la volée change réellement (pas au chargement initial)
            guard oldValue != nil && oldValue != selectedVolee else { return }
            if let volee = selectedVolee, let options = optionsByVolee[volee], !options.isEmpty {
                if let current = selectedOption, !options.contains(current) { selectedOption = nil }
            } else {
                selectedOption = nil
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
    @Published var showHomeView = false
    @Published var currentDataSource: DataSource = DataSource.automatic(for: .semestre)
    @Published var currentFileType: FileType = .cours
    @Published var showUpdateAlert = false
    @Published var updateAlertMessage = ""

    // MARK: - Private properties

    private var storageManager: StorageManager?

    // MARK: - Computed properties

    var filteredSchedules: [CourseSchedule] { schedules }

    var groupedByDate: [Date: [CourseSchedule]] {
        Dictionary(grouping: filteredSchedules) { schedule in
            Calendar.current.startOfDay(for: schedule.date)
        }
    }

    var currentSemestreName: String {
        currentDataSource.type == .examens ? "Examens" : "Semestre \(SemestreType.current().rawValue)"
    }

    // MARK: - Setup

    func setup(modelContext: ModelContext) {
        storageManager = StorageManager(modelContext: modelContext)
        lastUpdateDate = storageManager?.getLastUpdateDate()

        loadVoleePreference()
        loadModalitesPreference()
        loadOptionPreference()
        loadDataSourcePreference()

        if selectedVolee == nil {
            showHomeView = true
        } else if !showHomeView {
            Task { await loadFromCache() }
        }
    }

    // MARK: - Chargement des données

    func loadFromCache() async {
        guard let storageManager = storageManager else { return }

        do {
            let cachedSchedules = try storageManager.loadSchedules()
            if !cachedSchedules.isEmpty {
                schedules = cachedSchedules
                courses = Array(Set(cachedSchedules.map { $0.cours })).sorted()
                if !courses.isEmpty && selectedCourse.isEmpty { selectedCourse = courses[0] }
                isOfflineMode = true
            }
        } catch {
            print("❌ Erreur chargement cache: \(error)")
        }
    }

    func loadData(forceRefresh: Bool = false) async {
        guard let storageManager = storageManager else { return }
        guard let selectedVolee = selectedVolee else { showHomeView = true; return }

        if selectedModalites.isEmpty {
            errorMessage = "Veuillez sélectionner au moins une modalité (Temps Plein ou Partiel)"
            return
        }

        if !forceRefresh && storageManager.hasData() {
            await loadFromCache()
            return
        }

        isLoading = true
        errorMessage = nil
        isOfflineMode = false

        do {
            let mostRecentURL: String?
            switch currentDataSource.type {
            case .examens:  mostRecentURL = await DataSourceManager.getMostRecentExamenURL()
            case .semestre: mostRecentURL = await DataSourceManager.getMostRecentSemestreURL()
            }

            guard let urlString = mostRecentURL, let url = URL(string: urlString) else {
                throw NSError(domain: "DataSourceError", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Impossible de trouver le fichier sur le serveur. Le fichier a peut-être été déplacé ou renommé."
                ])
            }

            let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url))

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            // Sauvegarder la date de modification HTTP
            if let lastModifiedString = httpResponse.value(forHTTPHeaderField: "Last-Modified") {
                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
                dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
                if let fileModificationDate = dateFormatter.date(from: lastModifiedString) {
                    storageManager.setFileModificationDate(fileModificationDate)
                }
            }

            // Sauvegarder la date dans l'en-tête Excel si disponible
            if let excelHeaderDate = ExcelParser.extractUpdateDate(data) {
                storageManager.setExcelHeaderDate(excelHeaderDate)
            }

            let parsed = try ExcelParser.parse(
                data,
                selectedVolee: selectedVolee,
                modalites: Array(selectedModalites),
                selectedOption: selectedOption,
                fileType: currentFileType
            )

            try storageManager.saveSchedules(parsed)
            storageManager.setLastUpdateDate(Date())
            lastUpdateDate = Date()
            schedules = parsed
            courses = Array(Set(parsed.map { $0.cours })).sorted()

        } catch let error as URLError {
            errorMessage = "Erreur réseau: \(error.localizedDescription)"
            await loadFromCache()
        } catch {
            errorMessage = "Erreur: \(error.localizedDescription)"
            await loadFromCache()
        }

        isLoading = false
    }

    func refreshData() async {
        await loadData(forceRefresh: true)
    }

    // MARK: - Chargement de la liste des volées et options

    func loadCursusList() async {
        isLoading = true

        do {
            // Toujours charger les volées depuis le fichier de semestre (même si l'utilisateur est en mode Examens)
            guard let urlString = await DataSourceManager.getMostRecentSemestreURL(),
                  let url = URL(string: urlString) else {
                throw NSError(domain: "DataSourceError", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Impossible de trouver le fichier sur le serveur"
                ])
            }

            let (data, _) = try await URLSession.shared.data(from: url)

            availableVolees = try ExcelParser.extractVolees(data)

            let optionsDict = try ExcelParser.extractOptionsForVolees(data)
            optionsByVolee = optionsDict.mapValues { $0.sorted() }

        } catch {
            errorMessage = "Erreur lors du chargement des volées: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Vérification des mises à jour

    func checkForUpdates() async {
        guard let storageManager = storageManager, selectedVolee != nil else { return }

        DataSourceManager.clearCache()

        let mostRecentURL: String?
        switch currentDataSource.type {
        case .examens:  mostRecentURL = await DataSourceManager.getMostRecentExamenURL()
        case .semestre: mostRecentURL = await DataSourceManager.getMostRecentSemestreURL()
        }

        guard let urlString = mostRecentURL, let url = URL(string: urlString) else { return }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 10

            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let lastModifiedString = httpResponse.value(forHTTPHeaderField: "Last-Modified") else { return }

            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
            dateFormatter.timeZone = TimeZone(abbreviation: "GMT")

            guard let serverDate = dateFormatter.date(from: lastModifiedString),
                  let savedDate = storageManager.getFileModificationDate() else { return }

            if serverDate > savedDate {
                let displayFormatter = DateFormatter()
                displayFormatter.locale = Locale(identifier: "fr_FR")
                displayFormatter.dateStyle = .long
                displayFormatter.timeStyle = .short

                updateAlertMessage = "Une nouvelle version des horaires est disponible (mise à jour le \(displayFormatter.string(from: serverDate))).\n\nVoulez-vous recharger les horaires ?"
                showUpdateAlert = true
            }

        } catch {
            print("❌ Erreur vérification mises à jour: \(error)")
        }
    }

    // MARK: - Navigation

    func setDataSource(_ source: DataSource) {
        currentDataSource = source
        currentFileType = source.fileType
        saveDataSourcePreference(source)
    }

    func changeCursus() {
        showHomeView = true
    }

    // MARK: - Persistance des préférences

    private func saveVoleePreference() {
        UserDefaults.standard.set(selectedVolee, forKey: "selectedVolee")
    }

    private func loadVoleePreference() {
        selectedVolee = UserDefaults.standard.string(forKey: "selectedVolee")
    }

    private func saveModalitesPreference() {
        UserDefaults.standard.set(selectedModalites.map { $0.rawValue }, forKey: "selectedModalites")
    }

    private func loadModalitesPreference() {
        if let saved = UserDefaults.standard.array(forKey: "selectedModalites") as? [String] {
            selectedModalites = Set(saved.compactMap { Modalite(rawValue: $0) })
        }
    }

    private func saveOptionPreference() {
        UserDefaults.standard.set(selectedOption, forKey: "selectedOption")
    }

    private func loadOptionPreference() {
        selectedOption = UserDefaults.standard.string(forKey: "selectedOption")
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
            currentDataSource = DataSource.automatic(for: .semestre)
        }
    }
}
