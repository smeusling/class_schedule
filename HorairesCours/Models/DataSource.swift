// Models/DataSource.swift

import Foundation

enum DataSourceType: String, Codable, CaseIterable {
    case semestre = "Semestre"
    case examens = "Examens"
}

enum FileType: String, Codable {
    case cours = "Horaire de cours"
    case examens = "Horaire d'examens"
}

enum SemestreType: String, Codable {
    case automne = "Automne"
    case printemps = "Printemps"
    
    static func current() -> SemestreType {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: Date())
        // Janvier à Août = Printemps, Septembre à Décembre = Automne
        return (month >= 1 && month <= 8) ? .printemps : .automne
    }
}

struct DataSource: Codable {
    let type: DataSourceType
    let url: String
    let fileType: FileType
    
    private static let baseURL = "https://www.unil.ch/files/live/sites/fbm/files/06-espaces/sciences-infirmieres/"
    
    static let semestreAutomne = DataSource(
        type: .semestre,
        url: "https://www.unil.ch/files/live/sites/fbm/files/06-espaces/sciences-infirmieres/20251106_Horaire_Automne_2025.xlsx",
        fileType: .cours
    )
    
    static let semestrePrintemps = DataSource(
        type: .semestre,
        url: "https://www.unil.ch/files/live/sites/fbm/files/06-espaces/sciences-infirmieres/20260330_Horaire_Printemps_2026_2.xlsx",
        fileType: .cours
    )
    
    static let examensAutomne = DataSource(
        type: .examens,
        url: "https://www.unil.ch/files/live/sites/fbm/files/06-espaces/sciences-infirmieres/20251202_Horaire_Examens_A25.xlsx",
        fileType: .examens
    )
    
    static let examensPrintemps = DataSource(
        type: .examens,
        url: "https://www.unil.ch/files/live/sites/fbm/files/06-espaces/sciences-infirmieres/20260421_Horaire_Examens_P26.xlsx",
        fileType: .examens
    )
    
    // Rétrocompatibilité : pointe vers examensAutomne par défaut
    static var examens: DataSource { examensAutomne }
    
    // Obtenir la source automatiquement selon le type et la période courante
    static func automatic(for type: DataSourceType) -> DataSource {
        switch type {
        case .semestre:
            return SemestreType.current() == .printemps ? semestrePrintemps : semestreAutomne
        case .examens:
            return SemestreType.current() == .printemps ? examensPrintemps : examensAutomne
        }
    }
    
    // Générer des URLs candidates pour les examens automne
    static func generateExamenURLCandidates() -> [String] {
        generateExamensAutomneCandidates()
    }
    
    static func generateExamensAutomneCandidates() -> [String] {
        var urls: [String] = []
        let calendar = Calendar.current
        let now = Date()
        
        for daysAgo in 0...90 {
            if let date = calendar.date(byAdding: .day, value: -daysAgo, to: now) {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd"
                let dateString = formatter.string(from: date)
                urls.append("\(baseURL)\(dateString)_Horaire_Examens_A25.xlsx")
            }
        }
        return urls
    }
    
    static func generateExamensPrintempsCandidates() -> [String] {
        var urls: [String] = []
        let calendar = Calendar.current
        let now = Date()
        
        for daysAgo in 0...90 {
            if let date = calendar.date(byAdding: .day, value: -daysAgo, to: now) {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd"
                let dateString = formatter.string(from: date)
                urls.append("\(baseURL)\(dateString)_Horaire_Examens_P26.xlsx")
            }
        }
        return urls
    }
    
    // Générer des URLs candidates pour semestre automne
    static func generateAutomneURLCandidates() -> [String] {
        var urls: [String] = []
        let calendar = Calendar.current
        let now = Date()
        
        for daysAgo in 0...90 {
            if let date = calendar.date(byAdding: .day, value: -daysAgo, to: now) {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd"
                let dateString = formatter.string(from: date)
                urls.append("\(baseURL)\(dateString)_Horaire_Automne_2025.xlsx")
            }
        }
        return urls
    }
    
