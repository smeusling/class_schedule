// ViewModels/ScheduleViewModel.swift

import Foundation
import SwiftData

@MainActor
class ScheduleViewModel: ObservableObject {

    // MARK: - Published properties

    @Published var schedules: [CourseSchedule] = []
    @Published var courses: [String] = []
    // Catalogue des volées renvoyé par l'API (GET /api/volees), utilisé pour les cours et les examens.
    @Published var voleeCatalog: [APIVolee] = []
    // Identifiant de modalité de l'API (ex. "tempsPartiel6"), nil si aucune choisie.
    @Published var selectedModaliteId: String? { didSet { saveModalitePreference() } }
    // Identifiant d'option de l'API (ex. "santeMentale"), nil si aucune choisie.
    @Published var selectedOptionId: String? { didSet { saveOptionPreference() } }
    @Published var selectedVolee: String? {
        didSet {
            saveVoleePreference()
            // Changement réel de volée : on retire les choix qui n'existent pas pour la nouvelle volée
            guard oldValue != nil, oldValue != selectedVolee, let info = selectedVoleeInfo else { return }
            if let id = selectedModaliteId, !info.modalites.contains(where: { $0.id == id }) { selectedModaliteId = nil }
            if let id = selectedOptionId, !info.options.contains(where: { $0.id == id }) { selectedOptionId = nil }
        }
    }
    @Published var selectedCourse: String = ""
    @Published var selectedView: ViewType = .week
    @Published var selectedDate = Date()
    @Published var showAllCourses: Bool = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdateDate: Date?
    @Published var fileDate: Date?
    @Published var isOfflineMode = false
    @Published var showCursusSelector = false
    @Published var showHomeView = false
    @Published var currentDataSource: DataSource = DataSource.automatic(for: .semestre)
    @Published var currentFileType: FileType = .cours
    @Published var showUpdateAlert = false
    @Published var updateAlertMessage = ""
    @Published var showVoleeObsoleteAlert = false
    @Published var voleeObsoleteMessage = ""

    // MARK: - Private properties

    private var storageManager: StorageManager?
    // Semestre du catalogue chargé (le catalogue dépend du semestre).
    private var catalogSemestre: SemestreType?

    // Version du format des préférences de sélection.
    // 1 (avant l'API) : modalités "Temps Plein"/"Partiel", options en toutes lettres ; 2 : identifiants de l'API.
    private static let selectionFormatVersion = 2

    // Libellés de secours quand le catalogue n'est pas encore chargé (lancement hors ligne).
    private static let modaliteLabels = [
        "tempsPlein": "Temps plein",
        "tempsPartiel": "Temps partiel",
        "tempsPartiel6": "Temps partiel 6 semestres",
        "tempsPartiel8": "Temps partiel 8 semestres"
    ]
    private static let optionLabels = [
        "santeMentale": "Santé mentale",
        "soinsAdultes": "Soins aux adultes",
        "soinsPrimaires": "Soins primaires",
        "soinsPediatriques": "Soins pédiatriques",
        "optionClinique": "Option clinique",
        "optionRecherche": "Option recherche"
    ]

    // MARK: - Computed properties

    var filteredSchedules: [CourseSchedule] { schedules }

    var groupedByDate: [Date: [CourseSchedule]] {
        Dictionary(grouping: filteredSchedules) { schedule in
            Calendar.current.startOfDay(for: schedule.date)
        }
    }

    var sortedDatesWithCourses: [Date] {
        groupedByDate.keys.sorted()
    }

    // Premier jour de cours à partir d'aujourd'hui (sinon le dernier jour de cours),
    // utilisé pour positionner la vue "Tout" à l'ouverture
    var scrollTargetDateInAll: Date? {
        let today = Calendar.current.startOfDay(for: Date())
        return sortedDatesWithCourses.first(where: { $0 >= today }) ?? sortedDatesWithCourses.last
    }

    var availableVolees: [String] { voleeCatalog.map { $0.volee } }

    var selectedVoleeInfo: APIVolee? {
        guard let selectedVolee else { return nil }
        return voleeCatalog.first { $0.volee == selectedVolee }
    }

    // Semestre demandé à l'API, selon la source et la date.
    var currentSemestre: SemestreType { SemestreType.current(for: currentDataSource.type) }

    // Modalité envoyée à l'API : l'unique modalité de la volée, ou le choix de l'étudiant s'il existe pour cette volée.
    // Catalogue pas encore chargé (lancement hors ligne) : le choix enregistré.
    var effectiveModaliteId: String? {
        guard let info = selectedVoleeInfo else { return selectedModaliteId }
        return Self.effectiveChoice(selectedModaliteId, among: info.modalites)
    }

    // Option envoyée à l'API, même règle que la modalité.
    var effectiveOptionId: String? {
        guard let info = selectedVoleeInfo else { return selectedOptionId }
        return Self.effectiveChoice(selectedOptionId, among: info.options)
    }

    // Sélection utilisable : volée connue, et un choix pour chaque section qui en propose au moins deux.
    var isSelectionComplete: Bool {
        guard let info = selectedVoleeInfo else { return false }
        let modaliteOK = info.modalites.count <= 1 || effectiveModaliteId != nil
        let optionOK = info.options.count <= 1 || effectiveOptionId != nil
        return modaliteOK && optionOK
    }

