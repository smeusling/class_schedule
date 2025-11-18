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
        
        var consecutiveNonVoleeCount = 0
        
        // Lire uniquement la colonne A (Volée)
        for (index, row) in rows.enumerated() {
            if index == 0 { continue } // Skip l'en-tête "Volée"
            
            let cells = row.cells
            guard let volee = getCellValueOptimized(cells, at: 0, sharedStrings: sharedStrings), !volee.isEmpty else {
                continue
            }
            
            // Nettoyer : enlever "Temps Plein", "Temps partiel", "Partiel", "Plein", "Tous"
            var cleanedVolee = volee
                .replacingOccurrences(of: " Temps plein", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " Temps Plein", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " Temps partiel", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " Temps Partiel", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " Partiel", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " Plein", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " Tous", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " (8 semestres)", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Vérifier si c'est une vraie volée (commence par ICLS, IPS, MScIPS, ou Etudiants)
            let lowercased = cleanedVolee.lowercased()
            let startsWithValidPrefix = lowercased.hasPrefix("icls") ||
                                       lowercased.hasPrefix("ips") ||
                                       lowercased.hasPrefix("mscips") ||
                                       lowercased.hasPrefix("etudiants")
            
            // Si ce n'est pas une volée, on compte
            if !startsWithValidPrefix {
                consecutiveNonVoleeCount += 1
                // Si on a 3 lignes consécutives qui ne sont pas des volées, on arrête
                if consecutiveNonVoleeCount >= 3 {
                    print("🛑 Arrêt de la lecture - fin de la section des volées")
                    break
                }
                continue
            }
            
            // Réinitialiser le compteur si on trouve une volée
            consecutiveNonVoleeCount = 0
            
            // Gérer les cursus multiples séparés par "/"
            let parts = cleanedVolee.components(separatedBy: "/")
            for part in parts {
                let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
                let partLowercased = trimmed.lowercased()
                
                // Vérifier que cette partie est aussi une vraie volée
                let partIsValid = partLowercased.hasPrefix("icls") ||
                                partLowercased.hasPrefix("ips") ||
                                partLowercased.hasPrefix("mscips") ||
                                partLowercased.hasPrefix("etudiants")
                
                if partIsValid && trimmed.count >= 3 {
                    // Nettoyer les préfixes de chiffres seuls (comme "7 IPS 7-24" -> "IPS 7-24")
                    var finalTrimmed = trimmed
                    
                    let components = trimmed.components(separatedBy: " ")
                    if components.count > 1, let firstComponent = components.first, firstComponent.allSatisfy({ $0.isNumber }) {
                        finalTrimmed = components.dropFirst().joined(separator: " ")
                    }
                    
                    voleesSet.insert(finalTrimmed)
                    print("🎓 Volée trouvée: '\(finalTrimmed)'")
                }
            }
        }
        
        let sortedVolees = Array(voleesSet).sorted()
        print("✅ Total volées extraites: \(sortedVolees.count)")
        print("📋 Liste finale: \(sortedVolees)")
        
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
            
            // ✅ LIRE LA DATE DIFFÉREMMENT
            let dateStr = getDateCellValue(cells, at: 1, sharedStrings: sharedStrings) ?? ""
            
            let heureDebut = getCellValueOptimized(cells, at: 2, sharedStrings: sharedStrings) ?? ""
            let heureFin = getCellValueOptimized(cells, at: 3, sharedStrings: sharedStrings) ?? ""
            let cours = getCellValueOptimized(cells, at: 5, sharedStrings: sharedStrings) ?? ""
            let cursus = getCellValueOptimized(cells, at: 7, sharedStrings: sharedStrings) ?? ""
            let enseignant = getCellValueOptimized(cells, at: 9, sharedStrings: sharedStrings) ?? ""
            let salle = getCellValueOptimized(cells, at: 10, sharedStrings: sharedStrings) ?? ""
            
            // Filtrer par volée ET modalités
            if let selectedVolee = selectedVolee {
                if !matchesVoleeAndModalites(cursus: cursus, selectedVolee: selectedVolee, modalites: modalites) {
                    print("❌ Ligne \(index): Cours '\(cours)' REJETÉ - Cursus: '\(cursus)' ne correspond pas à '\(selectedVolee)' avec modalités: \(modalites.map { $0.rawValue })")
                    continue
                } else {
                    print("✅ Ligne \(index): Cours '\(cours)' ACCEPTÉ - Cursus: '\(cursus)'")
                }
            }
            
            guard !cours.isEmpty else { continue }
            guard let date = parseDate(dateStr) else {
                print("⚠️ Ligne \(index): Date invalide '\(dateStr)'")
                continue
            }
            
            let formatter = DateFormatter()
            formatter.dateFormat = "dd/MM/yyyy"
            print("✅ Ligne \(index): Date Excel '\(dateStr)' -> Date parsée: \(formatter.string(from: date)) | Cours: '\(cours)'")
            
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

    // ✅ NOUVELLE FONCTION pour lire spécifiquement les cellules de date
    private static func getDateCellValue(_ cells: [Cell], at index: Int, sharedStrings: SharedStrings?) -> String? {
        guard index < cells.count else { return nil }
        let cell = cells[index]
        
        // Essayer de lire depuis les shared strings d'abord
        if let sharedStrings = sharedStrings,
           let stringValue = cell.stringValue(sharedStrings) {
            return stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Si la cellule a une valeur de type "inline string"
        if let inlineString = cell.inlineString {
            return inlineString.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Sinon, si c'est un nombre (serial date), on le retourne tel quel
        if let value = cell.value {
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return nil
    }
    
    // Nouvelle fonction de matching avec volée + modalités
    private static func matchesVoleeAndModalites(cursus: String, selectedVolee: String, modalites: [Modalite]) -> Bool {
        let cleanCursus = cursus.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSelected = selectedVolee.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // ⚠️ Si le cursus est vide, on ne peut pas savoir à qui appartient ce cours
        // On le rejette pour éviter d'afficher des cours qui ne concernent pas l'utilisateur
        if cleanCursus.isEmpty {
            print("⚠️ Cours sans cursus spécifié - REJETÉ")
            return false
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
            // Excel a un bug historique : il considère 1900 comme bissextile (ce qui est faux)
            // Donc pour les dates après le 28 février 1900, il faut soustraire 1 jour
            
            // Utilisons la méthode standard : epoch Excel = 1er janvier 1900
            let referenceDate = DateComponents(calendar: Calendar.current, year: 1899, month: 12, day: 30)
            guard let excelEpoch = Calendar.current.date(from: referenceDate) else { return nil }
            
            let daysToAdd = Int(serialNumber)
            
            if let date = Calendar.current.date(byAdding: .day, value: daysToAdd, to: excelEpoch) {
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

        // Extraire la date de mise à jour depuis l'en-tête du fichier Excel
        static func extractUpdateDate(_ data: Data) -> Date? {
            guard let xlsx = try? XLSXFile(data: data) else {
                return nil
            }
            
            do {
                guard let firstWorkbook = try xlsx.parseWorkbooks().first else { return nil }
                let worksheetPaths = try xlsx.parseWorksheetPathsAndNames(workbook: firstWorkbook)
                
                guard let horairePath = worksheetPaths.first(where: { $0.name!.lowercased().contains("horaire") })?.path
                      ?? worksheetPaths.first?.path else { return nil }
                
                let worksheet = try xlsx.parseWorksheet(at: horairePath)
                let sharedStrings = try? xlsx.parseSharedStrings()
                let rows = worksheet.data?.rows ?? []
                
                // Chercher dans la première ligne (row 0) la date
                if let firstRow = rows.first {
                    let cells = firstRow.cells
                    
                    // Essayer de lire toutes les cellules de la première ligne
                    for (index, cell) in cells.enumerated() {
                        if let value = getCellValueOptimized(cells, at: index, sharedStrings: sharedStrings),
                           !value.isEmpty {
                            
                            print("📋 Cellule \(index) de la première ligne: '\(value)'")
                            
                            // Vérifier si c'est une date (format "Automne 2025 - 06.11.2025")
                            if value.contains("2025") || value.contains("2024") {
                                print("📅 Titre trouvé dans Excel: '\(value)'")
                                
                                // Extraire la date du format "Automne 2025 - 06.11.2025" ou "DD.MM.YYYY"
                                if let dateMatch = value.range(of: "\\d{2}\\.\\d{2}\\.\\d{4}", options: .regularExpression) {
                                    let dateStr = String(value[dateMatch])
                                    print("📅 Date extraite: '\(dateStr)'")
                                    
                                    // Parser la date (format DD.MM.YYYY)
                                    let formatter = DateFormatter()
                                    formatter.dateFormat = "dd.MM.yyyy"
                                    if let date = formatter.date(from: dateStr) {
                                        print("✅ Date parsée avec succès: \(date)")
                                        return date
                                    }
                                }
                            }
                        }
                    }
                }
                
                print("⚠️ Aucune date trouvée dans l'en-tête Excel")
                return nil
                
            } catch {
                print("❌ Erreur lors de l'extraction de la date: \(error)")
                return nil
            }
        }
    }