    // Générer des URLs candidates pour semestre printemps
    static func generatePrintempsURLCandidates() -> [String] {
        var urls: [String] = []
        let calendar = Calendar.current
        let now = Date()
        
        for daysAgo in 0...90 {
            if let date = calendar.date(byAdding: .day, value: -daysAgo, to: now) {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd"
                let dateString = formatter.string(from: date)
                urls.append("\(baseURL)\(dateString)_Horaire_Printemps_2026.xlsx")
            }
        }
        return urls
    }
}

// Gestionnaire d'URLs avec recherche du fichier le plus récent
@MainActor
class DataSourceManager {
    private static let cachedExamenURLKey = "cachedExamenURL"
    private static let cachedAutomneURLKey = "cachedAutomneURL"
    private static let cachedPrintempsURLKey = "cachedPrintempsURL"
    private static let cachedExamensPrintempsURLKey = "cachedExamensPrintempsURL"
    private static let cachedExamenDateKey = "cachedExamenDate"
    private static let cachedAutomneDateKey = "cachedAutomneDate"
    private static let cachedPrintempsDateKey = "cachedPrintempsDate"
    private static let cachedExamensPrintempsDateKey = "cachedExamensPrintempsDate"
    
    // Récupérer l'URL pour le semestre actuel
    static func getMostRecentSemestreURL() async -> String? {
        LogManager.shared.log("📅 Semestre actuel détecté: \(SemestreType.current().rawValue)")
        switch SemestreType.current() {
        case .automne:   return await getMostRecentAutomneURL()
        case .printemps: return await getMostRecentPrintempsURL()
        }
    }
    
    // Récupérer l'URL la plus récente pour les examens (selon la période courante)
    static func getMostRecentExamenURL() async -> String? {
        switch SemestreType.current() {
        case .automne:   return await getMostRecentExamensAutomneURL()
        case .printemps: return await getMostRecentExamensPrintempsURL()
        }
    }
    
    private static func getMostRecentExamensAutomneURL() async -> String? {
        LogManager.shared.log("🔍 Recherche du fichier Examens Automne le plus récent...")
        
        if let cachedURL = UserDefaults.standard.string(forKey: cachedExamenURLKey),
           let cachedDate = UserDefaults.standard.object(forKey: cachedExamenDateKey) as? Date,
           Date().timeIntervalSince(cachedDate) < 6 * 3600 {
            LogManager.shared.log("✅ Utilisation du cache (moins de 6h): \(cachedURL)")
            return cachedURL
        }
        
        let candidates = [DataSource.examensAutomne.url] + DataSource.generateExamensAutomneCandidates()
        return await findMostRecentURL(among: candidates, cacheKey: cachedExamenURLKey, dateCacheKey: cachedExamenDateKey)
    }
    
    private static func getMostRecentExamensPrintempsURL() async -> String? {
        LogManager.shared.log("🔍 Recherche du fichier Examens Printemps le plus récent...")
        
        if let cachedURL = UserDefaults.standard.string(forKey: cachedExamensPrintempsURLKey),
           let cachedDate = UserDefaults.standard.object(forKey: cachedExamensPrintempsDateKey) as? Date,
           Date().timeIntervalSince(cachedDate) < 6 * 3600 {
            LogManager.shared.log("✅ Utilisation du cache (moins de 6h): \(cachedURL)")
            return cachedURL
        }
        
        let candidates = [DataSource.examensPrintemps.url] + DataSource.generateExamensPrintempsCandidates()
        return await findMostRecentURL(among: candidates, cacheKey: cachedExamensPrintempsURLKey, dateCacheKey: cachedExamensPrintempsDateKey)
    }
    