    var selectedModaliteLabel: String? {
        label(for: effectiveModaliteId, in: selectedVoleeInfo?.modalites, fallback: Self.modaliteLabels)
    }

    var selectedOptionLabel: String? {
        label(for: effectiveOptionId, in: selectedVoleeInfo?.options, fallback: Self.optionLabels)
    }

    var currentSemestreName: String {
        switch (currentDataSource.type, currentSemestre) {
        case (.examens, .automne):    return "Examens d'automne"
        case (.examens, .printemps):  return "Examens de printemps"
        case (.semestre, .automne):   return "Semestre d'automne"
        case (.semestre, .printemps): return "Semestre de printemps"
        }
    }

    private static func effectiveChoice(_ chosen: String?, among choices: [APIChoice]) -> String? {
        if choices.count == 1 { return choices[0].id }
        guard let chosen, choices.contains(where: { $0.id == chosen }) else { return nil }
        return chosen
    }

    private func label(for id: String?, in choices: [APIChoice]?, fallback: [String: String]) -> String? {
        guard let id else { return nil }
        return choices?.first(where: { $0.id == id })?.label ?? fallback[id] ?? id
    }

    // MARK: - Setup

    func setup(modelContext: ModelContext) {
        storageManager = StorageManager(modelContext: modelContext)
        lastUpdateDate = storageManager?.getLastUpdateDate()
        fileDate = storageManager?.getFileModificationDate() ?? storageManager?.getExcelHeaderDate()

        loadDataSourcePreference()
        loadSelectionPreferences()

        if selectedVolee == nil {
            showHomeView = true
        } else if !showHomeView {
            Task { await loadFromCache() }
        }
    }
    
    // MARK: - Semaine d'ouverture

    // Semaine affichée à l'ouverture : celle du jour, sauf si le premier élément est dans une semaine
    // plus tardive (examens de janvier consultés en novembre, cours avant la rentrée) :
    // on ouvre alors sur la semaine du premier élément. Les flèches permettent de revenir en arrière.
    private func applyOpeningWeek() {
        let calendar = Calendar.current
        let today = Date()
        guard let first = sortedDatesWithCourses.first,
              let todayWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start,
              let firstWeek = calendar.dateInterval(of: .weekOfYear, for: first)?.start else {
            selectedDate = today
            return
        }
        selectedDate = firstWeek > todayWeek ? first : today
    }

    // MARK: - Chargement des données

    func loadFromCache() async {
        guard let storageManager = storageManager else { return }

        do {
            let cachedSchedules = try storageManager.loadSchedules()
            if !cachedSchedules.isEmpty {
                schedules = cachedSchedules
                courses = Array(Set(cachedSchedules.map { $0.cours })).sorted()
                applyOpeningWeek()
                if !courses.isEmpty && selectedCourse.isEmpty { selectedCourse = courses[0] }
                isOfflineMode = true
            }
        } catch {
            LogManager.shared.log("❌ Erreur chargement cache: \(error)")
        }
    }

    func loadData(forceRefresh: Bool = false) async {
        guard let storageManager = storageManager else { return }
        guard let selectedVolee = selectedVolee else { showHomeView = true; return }

        if !forceRefresh && storageManager.hasData() {
            await loadFromCache()
            return
        }

        isLoading = true
        errorMessage = nil
        isOfflineMode = false

        let semestre = currentSemestre
        let modalite = effectiveModaliteId
        let option = effectiveOptionId

        do {
            let parsed: [CourseSchedule]
            let dateFichier: String?
            switch currentDataSource.type {
            case .examens:
                let response = try await APIClient.fetchExams(semestre: semestre, volee: selectedVolee, modalite: modalite, option: option)
                parsed = ScheduleMapper.schedules(fromExams: response.examens)
                dateFichier = response.dateFichier
            case .semestre:
                let response = try await APIClient.fetchSchedule(semestre: semestre, volee: selectedVolee, modalite: modalite, option: option)
                parsed = ScheduleMapper.schedules(fromCourses: response.cours)
                dateFichier = response.dateFichier
            }

            // Date du fichier publié par l'UNIL, fournie par l'API (la date d'en-tête Excel n'existe plus)
            let newFileDate = ScheduleMapper.date(fromAPI: dateFichier)
            storageManager.setFileModificationDate(newFileDate)
            storageManager.setExcelHeaderDate(nil)

            try storageManager.saveSchedules(parsed)
            storageManager.setLastUpdateDate(Date())
            lastUpdateDate = Date()
            fileDate = newFileDate
            LogManager.shared.log("📄 Horaires chargés depuis l'API : \(parsed.count) éléments | \(currentSemestreName) | volée \(selectedVolee) | modalité \(modalite ?? "aucune") | option \(option ?? "aucune") | fichier du \(dateFichier ?? "?")")
            schedules = parsed
            courses = Array(Set(parsed.map { $0.cours })).sorted()
            applyOpeningWeek()

        } catch APIError.notAvailable(let message) {
            // Horaire pas encore publié : on n'affiche pas le cache, qui peut venir d'une autre source ou d'un autre semestre
            errorMessage = message
            schedules = []
        } catch {
            errorMessage = error.localizedDescription
            await loadFromCache()
        }

        isLoading = false
    }

