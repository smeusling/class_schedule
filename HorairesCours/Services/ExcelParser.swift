// Services/ExcelParser.swift

import Foundation
import CoreXLSX

class ExcelParser {
    
    // Extraire uniquement les volées uniques (sans Temps Plein/Partiel)
    static func extractVolees(_ data: Data) throws -> [String] {
        guard let xlsx = try? XLSXFile(data: data) else {
            throw NSError(domain: "ExcelParsingError", code: -1)
        }
        
        var voleesSet = Set<String>()
        let workbooks = try xlsx.parseWorkbooks()
        
        guard let firstWorkbook = workbooks.first else { return [] }
        
        let worksheetPaths = try xlsx.parseWorksheetPathsAndNames(workbook: firstWorkbook)
        
        // Chercher l'onglet "Menu déroulant"
        guard let menuPath = worksheetPaths.first(where: {
            $0.name!.lowercased().contains("menu") ||
            $0.name!.lowercased().contains("déroulant") ||
            $0.name!.lowercased().contains("deroulant")
        })?.path else {
            print("⚠️ Onglet 'Menu déroulant' non trouvé")
            return []
        }
        
        print("✅ Onglet trouvé: \(worksheetPaths.first(where: { $0.path == menuPath })?.name ?? "")")
        
        let worksheet = try xlsx.parseWorksheet(at: menuPath)
        let rows = worksheet.data?.rows ?? []
        let sharedStrings = try? xlsx.parseSharedStrings()
        
        // La colonne A contient "Volée" (en-tête), puis la liste des cursus
        for (index, row) in rows.enumerated() {
            if index == 0 { continue } // Skip l'en-tête "Volée"
            
            let cells = row.cells
            if let volee = getCellValueOptimized(cells, at: 0, sharedStrings: sharedStrings), !volee.isEmpty {
                // Nettoyer : enlever "Temps Plein", "Temps partiel", "Partiel", "Plein", "Tous"
                var cleanedVolee = volee
                    .replacingOccurrences(of: " Temps plein", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: " Temps Plein", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: " Temps partiel", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: " Temps Partiel", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: " Partiel", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: " Plein", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: " Tous", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Gérer les cursus multiples séparés par "/"
                let parts = cleanedVolee.components(separatedBy: "/")
                for part in parts {
                    let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty && !trimmed.lowercased().contains("volée") {
                        voleesSet.insert(trimmed)
                        print("🎓 Volée trouvée: '\(trimmed)'")
                    }
                }
            }
        }
        
        let sortedVolees = Array(voleesSet).sorted()
        print("✅ Total volées extraites: \(sortedVolees.count)")
        
        return sortedVolees
    }
    
    // Parser avec filtre de volée ET modalités
    static func parse(_ data: Data, selectedVolee: String?, modalites: [Modalite]) throws -> [CourseSchedule] {
        guard let xlsx = try? XLSXFile(data: data) else {
            throw NSError(domain: "ExcelParsingError", code: -1)
        }
        
        var scheduleItems: [CourseSchedule] = []
        let colors = ScheduleColor.allCases
        var colorIndex = 0
        
        guard let firstWorkbook = try xlsx.parseWorkbooks().first else { return [] }
        
        let worksheetPaths = try xlsx.parseWorksheetPathsAndNames(workbook: firstWorkbook)
        
        guard let horairePath = worksheetPaths.first(where: { $0.name!.lowercased().contains("horaire") })?.path
              ?? worksheetPaths.first?.path else { return [] }
        
        let worksheet = try xlsx.parseWorksheet(at: horairePath)
        let sharedStrings = try? xlsx.parseSharedStrings()
        
        scheduleItems = parseWorksheet(worksheet, sharedStrings: sharedStrings, colors: colors, colorIndex: &colorIndex, selectedVolee: selectedVolee, modalites: modalites)
        
        return scheduleItems.sorted { $0.date < $1.date }
    }
    
    private static func parseWorksheet(_ worksheet: Worksheet, sharedStrings: SharedStrings?, colors: [ScheduleColor], colorIndex: inout Int, selectedVolee: String?, modalites: [Modalite]) -> [CourseSchedule] {
        var scheduleItems: [CourseSchedule] = []
        let rows = worksheet.data?.rows ?? []
        
        print("📊 Parsing \(rows.count) lignes...")
        
        for (index, row) in rows.enumerated() {
            if index < 2 { continue }
            
            let cells = row.cells
            
            let dateStr = getCellValueOptimized(cells, at: 1, sharedStrings: sharedStrings) ?? ""
            let heureDebut = getCellValueOptimized(cells, at: 2, sharedStrings: sharedStrings) ?? ""
            let heureFin = getCellValueOptimized(cells, at: 3, sharedStrings: sharedStrings) ?? ""
            let cours = getCellValueOptimized(cells, at: 5, sharedStrings: sharedStrings) ?? ""
            let cursus = getCellValueOptimized(cells, at: 7, sharedStrings: sharedStrings) ?? ""
            let enseignant = getCellValueOptimized(cells, at: 9, sharedStrings: sharedStrings) ?? ""
            let salle = getCellValueOptimized(cells, at: 10, sharedStrings: sharedStrings) ?? ""
            
            // Filtrer par volée ET modalités
            if let selectedVolee = selectedVolee {
                if !matchesVoleeAndModalites(cursus: cursus, selectedVolee: selectedVolee, modalites: modalites) {
                    continue
                }
            }
            
            guard !cours.isEmpty else { continue }
            guard let date = parseDate(dateStr) else { continue }
            
            let heureComplete = formatHeure(debut: heureDebut, fin: heureFin)
            
            let schedule = CourseSchedule(
                date: date,
                heure: heureComplete,
                cours: cours,
                salle: salle,
                enseignant: enseignant,
                duration: extractDuration(debut: heureDebut, fin: heureFin),
                color: colors[colorIndex % colors.count]
            )
            scheduleItems.append(schedule)
            colorIndex += 1
        }
        
        print("✅ Total schedules créés: \(scheduleItems.count)")
        return scheduleItems
    }
    
    // Nouvelle fonction de matching avec volée + modalités
    private static func matchesVoleeAndModalites(cursus: String, selectedVolee: String, modalites: [Modalite]) -> Bool {
        let cleanCursus = cursus.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSelected = selectedVolee.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        if cleanCursus.isEmpty {
            return true
        }
        
        // Séparer les cursus multiples
        let cursusList = cleanCursus.components(separatedBy: "/").map { $0.trimmingCharacters(in: .whitespaces) }
        
        for singleCursus in cursusList {
            let lowercaseCursus = singleCursus.lowercased()
            
            // Vérifier si la volée correspond
            if !lowercaseCursus.contains(cleanSelected) {
                continue
            }
            
            // Si les deux modalités sont cochées OU si "Tous" est présent
            if modalites.count == 2 || lowercaseCursus.contains("tous") {
                return true
            }
            
            // Vérifier les modalités spécifiques
            for modalite in modalites {
                switch modalite {
                case .tempsPlein:
                    if lowercaseCursus.contains("temps plein") || lowercaseCursus.contains("plein") {
                        return true
                    }
                case .partiel:
                    if lowercaseCursus.contains("partiel") {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    private static func getCellValueOptimized(_ cells: [Cell], at index: Int, sharedStrings: SharedStrings?) -> String? {
        guard index < cells.count else { return nil }
        let cell = cells[index]
        
        if let sharedStrings = sharedStrings,
           let stringValue = cell.stringValue(sharedStrings) {
            return stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        if let value = cell.value {
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return nil
    }
    
    private static func parseDate(_ dateString: String) -> Date? {
        // Vérifier si c'est un serial number Excel (un nombre)
        if let serialNumber = Double(dateString) {
            // Excel compte les jours depuis le 1er janvier 1900
            let excelEpoch = Date(timeIntervalSince1970: -2209161600) // 1er janvier 1900
            let daysToAdd = serialNumber - 2 // -2 pour corriger le bug Excel
            
            if let date = Calendar.current.date(byAdding: .day, value: Int(daysToAdd), to: excelEpoch) {
                return date
            }
        }
        
        // Sinon, parser comme format texte normal (DD/MM/YYYY, DD.MM.YYYY, etc.)
        let components = dateString.split(whereSeparator: { $0 == "/" || $0 == "." || $0 == "-" })
        guard components.count >= 3 else { return nil }
        
        let first = Int(components[0]) ?? 0
        let second = Int(components[1]) ?? 0
        let third = Int(components[2]) ?? 0
        
        var month: Int
        var day: Int
        var year: Int
        
        if first > 12 {
            day = first
            month = second
            year = third
        } else if second > 12 {
            month = first
            day = second
            year = third
        } else {
            month = first
            day = second
            year = third
        }
        
        if year < 100 {
            year += 2000
        }
        
        var dateComponents = DateComponents()
        dateComponents.day = day
        dateComponents.month = month
        dateComponents.year = year
        
        return Calendar.current.date(from: dateComponents)
    }
    
    private static func formatHeure(debut: String, fin: String) -> String {
        let debutFormatted = formatSingleHeure(debut)
        let finFormatted = formatSingleHeure(fin)
        return "\(debutFormatted) - \(finFormatted)"
    }
    
    private static func formatSingleHeure(_ heure: String) -> String {
        let cleaned = heure.replacingOccurrences(of: ".", with: ":")
        let components = cleaned.split(separator: ":")
        
        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            return heure
        }
        
        return String(format: "%02d:%02d", hour, minute)
    }
    
    private static func extractDuration(debut: String, fin: String) -> String {
        let debutComponents = debut.split(separator: ".")
        let finComponents = fin.split(separator: ".")
        
        guard debutComponents.count >= 1, finComponents.count >= 1,
              let startHour = Int(debutComponents[0]),
              let endHour = Int(finComponents[0]) else {
            return ""
        }
        
        let startMinute = debutComponents.count > 1 ? Int(debutComponents[1]) ?? 0 : 0
        let endMinute = finComponents.count > 1 ? Int(finComponents[1]) ?? 0 : 0
        
        var totalMinutes = (endHour * 60 + endMinute) - (startHour * 60 + startMinute)
        
        if totalMinutes < 0 {
            totalMinutes += 24 * 60
        }
        
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 && minutes > 0 {
            return "\(hours)h\(minutes)min"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)min"
        }
    }
}