    private static func getMostRecentAutomneURL() async -> String? {
        LogManager.shared.log("🔍 Recherche du fichier Automne le plus récent...")
        
        if let cachedURL = UserDefaults.standard.string(forKey: cachedAutomneURLKey),
           let cachedDate = UserDefaults.standard.object(forKey: cachedAutomneDateKey) as? Date,
           Date().timeIntervalSince(cachedDate) < 6 * 3600 {
            LogManager.shared.log("✅ Utilisation du cache (moins de 6h): \(cachedURL)")
            return cachedURL
        }
        
        let candidates = [DataSource.semestreAutomne.url] + DataSource.generateAutomneURLCandidates()
        return await findMostRecentURL(among: candidates, cacheKey: cachedAutomneURLKey, dateCacheKey: cachedAutomneDateKey)
    }
    
    private static func getMostRecentPrintempsURL() async -> String? {
        LogManager.shared.log("🔍 Recherche du fichier Printemps le plus récent...")
        
        if let cachedURL = UserDefaults.standard.string(forKey: cachedPrintempsURLKey),
           let cachedDate = UserDefaults.standard.object(forKey: cachedPrintempsDateKey) as? Date,
           Date().timeIntervalSince(cachedDate) < 6 * 3600 {
            LogManager.shared.log("✅ Utilisation du cache (moins de 6h): \(cachedURL)")
            return cachedURL
        }
        
        let candidates = [DataSource.semestrePrintemps.url] + DataSource.generatePrintempsURLCandidates()
        return await findMostRecentURL(among: candidates, cacheKey: cachedPrintempsURLKey, dateCacheKey: cachedPrintempsDateKey)
    }
    
    // Factorisation : cherche l'URL la plus récente parmi une liste de candidats
    private static func findMostRecentURL(among candidates: [String], cacheKey: String, dateCacheKey: String) async -> String? {
        var mostRecentURL: String?
        var mostRecentDate: Date?
        
        LogManager.shared.log("🔎 Test de \(min(candidates.count, 30)) URLs candidates...")
        
        for (index, candidateURL) in candidates.prefix(30).enumerated() {
            if let lastModified = await getLastModifiedDate(candidateURL) {
                LogManager.shared.log("  [\(index)] ✅ \(candidateURL.components(separatedBy: "/").last ?? "") - \(formatDate(lastModified))")
                if mostRecentDate == nil || lastModified > mostRecentDate! {
                    mostRecentDate = lastModified
                    mostRecentURL = candidateURL
                }
            }
        }
        
        if let finalURL = mostRecentURL, let finalDate = mostRecentDate {
            LogManager.shared.log("🎯 Fichier le plus récent: \(finalURL.components(separatedBy: "/").last ?? "")")
            LogManager.shared.log("📅 Date de modification: \(formatDate(finalDate))")
            UserDefaults.standard.set(finalURL, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: dateCacheKey)
            return finalURL
        }
        
        LogManager.shared.log("❌ Aucun fichier valide trouvé")
        return nil
    }
    
    private static func getLastModifiedDate(_ urlString: String) async -> Date? {
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
                  contentType.contains("spreadsheet") else {
                return nil
            }
            
            if let lastModifiedString = httpResponse.value(forHTTPHeaderField: "Last-Modified") {
                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
                dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
                return dateFormatter.date(from: lastModifiedString)
            }
            return nil
        } catch {
            return nil
        }
    }
    
    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: date)
    }
    
    static func clearCache() {
        UserDefaults.standard.removeObject(forKey: cachedExamenURLKey)
        UserDefaults.standard.removeObject(forKey: cachedAutomneURLKey)
        UserDefaults.standard.removeObject(forKey: cachedPrintempsURLKey)
        UserDefaults.standard.removeObject(forKey: cachedExamensPrintempsURLKey)
        UserDefaults.standard.removeObject(forKey: cachedExamenDateKey)
        UserDefaults.standard.removeObject(forKey: cachedAutomneDateKey)
        UserDefaults.standard.removeObject(forKey: cachedPrintempsDateKey)
        UserDefaults.standard.removeObject(forKey: cachedExamensPrintempsDateKey)
        LogManager.shared.log("🗑️ Cache d'URLs vidé")
    }
}
