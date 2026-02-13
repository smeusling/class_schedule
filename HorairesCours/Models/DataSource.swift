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
    
    // ✅ NOUVEAU : Détecter automatiquement le semestre selon la date
    static func current() -> SemestreType {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: Date())
        
        // Janvier à Août = Printemps
        // Septembre à Décembre = Automne
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
        url: "https://www.unil.ch/files/live/sites/fbm/files/06-espaces/sciences-infirmieres/20261901_Horaire_Printemps_2026.xlsx",
        fileType: .cours
    )
    
    static let examens = DataSource(
        type: .examens,
        url: "https://www.unil.ch/files/live/sites/fbm/files/06-espaces/sciences-infirmieres/20251202_Horaire_Examens_A25.xlsx",
        fileType: .examens
    )
    
    // ✅ NOUVEAU : Obtenir la source automatiquement selon le type
    static func automatic(for type: DataSourceType) -> DataSource {
        switch type {
        case .semestre:
            let currentSemestre = SemestreType.current()
            return currentSemestre == .printemps ? semestrePrintemps : semestreAutomne
        case .examens:
            return examens
        }
    }
    
    // Générer des URLs candidates pour les examens
    static func generateExamenURLCandidates() -> [String] {
        var urls: [String] = []
        let calendar = Calendar.current
        let now = Date()
        
        for daysAgo in 0...90 {
            if let date = calendar.date(byAdding: .day, value: -daysAgo, to: now) {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd"
                let dateString = formatter.string(from: date)
                
                urls.append("\(baseURL)\(dateString)_Horaire_Examens_A25.xlsx")
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
    private static let cachedExamenDateKey = "cachedExamenDate"
    private static let cachedAutomneDateKey = "cachedAutomneDate"
    private static let cachedPrintempsDateKey = "cachedPrintempsDate"
    
    // ✅ NOUVEAU : Récupérer l'URL pour le semestre actuel
    static func getMostRecentSemestreURL() async -> String? {
        let currentSemestre = SemestreType.current()
        print("📅 Semestre actuel détecté: \(currentSemestre.rawValue)")
        
        switch currentSemestre {
        case .automne:
            return await getMostRecentAutomneURL()
        case .printemps:
            return await getMostRecentPrintempsURL()
        }
    }
    
    // Récupérer l'URL la plus récente pour les examens
    static func getMostRecentExamenURL() async -> String? {
        print("🔍 Recherche du fichier d'examens le plus récent...")
        
        if let cachedURL = UserDefaults.standard.string(forKey: cachedExamenURLKey),
           let cachedDate = UserDefaults.standard.object(forKey: cachedExamenDateKey) as? Date {
            
            if Date().timeIntervalSince(cachedDate) < 6 * 3600 {
                print("✅ Utilisation du cache (moins de 6h): \(cachedURL)")
                return cachedURL
            }
        }
        
        let candidates = [DataSource.examens.url] + DataSource.generateExamenURLCandidates()
        var mostRecentURL: String?
        var mostRecentDate: Date?
        
        print("🔎 Test de \(min(candidates.count, 30)) URLs candidates...")
        
        for (index, candidateURL) in candidates.prefix(30).enumerated() {
            if let lastModified = await getLastModifiedDate(candidateURL) {
                print("  [\(index)] ✅ \(candidateURL.components(separatedBy: "/").last ?? "") - \(formatDate(lastModified))")
                
                if mostRecentDate == nil || lastModified > mostRecentDate! {
                    mostRecentDate = lastModified
                    mostRecentURL = candidateURL
                }
            }
        }
        
        if let finalURL = mostRecentURL, let finalDate = mostRecentDate {
            print("🎯 Fichier le plus récent: \(finalURL.components(separatedBy: "/").last ?? "")")
            print("📅 Date de modification: \(formatDate(finalDate))")
            
            UserDefaults.standard.set(finalURL, forKey: cachedExamenURLKey)
            UserDefaults.standard.set(Date(), forKey: cachedExamenDateKey)
            
            return finalURL
        }
        
        print("❌ Aucun fichier valide trouvé")
        return nil
    }
    
    private static func getMostRecentAutomneURL() async -> String? {
        print("🔍 Recherche du fichier Automne le plus récent...")
        
        if let cachedURL = UserDefaults.standard.string(forKey: cachedAutomneURLKey),
           let cachedDate = UserDefaults.standard.object(forKey: cachedAutomneDateKey) as? Date {
            
            if Date().timeIntervalSince(cachedDate) < 6 * 3600 {
                print("✅ Utilisation du cache (moins de 6h): \(cachedURL)")
                return cachedURL
            }
        }
        
        let candidates = [DataSource.semestreAutomne.url] + DataSource.generateAutomneURLCandidates()
        var mostRecentURL: String?
        var mostRecentDate: Date?
        
        print("🔎 Test de \(min(candidates.count, 30)) URLs candidates...")
        
        for (index, candidateURL) in candidates.prefix(30).enumerated() {
            if let lastModified = await getLastModifiedDate(candidateURL) {
                print("  [\(index)] ✅ \(candidateURL.components(separatedBy: "/").last ?? "") - \(formatDate(lastModified))")
                
                if mostRecentDate == nil || lastModified > mostRecentDate! {
                    mostRecentDate = lastModified
                    mostRecentURL = candidateURL
                }
            }
        }
        
        if let finalURL = mostRecentURL, let finalDate = mostRecentDate {
            print("🎯 Fichier le plus récent: \(finalURL.components(separatedBy: "/").last ?? "")")
            print("📅 Date de modification: \(formatDate(finalDate))")
            
            UserDefaults.standard.set(finalURL, forKey: cachedAutomneURLKey)
            UserDefaults.standard.set(Date(), forKey: cachedAutomneDateKey)
            
            return finalURL
        }
        
        print("❌ Aucun fichier valide trouvé")
        return nil
    }
    
    private static func getMostRecentPrintempsURL() async -> String? {
        print("🔍 Recherche du fichier Printemps le plus récent...")
        
        if let cachedURL = UserDefaults.standard.string(forKey: cachedPrintempsURLKey),
           let cachedDate = UserDefaults.standard.object(forKey: cachedPrintempsDateKey) as? Date {
            
            if Date().timeIntervalSince(cachedDate) < 6 * 3600 {
                print("✅ Utilisation du cache (moins de 6h): \(cachedURL)")
                return cachedURL
            }
        }
        
        let candidates = [DataSource.semestrePrintemps.url] + DataSource.generatePrintempsURLCandidates()
        var mostRecentURL: String?
        var mostRecentDate: Date?
        
        print("🔎 Test de \(min(candidates.count, 30)) URLs candidates...")
        
        for (index, candidateURL) in candidates.prefix(30).enumerated() {
            if let lastModified = await getLastModifiedDate(candidateURL) {
                print("  [\(index)] ✅ \(candidateURL.components(separatedBy: "/").last ?? "") - \(formatDate(lastModified))")
                
                if mostRecentDate == nil || lastModified > mostRecentDate! {
                    mostRecentDate = lastModified
                    mostRecentURL = candidateURL
                }
            }
        }
        
        if let finalURL = mostRecentURL, let finalDate = mostRecentDate {
            print("🎯 Fichier le plus récent: \(finalURL.components(separatedBy: "/").last ?? "")")
            print("📅 Date de modification: \(formatDate(finalDate))")
            
            UserDefaults.standard.set(finalURL, forKey: cachedPrintempsURLKey)
            UserDefaults.standard.set(Date(), forKey: cachedPrintempsDateKey)
            
            return finalURL
        }
        
        print("❌ Aucun fichier valide trouvé")
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
        UserDefaults.standard.removeObject(forKey: cachedExamenDateKey)
        UserDefaults.standard.removeObject(forKey: cachedAutomneDateKey)
        UserDefaults.standard.removeObject(forKey: cachedPrintempsDateKey)
        print("🗑️ Cache d'URLs vidé")
    }
}