    func refreshData() async {
        // Recharge toujours le catalogue avant les horaires : si l'UNIL a publié
        // un nouveau fichier, les volées et leurs choix peuvent avoir changé.
        await loadCursusList()

        if let selectedVolee = selectedVolee, !availableVolees.isEmpty, !availableVolees.contains(selectedVolee) {
            // La volée sélectionnée n'existe plus dans le fichier le plus récent
            voleeObsoleteMessage = "Votre volée « \(selectedVolee) » n'existe plus dans le fichier actuel de l'UNIL. Veuillez en sélectionner une nouvelle."
            showVoleeObsoleteAlert = true
            self.selectedVolee = nil
            selectedModaliteId = nil
            selectedOptionId = nil
            schedules = []
            showHomeView = true
            return
        }

        if !availableVolees.isEmpty && !isSelectionComplete {
            // Les modalités ou options de la volée ont changé : l'étudiant complète sa sélection
            voleeObsoleteMessage = "Les choix proposés pour la volée « \(selectedVolee ?? "") » ont changé. Veuillez compléter votre sélection."
            showVoleeObsoleteAlert = true
            schedules = []
            showHomeView = true
            return
        }

        await loadData(forceRefresh: true)
    }

    // MARK: - Chargement du catalogue des volées

    func loadCursusList() async {
        isLoading = true
        let semestre = currentSemestre

        do {
            voleeCatalog = try await APIClient.fetchVolees(semestre: semestre)
            catalogSemestre = semestre
        } catch {
            errorMessage = "Erreur lors du chargement des volées : \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Vérification des mises à jour

    func checkForUpdates() async {
        guard let selectedVolee = selectedVolee,
              let savedDate = storageManager?.getFileModificationDate() else { return }

        do {
            let dateFichier: String?
            switch currentDataSource.type {
            case .examens:
                dateFichier = try await APIClient.fetchExams(semestre: currentSemestre, volee: selectedVolee, modalite: effectiveModaliteId, option: effectiveOptionId).dateFichier
            case .semestre:
                dateFichier = try await APIClient.fetchSchedule(semestre: currentSemestre, volee: selectedVolee, modalite: effectiveModaliteId, option: effectiveOptionId).dateFichier
            }

            guard let serverDate = ScheduleMapper.date(fromAPI: dateFichier), serverDate > savedDate else { return }

            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "fr_FR")
            displayFormatter.timeZone = TimeZone(identifier: "UTC")
            displayFormatter.dateStyle = .long
            displayFormatter.timeStyle = .none

            updateAlertMessage = "Une nouvelle version des horaires est disponible (fichier du \(displayFormatter.string(from: serverDate))).\n\nVoulez-vous recharger les horaires ?"
            showUpdateAlert = true

        } catch {
            LogManager.shared.log("❌ Erreur vérification mises à jour: \(error.localizedDescription)")
        }
    }

    // MARK: - Navigation

    func setDataSource(_ source: DataSource) {
        currentDataSource = source
        currentFileType = source.fileType
        saveDataSourcePreference(source)

        // Le catalogue dépend du semestre : on le recharge si la nouvelle source change de semestre
        // (en janvier et février, cours = printemps mais examens = automne)
        if let catalogSemestre, catalogSemestre != currentSemestre {
            voleeCatalog = []
            Task { await loadCursusList() }
        }
    }

    func changeCursus() {
        showHomeView = true
    }

    // MARK: - Persistance des préférences

    private func saveVoleePreference() {
        UserDefaults.standard.set(selectedVolee, forKey: "selectedVolee")
    }

    private func saveModalitePreference() {
        UserDefaults.standard.set(selectedModaliteId, forKey: "selectedModaliteId")
    }

    private func saveOptionPreference() {
        UserDefaults.standard.set(selectedOptionId, forKey: "selectedOptionId")
    }

    private func loadSelectionPreferences() {
        let defaults = UserDefaults.standard
        selectedVolee = defaults.string(forKey: "selectedVolee")

        if defaults.integer(forKey: "selectionFormatVersion") < Self.selectionFormatVersion {
            // Anciennes préférences ("Temps Plein"/"Partiel", options en toutes lettres) : non reprises.
            // La volée est gardée, l'étudiant complète sa sélection une fois.
            defaults.removeObject(forKey: "selectedModalites")
            defaults.removeObject(forKey: "selectedOption")
            defaults.set(Self.selectionFormatVersion, forKey: "selectionFormatVersion")
            selectedModaliteId = nil
            selectedOptionId = nil
            if selectedVolee != nil { showHomeView = true }
            LogManager.shared.log("🔄 Préférences de sélection converties au format de l'API")
            return
        }

        selectedModaliteId = defaults.string(forKey: "selectedModaliteId")
        selectedOptionId = defaults.string(forKey: "selectedOptionId")
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
