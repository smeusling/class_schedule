// Services/ExcelParser.swift

import Foundation
import CoreXLSX

class ExcelParser {
    
    // Services/ExcelParser.swift

    // ✅ MODIFIER la fonction extractVolees :

    static func extractVolees(_ data: Data) throws -> [String] {
        guard let xlsx = try? XLSXFile(data: data) else {
            throw NSError(domain: "ExcelParsingError", code: -1)
        }
        
        var voleesSet = Set<String>()
        let workbooks = try xlsx.parseWorkbooks()
        
        guard let firstWorkbook = workbooks.first else { return [] }
        
        let worksheetPaths = try xlsx.parseWorksheetPathsAndNames(workbook: firstWorkbook)
        
        // 1️⃣ Essayer d'abord de trouver l'onglet "Menu déroulant" (fichier Automne)
        if let menuPath = worksheetPaths.first(where: {
            $0.name!.lowercased().contains("menu") ||
            $0.name!.lowercased().contains("déroulant") ||
            $0.name!.lowercased().contains("deroulant")
        })?.path {
            
            print("✅ Onglet 'Menu déroulant' trouvé - extraction depuis Menu déroulant")
            return extractVoleesFromMenuDeroulant(xlsx: xlsx, menuPath: menuPath)
            
        } else {
            // 2️⃣ Sinon, extraire depuis la colonne "Volée" dans l'onglet "Horaire" (fichier Printemps)
            print("⚠️ Onglet 'Menu déroulant' non trouvé - extraction depuis l'onglet Horaire")
            
            guard let horairePath = worksheetPaths.first(where: { $0.name!.lowercased().contains("horaire") })?.path else {
                print("❌ Onglet 'Horaire' non trouvé non plus")
                return []
            }
            
            return try extractVoleesFromHoraireSheet(xlsx: xlsx, horairePath: horairePath)
        }
    }

    // ✅ NOUVELLE FONCTION : Extraire depuis "Menu déroulant"
    private static func extractVoleesFromMenuDeroulant(xlsx: XLSXFile, menuPath: String) -> [String] {
        var voleesSet = Set<String>()
        
        do {
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
            
        } catch {
            print("❌ Erreur lors de l'extraction depuis Menu déroulant: \(error)")
            return []
        }
    }

