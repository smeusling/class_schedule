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
    
    // Parser avec filtre de volée ET modalités ET type de fichier
    static func parse(_ data: Data, selectedVolee: String?, modalites: [Modalite], fileType: FileType) throws -> [CourseSchedule] {
        switch fileType {
        case .cours:
            return try parseCoursSchedule(data, selectedVolee: selectedVolee, modalites: modalites)
        case .examens:
            return try parseExamensSchedule(data, selectedVolee: selectedVolee, modalites: modalites)
        }
    }
    
    // Parser pour les horaires de cours
    private static func parseCoursSchedule(_ data: Data, selectedVolee: String?, modalites: [Modalite]) throws -> [CourseSchedule] {
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
        
        scheduleItems = parseCoursWorksheet(worksheet, sharedStrings: sharedStrings, colors: colors, colorIndex: &colorIndex, selectedVolee: selectedVolee, modalites: modalites)
        
        return scheduleItems.sorted { $0.date < $1.date }
    }
    
    // NOUVEAU : Parser pour les horaires d'examens
    private static func parseExamensSchedule(_ data: Data, selectedVolee: String?, modalites: [Modalite]) throws -> [CourseSchedule] {
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
        
        scheduleItems = parseExamensWorksheet(worksheet, sharedStrings: sharedStrings, colors: colors, colorIndex: &colorIndex, selectedVolee: selectedVolee, modalites: modalites)
        
        return scheduleItems.sorted { $0.date < $1.date }
    }

    private static func parseCoursWorksheet(_ worksheet: Worksheet, sharedStrings: SharedStrings?, colors: [ScheduleColor], colorIndex: inout Int, selectedVolee: String?, modalites: [Modalite]) -> [CourseSchedule] {
        var scheduleItems: [CourseSchedule] = []
        let rows = worksheet.data?.rows ?? []
        
        print("📊 Parsing \(rows.count) lignes...")
        
        for (index, row) in rows.enumerated() {
            if index < 2 { continue }
            
            let cells = row.cells
            
            let dateStr = getDateCellValue(cells, at: 1, sharedStrings: sharedStrings) ?? ""
            let heureDebut = getCellValueOptimized(cells, at: 2, sharedStrings: sharedStrings) ?? ""
            let heureFin = getCellValueOptimized(cells, at: 3, sharedStrings: sharedStrings) ?? ""
            let nombrePeriode = getCellValueOptimized(cells, at: 4, sharedStrings: sharedStrings) ?? ""
            let cours = getCellValueOptimized(cells, at: 5, sharedStrings: sharedStrings) ?? ""
            let contenuCours = getCellValueOptimized(cells, at: 6, sharedStrings: sharedStrings) ?? ""
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
                color: colors[colorIndex % colors.count],
                contenuCours: contenuCours,
                nombrePeriode: nombrePeriode
            )
            scheduleItems.append(schedule)
            colorIndex += 1
        }
        
        print("✅ Total schedules créés: \(scheduleItems.count)")
        return scheduleItems
    }
    
    private static func parseExamensWorksheet(_ worksheet: Worksheet, sharedStrings: SharedStrings?, colors: [ScheduleColor], colorIndex: inout Int, selectedVolee: String?, modalites: [Modalite]) -> [CourseSchedule] {
        var scheduleItems: [CourseSchedule] = []
        let rows = worksheet.data?.rows ?? []
        
        print("📊 Parsing examens - \(rows.count) lignes...")
        
        // DEUXIÈME PASSE : Parser les examens
        for (index, row) in rows.enumerated() {
            if index < 3 { continue }
            
            let cells = row.cells
            
            let jour = getCellValueOptimized(cells, at: 0, sharedStrings: sharedStrings) ?? ""
            let dateStr = getDateCellValue(cells, at: 1, sharedStrings: sharedStrings) ?? ""
            let arriveeControle = getCellValueOptimized(cells, at: 2, sharedStrings: sharedStrings) ?? ""
            let heureDebut = getCellValueOptimized(cells, at: 3, sharedStrings: sharedStrings) ?? ""
            let heureFin = getCellValueOptimized(cells, at: 4, sharedStrings: sharedStrings) ?? ""
            let coursRaw = getCellValueOptimized(cells, at: 5, sharedStrings: sharedStrings) ?? ""
            let modalite = getCellValueOptimized(cells, at: 6, sharedStrings: sharedStrings) ?? ""
            let anonymisation = getCellValueOptimized(cells, at: 7, sharedStrings: sharedStrings) ?? ""
            let volee = getCellValueOptimized(cells, at: 8, sharedStrings: sharedStrings) ?? ""
            let option = getCellValueOptimized(cells, at: 9, sharedStrings: sharedStrings) ?? ""
            let enseignant = getCellValueOptimized(cells, at: 10, sharedStrings: sharedStrings) ?? ""
            let salle = getCellValueOptimized(cells, at: 11, sharedStrings: sharedStrings) ?? ""
            
            // Filtrer par volée AVANT de vérifier le cours
            guard let selectedVolee = selectedVolee else { continue }
            
            if !matchesVoleeForExamens(volee: volee, modalite: modalite, option: option, selectedVolee: selectedVolee, selectedModalites: modalites) {
                continue
            }
            
            // ✅ VÉRIFICATION : Si le cours est juste un nombre, c'est une erreur de parsing
            var cours = coursRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if cours.isEmpty || Int(cours) != nil {
                cours = "⚠️ Erreur de lecture du fichier Excel"
                print("⚠️ Ligne \(index): Cours illisible (valeur: '\(coursRaw)'), utilisateur sera notifié")
            }
            
            print("✅ Ligne \(index): Examen '\(cours)' ACCEPTÉ - Volée: '\(volee)'")
            
            print("✅ Ligne \(index): Examen '\(cours)' ACCEPTÉ - Volée: '\(volee)'")

            // Parser la date
            guard let date = parseDate(dateStr) else {
                print("⚠️ Ligne \(index): Date invalide '\(dateStr)'")
                continue
            }

            let formatter = DateFormatter()
            formatter.dateFormat = "dd/MM/yyyy"
            print("✅ Ligne \(index): Date Excel '\(dateStr)' -> Date parsée: \(formatter.string(from: date)) | Examen: '\(cours)'")

            // 🔍 AJOUTEZ CES LOGS ICI ⬇️
            print("🔍 DEBUG Ligne \(index): arriveeControle brut = '\(arriveeControle)'")
            print("🔍 DEBUG Ligne \(index): heureDebut brut = '\(heureDebut)'")
            print("🔍 DEBUG Ligne \(index): heureFin brut = '\(heureFin)'")

            // Construire les informations d'horaire
            let heureComplete: String
            if !arriveeControle.isEmpty && arriveeControle != "Ø" {
                let arriveeFormatted = formatSingleHeureUniform(arriveeControle)
                print("🔍 DEBUG Ligne \(index): arriveeControle formaté = '\(arriveeFormatted)'")
                
                if !heureDebut.isEmpty && !heureFin.isEmpty {
                    let debutFormatted = formatSingleHeureUniform(heureDebut)
                    let finFormatted = formatSingleHeureUniform(heureFin)
                    print("🔍 DEBUG Ligne \(index): heureDebut formaté = '\(debutFormatted)', heureFin formaté = '\(finFormatted)'")
                    heureComplete = "Arrivée: \(arriveeFormatted) | Examen: \(debutFormatted) - \(finFormatted)"
                } else {
                    heureComplete = "Arrivée: \(arriveeFormatted)"
                }
            } else {
                if !heureDebut.isEmpty && !heureFin.isEmpty {
                    let debutFormatted = formatSingleHeureUniform(heureDebut)
                    let finFormatted = formatSingleHeureUniform(heureFin)
                    heureComplete = "\(debutFormatted) - \(finFormatted)"
                } else {
                    heureComplete = "Horaire non spécifié"
                }
            }
            // Construire le contenu de l'examen
            var contenuExamen = ""
            if !modalite.isEmpty {
                contenuExamen = "📝 \(modalite)"
            }
            if !anonymisation.isEmpty {
                if !contenuExamen.isEmpty {
                    contenuExamen += "\n"
                }
                contenuExamen += "🔒 Anonymisation: \(anonymisation)"
            }
            if !option.isEmpty && option != "Toutes orientations" {
                if !contenuExamen.isEmpty {
                    contenuExamen += "\n"
                }
                contenuExamen += "📚 \(option)"
            }
            
            let schedule = CourseSchedule(
                date: date,
                heure: heureComplete,
                cours: cours,
                salle: salle,
                enseignant: enseignant,
                duration: extractDuration(debut: heureDebut, fin: heureFin),
                color: colors[colorIndex % colors.count],
                contenuCours: contenuExamen,
                nombrePeriode: ""
            )
            scheduleItems.append(schedule)
            colorIndex += 1
        }
        
        print("✅ Total examens créés: \(scheduleItems.count)")
        return scheduleItems
    }

    // Nouvelle fonction de matching avec volée + modalités
    private static func matchesVoleeAndModalites(cursus: String, selectedVolee: String, modalites: [Modalite]) -> Bool {
        let cleanCursus = cursus.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSelected = selectedVolee.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // ⚠️ Si le cursus est vide, on ne peut pas savoir à qui appartient ce cours
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
    
    // NOUVEAU : Fonction de matching pour les examens
    private static func matchesVoleeForExamens(volee: String, modalite: String, option: String, selectedVolee: String, selectedModalites: [Modalite]) -> Bool {
        let cleanVolee = volee.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanSelected = selectedVolee.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanModalite = modalite.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanOption = option.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Si pas de volée spécifiée dans l'examen, ne pas l'accepter
        if cleanVolee.isEmpty {
            print("⚠️ Examen sans volée spécifiée - REJETÉ")
            return false
        }
        
        // Gérer les volées multiples séparées par "/" ou ","
        let voleeParts = cleanVolee.components(separatedBy: CharacterSet(charactersIn: "/,")).map { $0.trimmingCharacters(in: .whitespaces) }
        
        var voleeMatches = false
        for voleePart in voleeParts {
            if voleePart.contains(cleanSelected) {
                voleeMatches = true
                break
            }
        }
        
        // Si la volée ne correspond pas, rejeter
        if !voleeMatches {
            return false
        }
        
        // Si l'option est "Toutes orientations", accepter pour toutes les modalités
        if cleanOption.contains("toutes orientations") {
            return true
        }
        
        // Si les deux modalités sont sélectionnées, accepter
        if selectedModalites.count == 2 {
            return true
        }
        
        // Vérifier les modalités spécifiques
        for selectedModalite in selectedModalites {
            switch selectedModalite {
            case .tempsPlein:
                // Chercher "Temps Plein" ou "Plein" dans la volée ou la modalité
                if cleanVolee.contains("temps plein") || cleanVolee.contains("plein") ||
                   cleanModalite.contains("temps plein") || cleanModalite.contains("plein") {
                    return true
                }
            case .partiel:
                // Chercher "Partiel" dans la volée ou la modalité
                if cleanVolee.contains("partiel") || cleanModalite.contains("partiel") {
                    return true
                }
            }
        }
        
        // Si aucune modalité n'est spécifiée dans l'examen, l'accepter par défaut
        if cleanModalite.isEmpty && !cleanVolee.contains("temps plein") && !cleanVolee.contains("plein") && !cleanVolee.contains("partiel") {
            return true
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
    
    // Fonction pour lire spécifiquement les cellules de date
    private static func getDateCellValue(_ cells: [Cell], at index: Int, sharedStrings: SharedStrings?) -> String? {
        guard index < cells.count else { return nil }
        let cell = cells[index]
        
        if let sharedStrings = sharedStrings,
           let stringValue = cell.stringValue(sharedStrings) {
            return stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        if let inlineString = cell.inlineString {
            return inlineString.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        if let value = cell.value {
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return nil
    }
    
    private static func parseDate(_ dateString: String) -> Date? {
        // Vérifier si c'est un serial number Excel (un nombre)
        if let serialNumber = Double(dateString) {
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
    
    private static func formatSingleHeureUniform(_ heure: String) -> String {
        let cleaned = heure.trimmingCharacters(in: .whitespaces)
        
        // Si c'est vide, retourner une valeur par défaut
        if cleaned.isEmpty {
            return "00:00"
        }
        
        // ✅ CORRECTION : Si c'est un nombre avec point
        if cleaned.contains(".") {
            if let doubleValue = Double(cleaned) {
                let hours = Int(doubleValue)
                // La partie décimale représente directement les minutes (pas une fraction)
                let decimalPart = doubleValue - Double(hours)
                let decimalString = String(format: "%.1f", decimalPart)
                
                // Extraire le chiffre après le point
                if let dotIndex = decimalString.firstIndex(of: "."),
                   decimalString.count > dotIndex.utf16Offset(in: decimalString) + 1 {
                    let minuteChar = decimalString[decimalString.index(after: dotIndex)]
                    if let minuteDigit = Int(String(minuteChar)) {
                        let minutes = minuteDigit * 10  // .3 devient 30
                        return String(format: "%02d:%02d", hours, minutes)
                    }
                }
                
                // Fallback si on n'arrive pas à extraire
                return String(format: "%02d:00", hours)
            }
        }
        
        // Si ça contient deux-points (comme "14:00")
        if cleaned.contains(":") {
            let components = cleaned.components(separatedBy: ":")
            if components.count == 2,
               let hour = Int(components[0]),
               let minute = Int(components[1]) {
                return String(format: "%02d:%02d", hour, minute)
            }
        }
        
        // Si c'est juste un nombre (comme "14" ou "9")
        if let hour = Int(cleaned) {
            return String(format: "%02d:00", hour)
        }
        
        // Sinon retourner tel quel
        return cleaned
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
            
            if let firstRow = rows.first {
                let cells = firstRow.cells
                
                for (index, cell) in cells.enumerated() {
                    if let value = getCellValueOptimized(cells, at: index, sharedStrings: sharedStrings),
                       !value.isEmpty {
                        
                        print("📋 Cellule \(index) de la première ligne: '\(value)'")
                        
                        if value.contains("2025") || value.contains("2024") {
                            print("📅 Titre trouvé dans Excel: '\(value)'")
                            
                            if let dateMatch = value.range(of: "\\d{2}\\.\\d{2}\\.\\d{4}", options: .regularExpression) {
                                let dateStr = String(value[dateMatch])
                                print("📅 Date extraite: '\(dateStr)'")
                                
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
    
    // Validation de la structure du fichier
    static func validateFileStructure(_ data: Data, fileType: FileType) throws -> Bool {
        guard let xlsx = try? XLSXFile(data: data) else {
            return false
        }
        
        guard let firstWorkbook = try xlsx.parseWorkbooks().first else {
            return false
        }
        
        let worksheetPaths = try xlsx.parseWorksheetPathsAndNames(workbook: firstWorkbook)
        
        // Vérifier qu'il y a bien un onglet "Horaire"
        guard worksheetPaths.first(where: { $0.name!.lowercased().contains("horaire") }) != nil else {
            return false
        }
        
        // Pour les cours, vérifier qu'il y a un "Menu déroulant"
        if fileType == .cours {
            guard worksheetPaths.first(where: {
                $0.name!.lowercased().contains("menu") ||
                $0.name!.lowercased().contains("déroulant") ||
                $0.name!.lowercased().contains("deroulant")
            }) != nil else {
                return false
            }
        }
        
        switch fileType {
        case .cours:
            return try validateCoursStructure(xlsx, workbook: firstWorkbook)
        case .examens:
            return try validateExamensStructure(xlsx, workbook: firstWorkbook)
        }
    }
    
    private static func validateCoursStructure(_ xlsx: XLSXFile, workbook: Workbook) throws -> Bool {
        let worksheetPaths = try xlsx.parseWorksheetPathsAndNames(workbook: workbook)
        guard let horairePath = worksheetPaths.first(where: { $0.name!.lowercased().contains("horaire") })?.path else {
            return false
        }
        
        let worksheet = try xlsx.parseWorksheet(at: horairePath)
        let rows = worksheet.data?.rows ?? []
        
        guard rows.count >= 3 else { return false }
        
        if let headerRow = rows.first {
            let cells = headerRow.cells
            return cells.count >= 11
        }
        
        return false
    }
    
    private static func validateExamensStructure(_ xlsx: XLSXFile, workbook: Workbook) throws -> Bool {
        let worksheetPaths = try xlsx.parseWorksheetPathsAndNames(workbook: workbook)
        guard let horairePath = worksheetPaths.first(where: { $0.name!.lowercased().contains("horaire") })?.path else {
            return false
        }
        
        let worksheet = try xlsx.parseWorksheet(at: horairePath)
        let rows = worksheet.data?.rows ?? []
        
        guard rows.count >= 4 else { return false }
        
        if let firstDataRow = rows.dropFirst(3).first {
            return firstDataRow.cells.count >= 12
        }
        
        return false
    }
}
