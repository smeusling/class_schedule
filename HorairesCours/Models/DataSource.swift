// Models/DataSource.swift

import Foundation

enum DataSourceType: String, Codable, CaseIterable {
    case semestreAutomne = "Semestre Automne"
    case examens = "Examens"
    case customURL = "URL Personnalisée"
}

enum FileType: String, Codable {
    case cours = "Horaire de cours"
    case examens = "Horaire d'examens"
}

struct DataSource: Codable {
    let type: DataSourceType
    let url: String
    let fileType: FileType
    
    private static let baseURL = "https://www.unil.ch/files/live/sites/fbm/files/06-espaces/sciences-infirmieres/"
    
    static let semestreAutomne = DataSource(
        type: .semestreAutomne,
        url: "https://www.unil.ch/files/live/sites/fbm/files/06-espaces/sciences-infirmieres/20251106_Horaire_Automne_2025.xlsx",
        fileType: .cours
    )
    
    static let examens = DataSource(
        type: .examens,
        url: "https://www.unil.ch/files/live/sites/fbm/files/06-espaces/sciences-infirmieres/20251202_Horaire_Examens_A25.xlsx",
        fileType: .examens
    )
    
    // Générer des URLs candidates pour les examens
    static func generateExamenURLCandidates() -> [String] {
        var urls: [String] = []
        let calendar = Calendar.current
        let now = Date()
        
        // Essayer les 90 derniers jours
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
    
    // Générer des URLs candidates pour les cours
    static func generateCoursURLCandidates() -> [String] {
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
}

// Gestionnaire d'URLs avec recherche du fichier le plus récent
@MainActor
class DataSourceManager {
    private static let cachedExamenURLKey = "cachedExamenURL"
    private static let cachedCoursURLKey = "cachedCoursURL"
    private static let cachedExamenDateKey = "cachedExamenDate"
    private static let cachedCoursDateKey = "cachedCoursDate"
    
    // Récupérer l'URL la plus récente pour les examens
    static func getMostRecentExamenURL() async -> String? {
        print("🔍 Recherche du fichier d'examens le plus récent...")
        
        // 1️⃣ Vérifier le cache et sa fraîcheur
        if let cachedURL = UserDefaults.standard.string(forKey: cachedExamenURLKey),
           let cachedDate = UserDefaults.standard.object(forKey: cachedExamenDateKey) as? Date {
            
            // Si le cache a moins de 6 heures, l'utiliser
            if Date().timeIntervalSince(cachedDate) < 6 * 3600 {
                print("✅ Utilisation du cache (moins de 6h): \(cachedURL)")
                return cachedURL
            }
        }
        
        // 2️⃣ Rechercher le fichier le plus récent
        let candidates = [DataSource.examens.url] + DataSource.generateExamenURLCandidates()
        var mostRecentURL: String?
        var mostRecentDate: Date?
        
        print("🔍 Test de \(min(candidates.count, 30)) URLs candidates...")
        
        // Tester les 30 premières URLs (optimisation)
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
            
            // Mettre en cache
            UserDefaults.standard.set(finalURL, forKey: cachedExamenURLKey)
            UserDefaults.standard.set(Date(), forKey: cachedExamenDateKey)
            
            return finalURL
        }
        
        print("❌ Aucun fichier valide trouvé")
        return nil
    }
    
    // Récupérer l'URL la plus récente pour les cours
    static func getMostRecentCoursURL() async -> String? {
        print("🔍 Recherche du fichier de cours le plus récent...")
        
        if let cachedURL = UserDefaults.standard.string(forKey: cachedCoursURLKey),
           let cachedDate = UserDefaults.standard.object(forKey: cachedCoursDateKey) as? Date {
            
            if Date().timeIntervalSince(cachedDate) < 6 * 3600 {
                print("✅ Utilisation du cache (moins de 6h): \(cachedURL)")
                return cachedURL
            }
        }
        
        let candidates = [DataSource.semestreAutomne.url] + DataSource.generateCoursURLCandidates()
        var mostRecentURL: String?
        var mostRecentDate: Date?
        
        print("🔍 Test de \(min(candidates.count, 30)) URLs candidates...")
        
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
            
            UserDefaults.standard.set(finalURL, forKey: cachedCoursURLKey)
            UserDefaults.standard.set(Date(), forKey: cachedCoursDateKey)
            
            return finalURL
        }
        
        print("❌ Aucun fichier valide trouvé")
        return nil
    }
    
    // Obtenir la date Last-Modified d'une URL
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
    
    // Formater une date pour l'affichage
    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: date)
    }
    
    // Forcer le rafraîchissement du cache
    static func clearCache() {
        UserDefaults.standard.removeObject(forKey: cachedExamenURLKey)
        UserDefaults.standard.removeObject(forKey: cachedCoursURLKey)
        UserDefaults.standard.removeObject(forKey: cachedExamenDateKey)
        UserDefaults.standard.removeObject(forKey: cachedCoursDateKey)
        print("🗑️ Cache d'URLs vidé")
    }
}