    // ✅ NOUVELLE FONCTION : Extraire depuis l'onglet "Horaire"
    private static func extractVoleesFromHoraireSheet(xlsx: XLSXFile, horairePath: String) throws -> [String] {
        var voleesSet = Set<String>()
        
        let worksheet = try xlsx.parseWorksheet(at: horairePath)
        let rows = worksheet.data?.rows ?? []
        let sharedStrings = try? xlsx.parseSharedStrings()
        
        print("📊 Parsing de l'onglet Horaire - \(rows.count) lignes...")
        
        // Trouver la colonne "Volée"
        guard let voleeCol = findColumnIndex(in: rows, sharedStrings: sharedStrings, columnName: "volée") else {
            print("❌ Colonne 'Volée' non trouvée")
            return []
        }
        
        print("✅ Colonne 'Volée' trouvée à l'index \(voleeCol)")
        
        // Parcourir toutes les lignes et extraire les volées uniques
        for (index, row) in rows.enumerated() {
            if index < 3 { continue } // Skip les en-têtes
            
            let cells = row.cells
            guard let volee = getCellValueOptimized(cells, at: voleeCol, sharedStrings: sharedStrings), !volee.isEmpty else {
                continue
            }
            
            // Nettoyer la volée (enlever "Tous", "Temps Plein", "Temps Partiel", etc.)
            var cleanedVolee = volee
                .replacingOccurrences(of: " Tous", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " Temps plein", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " Temps Plein", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " Temps partiel", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " Temps Partiel", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " Partiel", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " Plein", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Gérer les cursus multiples séparés par "/"
            let parts = cleanedVolee.components(separatedBy: "/")
            for part in parts {
                let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
                let partLowercased = trimmed.lowercased()
                
                // Vérifier que cette partie est aussi une vraie volée
                let isValidVolee = partLowercased.hasPrefix("icls") ||
                                  partLowercased.hasPrefix("ips") ||
                                  partLowercased.hasPrefix("mscips") ||
                                  partLowercased.hasPrefix("etudiants")
                
                if isValidVolee && trimmed.count >= 3 {
                    voleesSet.insert(trimmed)
                }
            }
        }
        
        let sortedVolees = Array(voleesSet).sorted()
        print("✅ Total volées extraites: \(sortedVolees.count)")
        print("📋 Liste finale: \(sortedVolees)")
        
        return sortedVolees
    }
    
    // ✅ NOUVELLE FONCTION : Extraire les options disponibles par volée
    static func extractOptionsForVolees(_ data: Data) throws -> [String: Set<String>] {
        guard let xlsx = try? XLSXFile(data: data) else {
            throw NSError(domain: "ExcelParsingError", code: -1)
        }
        
        var optionsByVolee: [String: Set<String>] = [:]
        
        guard let firstWorkbook = try xlsx.parseWorkbooks().first else { return [:] }
        
        let worksheetPaths = try xlsx.parseWorksheetPathsAndNames(workbook: firstWorkbook)
        
        guard let horairePath = worksheetPaths.first(where: { $0.name!.lowercased().contains("horaire") })?.path else {
            return [:]
        }
        
        let worksheet = try xlsx.parseWorksheet(at: horairePath)
        let rows = worksheet.data?.rows ?? []
        let sharedStrings = try? xlsx.parseSharedStrings()
        
        print("📊 Extraction des options par volée...")
        
        // Trouver les colonnes nécessaires
        let columnMap = buildColumnMap(rows: rows, sharedStrings: sharedStrings, fileType: .cours)
        
        guard let cursusCol = columnMap["cursus"],
              let optionCol = columnMap["option"] else {
            print("❌ Colonnes 'cursus' ou 'option' non trouvées")
            return [:]
        }
        
        print("✅ Colonnes trouvées: cursus=\(cursusCol), option=\(optionCol)")
        
        // Parcourir toutes les lignes
        for (index, row) in rows.enumerated() {
            if index < 3 { continue } // Skip les en-têtes
            
            let cells = row.cells
            
            guard let cursus = getCellValueOptimized(cells, at: cursusCol, sharedStrings: sharedStrings),
                  !cursus.isEmpty else {
                continue
            }
            
            guard let option = getCellValueOptimized(cells, at: optionCol, sharedStrings: sharedStrings),
                  !option.isEmpty else {
                continue
            }
            
            // Nettoyer le cursus (enlever modalités)
            let cleanedCursus = cursus
                .replacingOccurrences(of: " Temps plein", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " Temps Plein", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " Temps partiel", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " Temps Partiel", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " Partiel", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " Plein", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " Tous", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Séparer les volées multiples
            let volees = cleanedCursus.components(separatedBy: "/")
            
            for volee in volees {
                let trimmedVolee = volee.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Vérifier que c'est une vraie volée
                let lowercased = trimmedVolee.lowercased()
                let isValid = lowercased.hasPrefix("icls") ||
                             lowercased.hasPrefix("ips") ||
                             lowercased.hasPrefix("mscips") ||
                             lowercased.hasPrefix("etudiants")
                
                if isValid && trimmedVolee.count >= 3 {
                                // Initialiser le Set si nécessaire
                                if optionsByVolee[trimmedVolee] == nil {
                                    optionsByVolee[trimmedVolee] = Set<String>()
                                }
                                
                                // ✅ Nettoyer et séparer l'option
                                let cleanedOption = option.trimmingCharacters(in: .whitespacesAndNewlines)
                                
                                // ✅ Filtrer les options à ignorer
                                let lowerOption = cleanedOption.lowercased()
                                if lowerOption.contains("tous") ||
                                   lowerOption.contains("toutes orientations") ||
                                   cleanedOption.isEmpty {
                                    // Ne pas ajouter ces options
                                    continue
                                }
                                
                                // ✅ Séparer d'abord les options multiples avec "/" ou ","
                                let separators = CharacterSet(charactersIn: "/,")
                                let optionParts = cleanedOption.components(separatedBy: separators)
                                
                                for part in optionParts {
                                    let trimmedPart = part.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if trimmedPart.isEmpty || trimmedPart.count <= 2 {
                                        continue
                                    }
                                    
                                    // ✅ Normaliser chaque partie individuellement
                                    var normalizedPart = trimmedPart
                                    let lowerPart = trimmedPart.lowercased()
                                    
                                    // Mapper les variations vers les noms standards
                                    if lowerPart == "primaires" || lowerPart == "soins primaires" {
                                        normalizedPart = "Soins primaires"
                                    } else if lowerPart == "adultes" || lowerPart == "soins aux adultes" {
                                        normalizedPart = "Soins aux adultes"
                                    } else if lowerPart == "pédiatriques" || lowerPart == "pediatriques" ||
                                              lowerPart == "pédiatrie" || lowerPart == "pediatrie" ||
                                              lowerPart == "soins aux enfants" {
                                        normalizedPart = "Soins aux enfants"
                                    } else if lowerPart == "santé mentale" {
                                        normalizedPart = "Santé mentale"
                                    } else if lowerPart == "option clinique" {
                                        normalizedPart = "Option clinique"
                                    } else if lowerPart == "option recherche" {
                                        normalizedPart = "Option recherche"
                                    }
                                    // Sinon, garder le nom tel quel (première lettre en majuscule)
                                    else if !normalizedPart.isEmpty {
                                        normalizedPart = normalizedPart.prefix(1).uppercased() + normalizedPart.dropFirst()
                                    }
                                    
                                    optionsByVolee[trimmedVolee]?.insert(normalizedPart)
                                }
                            }
            }
        }
        
        // Afficher les résultats
        for (volee, options) in optionsByVolee.sorted(by: { $0.key < $1.key }) {
            print("🎯 \(volee): \(options.sorted().joined(separator: ", "))")
        }
        
        return optionsByVolee
    }
    
    // Parser avec filtre de volée ET modalités ET option ET type de fichier
    static func parse(_ data: Data, selectedVolee: String?, modalites: [Modalite], selectedOption: String?, fileType: FileType) throws -> [CourseSchedule] {
        switch fileType {
        case .cours:
            return try parseCoursSchedule(data, selectedVolee: selectedVolee, modalites: modalites, selectedOption: selectedOption)
        case .examens:
            return try parseExamensSchedule(data, selectedVolee: selectedVolee, modalites: modalites, selectedOption: selectedOption)
        }
    }
    
    // MARK: - Fonctions utilitaires pour trouver les colonnes par nom
    
    private static func findColumnIndex(in rows: [Row], sharedStrings: SharedStrings?, columnName: String) -> Int? {
        // Chercher dans les 3 premières lignes (souvent l'en-tête est en ligne 1 ou 2)
        for row in rows.prefix(3) {
            let cells = row.cells
            
            for (index, _) in cells.enumerated() {
                if let value = getCellValueOptimized(cells, at: index, sharedStrings: sharedStrings) {
                    let cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    let cleanSearch = columnName.lowercased()
                    
                    // ✅ CORRECTION : Chercher une correspondance EXACTE d'abord
                    if cleanValue == cleanSearch {
                        print("✅ Colonne '\(columnName)' trouvée à l'index \(index) (valeur: '\(value)') - EXACT MATCH")
                        return index
                    }
                }
            }
        }
        
        // ✅ Si pas de match exact, chercher si ça contient (fallback)
        for row in rows.prefix(3) {
            let cells = row.cells
            
            for (index, _) in cells.enumerated() {
                if let value = getCellValueOptimized(cells, at: index, sharedStrings: sharedStrings) {
                    let cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    let cleanSearch = columnName.lowercased()
                    
                    if cleanValue.contains(cleanSearch) {
                        print("✅ Colonne '\(columnName)' trouvée à l'index \(index) (valeur: '\(value)') - PARTIAL MATCH")
                        return index
                    }
                }
            }
        }
        
        print("⚠️ Colonne '\(columnName)' non trouvée")
        return nil
    }
    
    private static func buildColumnMap(rows: [Row], sharedStrings: SharedStrings?, fileType: FileType) -> [String: Int] {
        var columnMap: [String: Int] = [:]
        
        let columnsToFind: [String]
        if fileType == .cours {
            columnsToFind = ["date", "heure début", "heure fin", "nombre période", "contenu", "option", "enseignant", "salle"]
        } else {
            columnsToFind = ["date", "arrivée", "heure début", "heure fin", "cours", "modalité", "anonymisation", "volée", "option", "enseignant", "salle"]
        }
        
        print("🔍 Recherche des colonnes pour type: \(fileType.rawValue)")
        
        for columnName in columnsToFind {
            if let index = findColumnIndex(in: rows, sharedStrings: sharedStrings, columnName: columnName) {
                columnMap[columnName] = index
            }
        }
        
        // ✅ SPÉCIAL : Pour le fichier cours, déduire les colonnes sans titre
        if fileType == .cours {
            // La colonne "Cours" (sans titre) est juste AVANT "Contenu du cours"
            if let contenuIndex = columnMap["contenu"] {
                let coursIndex = contenuIndex - 1
                columnMap["cours"] = coursIndex
                print("✅ Colonne 'cours' déduite à l'index \(coursIndex) (juste avant Contenu)")
            }
            
            // La colonne "Cursus" (sans titre) est juste AVANT "Option"
            if let optionIndex = columnMap["option"] {
                let cursusIndex = optionIndex - 1
                columnMap["cursus"] = cursusIndex
                print("✅ Colonne 'cursus' déduite à l'index \(cursusIndex) (juste avant Option)")
            }
        } else {
            // Pour les examens, cursus n'existe pas, on garde "cours" tel quel
        }
        
        print("📋 Mapping des colonnes: \(columnMap)")
        return columnMap
    }
    
    // Parser pour les horaires de cours
    private static func parseCoursSchedule(_ data: Data, selectedVolee: String?, modalites: [Modalite], selectedOption: String?) throws -> [CourseSchedule] {
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
        
        scheduleItems = parseCoursWorksheetDynamic(worksheet, sharedStrings: sharedStrings, colors: colors, colorIndex: &colorIndex, selectedVolee: selectedVolee, modalites: modalites, selectedOption: selectedOption)
        
        return scheduleItems.sorted { $0.date < $1.date }
    }
    
    // NOUVEAU : Parser pour les horaires d'examens
    private static func parseExamensSchedule(_ data: Data, selectedVolee: String?, modalites: [Modalite], selectedOption: String?) throws -> [CourseSchedule] {
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
        
        scheduleItems = parseExamensWorksheetDynamic(worksheet, sharedStrings: sharedStrings, colors: colors, colorIndex: &colorIndex, selectedVolee: selectedVolee, modalites: modalites, selectedOption: selectedOption)
        
        return scheduleItems.sorted { $0.date < $1.date }
    }
    
    private static func parseCoursWorksheetDynamic(_ worksheet: Worksheet, sharedStrings: SharedStrings?, colors: [ScheduleColor], colorIndex: inout Int, selectedVolee: String?, modalites: [Modalite], selectedOption: String?) -> [CourseSchedule] {
        var scheduleItems: [CourseSchedule] = []
        let rows = worksheet.data?.rows ?? []
        
        print("📊 Parsing \(rows.count) lignes...")
        
        // ✅ NOUVEAU : Construire le mapping des colonnes
        let columnMap = buildColumnMap(rows: rows, sharedStrings: sharedStrings, fileType: .cours)
        
        // Vérifier qu'on a les colonnes essentielles
        guard let dateCol = columnMap["date"],
              let coursCol = columnMap["cours"] else {
            print("❌ Colonnes essentielles manquantes (date ou cours)")
            return []
        }
        
        // Colonnes optionnelles avec fallback
        let heureDebutCol = columnMap["heure début"] ?? columnMap["heure debut"] ?? 2
        let heureFinCol = columnMap["heure fin"] ?? 3
        let nombrePeriodeCol = columnMap["nombre période"] ?? columnMap["nombre periode"] ?? 4
        let contenuCol = columnMap["contenu"] ?? columnMap["contenu du cours"] ?? 6
        let cursusCol = columnMap["cursus"] ?? 7
        let optionCol = columnMap["option"] ?? 8
        let enseignantCol = columnMap["enseignant"] ?? 9
        let salleCol = columnMap["salle"] ?? 10
        
        print("🔍 Colonnes utilisées: date=\(dateCol), cours=\(coursCol), cursus=\(cursusCol), option=\(optionCol), salle=\(salleCol), enseignant=\(enseignantCol)")
        
        for (index, row) in rows.enumerated() {
            if index < 2 { continue }
            
            let cells = row.cells
            
            let dateStr = getDateCellValue(cells, at: dateCol, sharedStrings: sharedStrings) ?? ""
            let heureDebut = getCellValueOptimized(cells, at: heureDebutCol, sharedStrings: sharedStrings) ?? ""
            let heureFin = getCellValueOptimized(cells, at: heureFinCol, sharedStrings: sharedStrings) ?? ""
            let nombrePeriode = getCellValueOptimized(cells, at: nombrePeriodeCol, sharedStrings: sharedStrings) ?? ""
            let cours = getCellValueOptimized(cells, at: coursCol, sharedStrings: sharedStrings) ?? ""
            let contenuCours = getCellValueOptimized(cells, at: contenuCol, sharedStrings: sharedStrings) ?? ""
            let cursus = getCellValueOptimized(cells, at: cursusCol, sharedStrings: sharedStrings) ?? ""
            let option = getCellValueOptimized(cells, at: optionCol, sharedStrings: sharedStrings) ?? ""
            let enseignant = getCellValueOptimized(cells, at: enseignantCol, sharedStrings: sharedStrings) ?? ""
            
            // ✅ Nettoyer les erreurs Excel
            var salle = getCellValueOptimized(cells, at: salleCol, sharedStrings: sharedStrings) ?? ""
            
            if salle == "#REF!" || salle == "#N/A" || salle == "#VALUE!" || salle == "#DIV/0!" || salle == "#NAME?" || salle == "0" {
                salle = ""
            }
            
            // Filtrer par volée ET modalités
            if let selectedVolee = selectedVolee {
                if !matchesVoleeAndModalites(cursus: cursus, selectedVolee: selectedVolee, modalites: modalites) {
                    continue
                }
            }
            
            // ✅ NOUVEAU : Filtrer par option si sélectionnée
                    if let selectedOption = selectedOption, !selectedOption.isEmpty {
                        let cleanOption = option.trimmingCharacters(in: .whitespacesAndNewlines)
                        let lowerCleanOption = cleanOption.lowercased()
                        
                        // Si l'option du cours est vide, "Tous", ou "IPS toutes orientations", on l'affiche pour tout le monde
                        if cleanOption.isEmpty ||
                           lowerCleanOption.contains("tous") ||
                           lowerCleanOption.contains("toutes orientations") {
                            // Ce cours est pour tout le monde, on l'affiche
                            print("✅ Cours accepté (option vide/tous): \(cours)")
                        } else {
                            // ✅ Séparer les options multiples par "/" ou ","
                            let separators = CharacterSet(charactersIn: "/,")
                            let courseOptionParts = cleanOption.components(separatedBy: separators)
                                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            
                            let selectedLower = selectedOption.lowercased()
                            
                            print("🔍 Cours: '\(cours)' - Option cours: '\(cleanOption)' - Parts: \(courseOptionParts)")
                            print("   Option sélectionnée: '\(selectedOption)'")
                            
                            // Fonction pour normaliser et comparer
                            func normalizeAndMatch(_ part: String, _ selected: String) -> Bool {
                                let lowerPart = part.lowercased()
                                
                                // Correspondances directes
                                if lowerPart == selected || selected.contains(lowerPart) || lowerPart.contains(selected) {
                                    print("   ✅ Match direct: '\(part)' <-> '\(selected)'")
                                    return true
                                }
                                
                                // Correspondances par équivalence
                                if selected.contains("primaire") && (lowerPart == "primaires" || lowerPart.contains("primaire")) {
                                    print("   ✅ Match primaires: '\(part)'")
                                    return true
                                }
                                if selected.contains("adulte") && (lowerPart == "adultes" || lowerPart.contains("adulte")) {
                                    print("   ✅ Match adultes: '\(part)'")
                                    return true
                                }
                                if selected.contains("enfant") && (lowerPart == "pédiatriques" || lowerPart == "pediatriques" ||
                                                                    lowerPart == "pédiatrie" || lowerPart == "pediatrie" ||
                                                                    lowerPart.contains("enfant")) {
                                    print("   ✅ Match enfants: '\(part)'")
                                    return true
                                }
                                if selected.contains("mentale") && lowerPart.contains("mentale") {
                                    print("   ✅ Match mentale: '\(part)'")
                                    return true
                                }
                                
                                return false
                            }
                            
                            // Vérifier si l'option sélectionnée correspond à au moins une des options du cours
                            let matches = courseOptionParts.contains { part in
                                !part.isEmpty && normalizeAndMatch(part, selectedLower)
                            }
                            
                            if !matches {
                                print("   ❌ Cours rejeté - aucun match")
                                continue
                            } else {
                                print("   ✅ Cours accepté - match trouvé")
                            }
                        }
                    }
            
            guard !cours.isEmpty else { continue }
            guard let date = parseDate(dateStr) else {
                continue
            }
            
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
    
    private static func parseExamensWorksheetDynamic(_ worksheet: Worksheet, sharedStrings: SharedStrings?, colors: [ScheduleColor], colorIndex: inout Int, selectedVolee: String?, modalites: [Modalite], selectedOption: String?) -> [CourseSchedule] {
        var scheduleItems: [CourseSchedule] = []
        let rows = worksheet.data?.rows ?? []
        
        print("📊 Parsing examens - \(rows.count) lignes...")
        
        // ✅ NOUVEAU : Construire le mapping des colonnes
        let columnMap = buildColumnMap(rows: rows, sharedStrings: sharedStrings, fileType: .examens)
        
        // Vérifier qu'on a les colonnes essentielles
        guard let dateCol = columnMap["date"],
              let coursCol = columnMap["cours"] else {
            print("❌ Colonnes essentielles manquantes (date ou cours)")
            return []
        }
        
        // Pour volée, essayer plusieurs variantes
        let voleeCol = columnMap["volée"] ?? columnMap["volee"] ?? 8
        
        // Colonnes optionnelles avec fallback
        let arriveeCol = columnMap["arrivée"] ?? columnMap["arrivee"] ?? columnMap["arrivée pour contrôle id"] ?? 2
        let heureDebutCol = columnMap["heure début"] ?? columnMap["heure debut"] ?? 3
        let heureFinCol = columnMap["heure fin"] ?? 4
        let modaliteCol = columnMap["modalité"] ?? columnMap["modalite"] ?? 6
        let anonymisationCol = columnMap["anonymisation"] ?? 7
        let optionCol = columnMap["option"] ?? 9
        let enseignantCol = columnMap["enseignant"] ?? 10
        let salleCol = columnMap["salle"] ?? 11
        
        print("🔍 Colonnes utilisées: date=\(dateCol), cours=\(coursCol), volée=\(voleeCol), option=\(optionCol), salle=\(salleCol)")
        
        for (index, row) in rows.enumerated() {
            if index < 3 { continue }
            
            let cells = row.cells
            
            let dateStr = getDateCellValue(cells, at: dateCol, sharedStrings: sharedStrings) ?? ""
            let arriveeControle = getCellValueOptimized(cells, at: arriveeCol, sharedStrings: sharedStrings) ?? ""
            let heureDebut = getCellValueOptimized(cells, at: heureDebutCol, sharedStrings: sharedStrings) ?? ""
            let heureFin = getCellValueOptimized(cells, at: heureFinCol, sharedStrings: sharedStrings) ?? ""
            let coursRaw = getCellValueOptimized(cells, at: coursCol, sharedStrings: sharedStrings) ?? ""
            let modalite = getCellValueOptimized(cells, at: modaliteCol, sharedStrings: sharedStrings) ?? ""
            let anonymisation = getCellValueOptimized(cells, at: anonymisationCol, sharedStrings: sharedStrings) ?? ""
            let volee = getCellValueOptimized(cells, at: voleeCol, sharedStrings: sharedStrings) ?? ""
            let option = getCellValueOptimized(cells, at: optionCol, sharedStrings: sharedStrings) ?? ""
            let enseignant = getCellValueOptimized(cells, at: enseignantCol, sharedStrings: sharedStrings) ?? ""
            
            // ✅ Nettoyer les erreurs Excel pour la salle
            var salle = getCellValueOptimized(cells, at: salleCol, sharedStrings: sharedStrings) ?? ""
            
            if salle == "#REF!" || salle == "#N/A" || salle == "#VALUE!" || salle == "#DIV/0!" || salle == "#NAME?" || salle == "0" {
                salle = ""
            }
            
            // Filtrer par volée
            guard let selectedVolee = selectedVolee else { continue }
            
            if !matchesVoleeForExamens(volee: volee, modalite: modalite, option: option, selectedVolee: selectedVolee, selectedModalites: modalites) {
                continue
            }
            
            // ✅ NOUVEAU : Filtrer par option si sélectionnée
                    if let selectedOption = selectedOption, !selectedOption.isEmpty {
                        let cleanOption = option.trimmingCharacters(in: .whitespacesAndNewlines)
                        let lowerCleanOption = cleanOption.lowercased()
                        
                        // Si l'option du cours est vide, "Tous", ou "IPS toutes orientations", on l'affiche pour tout le monde
                        if cleanOption.isEmpty ||
                           lowerCleanOption.contains("tous") ||
                           lowerCleanOption.contains("toutes orientations") {
                            // Ce cours est pour tout le monde, on l'affiche
                        } else {
                            // ✅ Séparer les options multiples par "/" ou ","
                            let separators = CharacterSet(charactersIn: "/,")
                            let courseOptionParts = cleanOption.components(separatedBy: separators)
                                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            
                            let selectedLower = selectedOption.lowercased()
                            
                            // Fonction pour normaliser et comparer
                            func normalizeAndMatch(_ part: String, _ selected: String) -> Bool {
                                let lowerPart = part.lowercased()
                                
                                // Correspondances directes
                                if lowerPart == selected || selected.contains(lowerPart) || lowerPart.contains(selected) {
                                    return true
                                }
                                
                                // Correspondances par équivalence
                                if selected.contains("primaire") && (lowerPart == "primaires" || lowerPart.contains("primaire")) {
                                    return true
                                }
                                if selected.contains("adulte") && (lowerPart == "adultes" || lowerPart.contains("adulte")) {
                                    return true
                                }
                                if selected.contains("enfant") && (lowerPart == "pédiatriques" || lowerPart == "pediatriques" ||
                                                                    lowerPart == "pédiatrie" || lowerPart == "pediatrie" ||
                                                                    lowerPart.contains("enfant")) {
                                    return true
                                }
                                if selected.contains("mentale") && lowerPart.contains("mentale") {
                                    return true
                                }
                                
                                return false
                            }
                            
                            // Vérifier si l'option sélectionnée correspond à au moins une des options du cours
                            let matches = courseOptionParts.contains { part in
                                !part.isEmpty && normalizeAndMatch(part, selectedLower)
                            }
                            
                            if !matches {
                                continue
                            }
                        }
                    }
            
            var cours = coursRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if cours.isEmpty || Int(cours) != nil {
                cours = "⚠️ Erreur de lecture du fichier Excel"
            }
            
            guard let date = parseDate(dateStr) else {
                continue
            }
            
            // Construire les informations d'horaire
            let heureComplete: String
            if !arriveeControle.isEmpty && arriveeControle != "Ø" {
                let arriveeFormatted = formatSingleHeureUniform(arriveeControle)
                
                if !heureDebut.isEmpty && !heureFin.isEmpty {
                    let debutFormatted = formatSingleHeureUniform(heureDebut)
                    let finFormatted = formatSingleHeureUniform(heureFin)
                    heureComplete = "Arrivée: \(arriveeFormatted) | Examen: \(debutFormatted) - \(finFormatted)"
                } else {
                    heureComplete = "Arrivée: \(arriveeFormatted)"
                }
            } else {
                if !heureDebut.isEmpty && !heureFin.isEmpty {
                    heureComplete = formatHeure(debut: heureDebut, fin: heureFin)
                } else {
                    heureComplete = "Horaire non spécifié"
                }
            }
            
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
            if !option.isEmpty {
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
        
        // ✅ Essayer la méthode standard d'abord
        if let sharedStrings = sharedStrings,
           let stringValue = cell.stringValue(sharedStrings) {
            return stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // ✅ AJOUT : Si stringValue est nil, récupérer manuellement depuis richText
        if let sharedStrings = sharedStrings,
           let type = cell.type,
           type == .sharedString,
           let valueString = cell.value,
           let sharedStringIndex = Int(valueString),
           sharedStringIndex < sharedStrings.items.count {
            
            let sharedString = sharedStrings.items[sharedStringIndex]
            
            // Si le texte est dans richText (tableau de fragments)
            if !sharedString.richText.isEmpty {
                let fullText = sharedString.richText
                    .compactMap { $0.text }
                    .joined()
                
                if !fullText.isEmpty {
                    return fullText.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            // Sinon, utiliser le texte simple s'il existe
            if let simpleText = sharedString.text {
                return simpleText.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Fallback sur la valeur brute
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
        let debutFormatted = formatSingleHeureUniform(debut)
        let finFormatted = formatSingleHeureUniform(fin)
        return "\(debutFormatted) - \(finFormatted)"
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
        // Nettoyer les espaces
        let cleanDebut = debut.trimmingCharacters(in: .whitespaces)
        let cleanFin = fin.trimmingCharacters(in: .whitespaces)
        
        // Si l'une des valeurs est vide, retourner vide
        if cleanDebut.isEmpty || cleanFin.isEmpty {
            return ""
        }
        
        // Parser l'heure de début
        var startMinutes = 0
        if cleanDebut.contains(":") {
            let parts = cleanDebut.components(separatedBy: ":")
            if parts.count == 2,
               let hours = Int(parts[0]),
               let minutes = Int(parts[1]) {
                startMinutes = hours * 60 + minutes
            }
        } else if cleanDebut.contains(".") {
            // ✅ CORRECTION : Gérer les floats avec précision
            if let doubleValue = Double(cleanDebut) {
                let hours = Int(doubleValue)
                let decimalPart = doubleValue - Double(hours)
                let decimalString = String(format: "%.1f", decimalPart)
                
                // Extraire le chiffre après le point (ex: 0.3 -> 3 -> 30 minutes)
                if let dotIndex = decimalString.firstIndex(of: "."),
                   decimalString.count > dotIndex.utf16Offset(in: decimalString) + 1 {
                    let minuteChar = decimalString[decimalString.index(after: dotIndex)]
                    if let minuteDigit = Int(String(minuteChar)) {
                        let minutes = minuteDigit * 10  // .3 devient 30
                        startMinutes = hours * 60 + minutes
                    }
                } else {
                    startMinutes = hours * 60
                }
            }
        } else if let hours = Int(cleanDebut) {
            startMinutes = hours * 60
        }
        
        // Parser l'heure de fin
        var endMinutes = 0
        if cleanFin.contains(":") {
            let parts = cleanFin.components(separatedBy: ":")
            if parts.count == 2,
               let hours = Int(parts[0]),
               let minutes = Int(parts[1]) {
                endMinutes = hours * 60 + minutes
            }
        } else if cleanFin.contains(".") {
            // ✅ CORRECTION : Gérer les floats avec précision
            if let doubleValue = Double(cleanFin) {
                let hours = Int(doubleValue)
                let decimalPart = doubleValue - Double(hours)
                let decimalString = String(format: "%.1f", decimalPart)
                
                // Extraire le chiffre après le point (ex: 0.3 -> 3 -> 30 minutes)
                if let dotIndex = decimalString.firstIndex(of: "."),
                   decimalString.count > dotIndex.utf16Offset(in: decimalString) + 1 {
                    let minuteChar = decimalString[decimalString.index(after: dotIndex)]
                    if let minuteDigit = Int(String(minuteChar)) {
                        let minutes = minuteDigit * 10  // .3 devient 30
                        endMinutes = hours * 60 + minutes
                    }
                } else {
                    endMinutes = hours * 60
                }
            }
        } else if let hours = Int(cleanFin) {
            endMinutes = hours * 60
        }
        
        // Si on n'a pas réussi à parser, retourner vide
        if startMinutes == 0 && endMinutes == 0 {
            return ""
        }
        
        // Calculer la différence
        var totalMinutes = endMinutes - startMinutes
        
        // Gérer le cas où on passe minuit
        if totalMinutes < 0 {
            totalMinutes += 24 * 60
        }
        
        // Vérification de sécurité : si la durée est absurde (> 24h), retourner vide
        if totalMinutes > 24 * 60 || totalMinutes < 0 {
            return ""
        }
        
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 && minutes > 0 {
            return "\(hours)h\(minutes)min"
        } else if hours > 0 {
            return "\(hours)h"
        } else if minutes > 0 {
            return "\(minutes)min"
        } else {
            return ""
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
                
                for (index, _) in cells.enumerated() {
                    if let value = getCellValueOptimized(cells, at: index, sharedStrings: sharedStrings),
                       !value.isEmpty {
                        
                        if value.contains("2025") || value.contains("2024") {
                            if let dateMatch = value.range(of: "\\d{2}\\.\\d{2}\\.\\d{4}", options: .regularExpression) {
                                let dateStr = String(value[dateMatch])
                                
                                let formatter = DateFormatter()
                                formatter.dateFormat = "dd.MM.yyyy"
                                if let date = formatter.date(from: dateStr) {
                                    return date
                                }
                            }
                        }
                    }
                }
            }
            
            return nil
            
        } catch {
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
