// Services/ExcelParser.swift

import Foundation
import CoreXLSX

class ExcelParser {

    // MARK: - Extraction des volées

    static func extractVolees(_ data: Data) throws -> [String] {
        guard let xlsx = try? XLSXFile(data: data) else {
            throw NSError(domain: "ExcelParsingError", code: -1)
        }

        guard let firstWorkbook = try xlsx.parseWorkbooks().first else { return [] }
        let worksheetPaths = try xlsx.parseWorksheetPathsAndNames(workbook: firstWorkbook)

        // Fichier Automne : onglet "Menu déroulant"
        if let menuPath = worksheetPaths.first(where: {
            $0.name!.lowercased().contains("menu") ||
            $0.name!.lowercased().contains("déroulant") ||
            $0.name!.lowercased().contains("deroulant")
        })?.path {
            return extractVoleesFromMenuDeroulant(xlsx: xlsx, menuPath: menuPath)
        }

        // Fichier Printemps : extraction depuis l'onglet "Horaire"
        guard let horairePath = worksheetPaths.first(where: { $0.name!.lowercased().contains("horaire") })?.path else {
            return []
        }
        return try extractVoleesFromHoraireSheet(xlsx: xlsx, horairePath: horairePath)
    }

    private static func extractVoleesFromMenuDeroulant(xlsx: XLSXFile, menuPath: String) -> [String] {
        var voleesSet = Set<String>()

        do {
            let worksheet = try xlsx.parseWorksheet(at: menuPath)
            let rows = worksheet.data?.rows ?? []
            let sharedStrings = try? xlsx.parseSharedStrings()
            var consecutiveNonVoleeCount = 0

            for (index, row) in rows.enumerated() {
                if index == 0 { continue }

                let cells = row.cells
                guard let volee = getCellValueOptimized(cells, at: 0, sharedStrings: sharedStrings), !volee.isEmpty else {
                    continue
                }

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

                let lowercased = cleanedVolee.lowercased()
                let startsWithValidPrefix = lowercased.hasPrefix("icls") ||
                                           lowercased.hasPrefix("ips") ||
                                           lowercased.hasPrefix("mscips") ||
                                           lowercased.hasPrefix("etudiants")

                if !startsWithValidPrefix {
                    consecutiveNonVoleeCount += 1
                    if consecutiveNonVoleeCount >= 3 { break }
                    continue
                }

                consecutiveNonVoleeCount = 0

                let parts = cleanedVolee.components(separatedBy: "/")
                for part in parts {
                    let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
                    let partLowercased = trimmed.lowercased()

                    let partIsValid = partLowercased.hasPrefix("icls") ||
                                     partLowercased.hasPrefix("ips") ||
                                     partLowercased.hasPrefix("mscips") ||
                                     partLowercased.hasPrefix("etudiants")

                    if partIsValid && trimmed.count >= 3 {
                        var finalTrimmed = trimmed
                        let components = trimmed.components(separatedBy: " ")
                        if components.count > 1, let first = components.first, first.allSatisfy({ $0.isNumber }) {
                            finalTrimmed = components.dropFirst().joined(separator: " ")
                        }
                        voleesSet.insert(finalTrimmed)
                    }
                }
            }

        } catch {
            print("❌ Erreur extraction Menu déroulant: \(error)")
        }

        return Array(voleesSet).sorted()
    }

    private static func extractVoleesFromHoraireSheet(xlsx: XLSXFile, horairePath: String) throws -> [String] {
        var voleesSet = Set<String>()

        let worksheet = try xlsx.parseWorksheet(at: horairePath)
        let rows = worksheet.data?.rows ?? []
        let sharedStrings = try? xlsx.parseSharedStrings()

        guard let voleeCol = findColumnIndex(in: rows, sharedStrings: sharedStrings, columnName: "volée") else {
            return []
        }

        for (index, row) in rows.enumerated() {
            if index < 3 { continue }

            let cells = row.cells
            guard let volee = getCellValueOptimized(cells, at: voleeCol, sharedStrings: sharedStrings), !volee.isEmpty else {
                continue
            }

            var cleanedVolee = volee
                .replacingOccurrences(of: " Tous", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " Temps plein", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " Temps Plein", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " Temps partiel", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " Temps Partiel", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " Partiel", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " Plein", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let parts = cleanedVolee.components(separatedBy: "/")
            for part in parts {
                let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
                let partLowercased = trimmed.lowercased()

                let isValidVolee = partLowercased.hasPrefix("icls") ||
                                   partLowercased.hasPrefix("ips") ||
                                   partLowercased.hasPrefix("mscips") ||
                                   partLowercased.hasPrefix("etudiants")

                if isValidVolee && trimmed.count >= 3 {
                    if trimmed.lowercased().contains("toutes orientations") { continue }

                    var normalized = trimmed
                    if normalized.hasPrefix("IPS-") {
                        normalized = "IPS " + String(normalized.dropFirst(4))
                    }
                    voleesSet.insert(normalized)
                }
            }
        }

        return Array(voleesSet).sorted()
    }

    // MARK: - Extraction des options par volée

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

        let columnMap = buildColumnMap(rows: rows, sharedStrings: sharedStrings, fileType: .cours)

        guard let cursusCol = columnMap["cursus"], let optionCol = columnMap["option"] else {
            return [:]
        }

        for (index, row) in rows.enumerated() {
            if index < 3 { continue }

            let cells = row.cells

            guard let cursus = getCellValueOptimized(cells, at: cursusCol, sharedStrings: sharedStrings), !cursus.isEmpty,
                  let option = getCellValueOptimized(cells, at: optionCol, sharedStrings: sharedStrings), !option.isEmpty else {
                continue
            }

            let cleanedCursus = cursus
                .replacingOccurrences(of: " Temps plein", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " Temps Plein", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " Temps partiel", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " Temps Partiel", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " Partiel", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " Plein", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " Tous", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            for volee in cleanedCursus.components(separatedBy: "/") {
                let trimmedVolee = volee.trimmingCharacters(in: .whitespacesAndNewlines)
                let lowercased = trimmedVolee.lowercased()

                let isValid = lowercased.hasPrefix("icls") || lowercased.hasPrefix("ips") ||
                              lowercased.hasPrefix("mscips") || lowercased.hasPrefix("etudiants")

                guard isValid && trimmedVolee.count >= 3 else { continue }

                if optionsByVolee[trimmedVolee] == nil {
                    optionsByVolee[trimmedVolee] = Set<String>()
                }

                let cleanedOption = option.trimmingCharacters(in: .whitespacesAndNewlines)
                let lowerOption = cleanedOption.lowercased()

                if lowerOption.contains("tous") || lowerOption.contains("toutes orientations") || cleanedOption.isEmpty {
                    continue
                }

                let separators = CharacterSet(charactersIn: "/,")
                for part in cleanedOption.components(separatedBy: separators) {
                    let trimmedPart = part.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmedPart.isEmpty || trimmedPart.count <= 2 { continue }

                    let lowerPart = trimmedPart.lowercased()
                    var normalizedPart: String

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
                    } else {
                        normalizedPart = trimmedPart.prefix(1).uppercased() + trimmedPart.dropFirst()
                    }

                    optionsByVolee[trimmedVolee]?.insert(normalizedPart)
                }
            }
        }

        return optionsByVolee
    }

    // MARK: - Point d'entrée principal

    static func parse(_ data: Data, selectedVolee: String?, modalites: [Modalite], selectedOption: String?, fileType: FileType) throws -> [CourseSchedule] {
        switch fileType {
        case .cours:
            return try parseCoursSchedule(data, selectedVolee: selectedVolee, modalites: modalites, selectedOption: selectedOption)
        case .examens:
            return try parseExamensSchedule(data, selectedVolee: selectedVolee, modalites: modalites, selectedOption: selectedOption)
        }
    }

    // MARK: - Utilitaires colonnes

    private static func findColumnIndex(in rows: [Row], sharedStrings: SharedStrings?, columnName: String) -> Int? {
        let cleanSearch = columnName.lowercased()

        // Correspondance exacte en priorité
        for row in rows.prefix(3) {
            for (index, _) in row.cells.enumerated() {
                if let value = getCellValueOptimized(row.cells, at: index, sharedStrings: sharedStrings) {
                    if value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == cleanSearch {
                        return index
                    }
                }
            }
        }

        // Correspondance partielle en fallback
        for row in rows.prefix(3) {
            for (index, _) in row.cells.enumerated() {
                if let value = getCellValueOptimized(row.cells, at: index, sharedStrings: sharedStrings) {
                    if value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().contains(cleanSearch) {
                        return index
                    }
                }
            }
        }

        return nil
    }

    private static func buildColumnMap(rows: [Row], sharedStrings: SharedStrings?, fileType: FileType) -> [String: Int] {
        var columnMap: [String: Int] = [:]

        let columnsToFind: [String] = fileType == .cours
            ? ["date", "heure début", "heure fin", "nombre période", "contenu", "option", "enseignant", "salle"]
            : ["date", "arrivée", "heure début", "heure fin", "cours", "modalité", "anonymisation", "volée", "option", "enseignant", "salle"]

        for columnName in columnsToFind {
            if let index = findColumnIndex(in: rows, sharedStrings: sharedStrings, columnName: columnName) {
                columnMap[columnName] = index
            }
        }

        if fileType == .cours {
            // La colonne "Cours" n'a pas de titre : elle est juste avant "Contenu"
            if columnMap["cours"] == nil, let contenuIndex = columnMap["contenu"] {
                columnMap["cours"] = contenuIndex - 1
            }
            // La colonne "Cursus" n'a pas de titre : elle est juste avant "Option"
            if let optionIndex = columnMap["option"] {
                columnMap["cursus"] = optionIndex - 1
            }
        }

        return columnMap
    }

    // MARK: - Parsing cours

    private static func parseCoursSchedule(_ data: Data, selectedVolee: String?, modalites: [Modalite], selectedOption: String?) throws -> [CourseSchedule] {
        guard let xlsx = try? XLSXFile(data: data) else {
            throw NSError(domain: "ExcelParsingError", code: -1)
        }

        var colorIndex = 0
        let colors = ScheduleColor.allCases

        guard let firstWorkbook = try xlsx.parseWorkbooks().first else { return [] }
        let worksheetPaths = try xlsx.parseWorksheetPathsAndNames(workbook: firstWorkbook)

        guard let horairePath = worksheetPaths.first(where: { $0.name!.lowercased().contains("horaire") })?.path
              ?? worksheetPaths.first?.path else { return [] }

        let worksheet = try xlsx.parseWorksheet(at: horairePath)
        let sharedStrings = try? xlsx.parseSharedStrings()

        let items = parseCoursWorksheetDynamic(worksheet, sharedStrings: sharedStrings, colors: colors, colorIndex: &colorIndex, selectedVolee: selectedVolee, modalites: modalites, selectedOption: selectedOption)
        return items.sorted { $0.date < $1.date }
    }

    private static func parseCoursWorksheetDynamic(_ worksheet: Worksheet, sharedStrings: SharedStrings?, colors: [ScheduleColor], colorIndex: inout Int, selectedVolee: String?, modalites: [Modalite], selectedOption: String?) -> [CourseSchedule] {
        var scheduleItems: [CourseSchedule] = []
        let rows = worksheet.data?.rows ?? []
        let columnMap = buildColumnMap(rows: rows, sharedStrings: sharedStrings, fileType: .cours)

        guard let dateCol = columnMap["date"], let coursCol = columnMap["cours"] else {
            return []
        }

        let heureDebutCol   = columnMap["heure début"] ?? 2
        let heureFinCol     = columnMap["heure fin"] ?? 3
        let nombrePeriodeCol = columnMap["nombre période"] ?? 4
        let contenuCol      = columnMap["contenu"] ?? 6
        let cursusCol       = columnMap["cursus"] ?? 7
        let optionCol       = columnMap["option"] ?? 8
        let enseignantCol   = columnMap["enseignant"] ?? 9
        let salleCol        = columnMap["salle"] ?? 10

        var lastValidDateStr = ""

        for (index, row) in rows.enumerated() {
            if index < 2 { continue }

            let cells = row.cells

            // Gestion des cellules de date fusionnées : réutiliser la dernière date valide
            var dateStr = getDateCellValue(cells, at: dateCol, sharedStrings: sharedStrings) ?? ""
            if dateStr.isEmpty { dateStr = lastValidDateStr } else { lastValidDateStr = dateStr }

            let heureDebut    = getCellValueOptimized(cells, at: heureDebutCol, sharedStrings: sharedStrings) ?? ""
            let heureFin      = getCellValueOptimized(cells, at: heureFinCol, sharedStrings: sharedStrings) ?? ""
            let nombrePeriode = getCellValueOptimized(cells, at: nombrePeriodeCol, sharedStrings: sharedStrings) ?? ""
            let cours         = getCellValueOptimized(cells, at: coursCol, sharedStrings: sharedStrings) ?? ""
            let contenuCours  = getCellValueOptimized(cells, at: contenuCol, sharedStrings: sharedStrings) ?? ""
            let cursus        = getCellValueOptimized(cells, at: cursusCol, sharedStrings: sharedStrings) ?? ""
            let option        = getCellValueOptimized(cells, at: optionCol, sharedStrings: sharedStrings) ?? ""
            let enseignant    = getCellValueOptimized(cells, at: enseignantCol, sharedStrings: sharedStrings) ?? ""

            var salle = getCellValueOptimized(cells, at: salleCol, sharedStrings: sharedStrings) ?? ""
            if ["#REF!", "#N/A", "#VALUE!", "#DIV/0!", "#NAME?", "0"].contains(salle) { salle = "" }

            if let selectedVolee = selectedVolee {
                guard matchesVoleeAndModalites(cursus: cursus, selectedVolee: selectedVolee, modalites: modalites) else { continue }
            }

            if let selectedOption = selectedOption, !selectedOption.isEmpty {
                guard matchesOption(courseOption: option, selectedOption: selectedOption) else { continue }
            }

            guard !cours.isEmpty, let date = parseDate(dateStr) else { continue }

            scheduleItems.append(CourseSchedule(
                date: date,
                heure: formatHeure(debut: heureDebut, fin: heureFin),
                cours: cours,
                salle: salle,
                enseignant: enseignant,
                duration: extractDuration(debut: heureDebut, fin: heureFin),
                color: colors[colorIndex % colors.count],
                contenuCours: contenuCours,
                nombrePeriode: nombrePeriode
            ))
            colorIndex += 1
        }

        return scheduleItems
    }

    // MARK: - Parsing examens

    private static func parseExamensSchedule(_ data: Data, selectedVolee: String?, modalites: [Modalite], selectedOption: String?) throws -> [CourseSchedule] {
        guard let xlsx = try? XLSXFile(data: data) else {
            throw NSError(domain: "ExcelParsingError", code: -1)
        }

        var colorIndex = 0
        let colors = ScheduleColor.allCases

        guard let firstWorkbook = try xlsx.parseWorkbooks().first else { return [] }
        let worksheetPaths = try xlsx.parseWorksheetPathsAndNames(workbook: firstWorkbook)

        guard let horairePath = worksheetPaths.first(where: { $0.name!.lowercased().contains("horaire") })?.path
              ?? worksheetPaths.first?.path else { return [] }

        let worksheet = try xlsx.parseWorksheet(at: horairePath)
        let sharedStrings = try? xlsx.parseSharedStrings()

        let items = parseExamensWorksheetDynamic(worksheet, sharedStrings: sharedStrings, colors: colors, colorIndex: &colorIndex, selectedVolee: selectedVolee, modalites: modalites, selectedOption: selectedOption)
        return items.sorted { $0.date < $1.date }
    }

    private static func parseExamensWorksheetDynamic(_ worksheet: Worksheet, sharedStrings: SharedStrings?, colors: [ScheduleColor], colorIndex: inout Int, selectedVolee: String?, modalites: [Modalite], selectedOption: String?) -> [CourseSchedule] {
        var scheduleItems: [CourseSchedule] = []
        let rows = worksheet.data?.rows ?? []
        let columnMap = buildColumnMap(rows: rows, sharedStrings: sharedStrings, fileType: .examens)

        guard let dateCol = columnMap["date"], let coursCol = columnMap["cours"] else {
            return []
        }

        let voleeCol         = columnMap["volée"] ?? 8
        let arriveeCol       = columnMap["arrivée"] ?? 2
        let heureDebutCol    = columnMap["heure début"] ?? 3
        let heureFinCol      = columnMap["heure fin"] ?? 4
        let modaliteCol      = columnMap["modalité"] ?? 6
        let anonymisationCol = columnMap["anonymisation"] ?? 7
        let optionCol        = columnMap["option"] ?? 9
        let enseignantCol    = columnMap["enseignant"] ?? 10
        let salleCol         = columnMap["salle"] ?? 11

        for (index, row) in rows.enumerated() {
            if index < 3 { continue }

            let cells = row.cells

            let dateStr          = getDateCellValue(cells, at: dateCol, sharedStrings: sharedStrings) ?? ""
            let arriveeControle  = getCellValueOptimized(cells, at: arriveeCol, sharedStrings: sharedStrings) ?? ""
            let heureDebut       = getCellValueOptimized(cells, at: heureDebutCol, sharedStrings: sharedStrings) ?? ""
            let heureFin         = getCellValueOptimized(cells, at: heureFinCol, sharedStrings: sharedStrings) ?? ""
            let coursRaw         = getCellValueOptimized(cells, at: coursCol, sharedStrings: sharedStrings) ?? ""
            let modalite         = getCellValueOptimized(cells, at: modaliteCol, sharedStrings: sharedStrings) ?? ""
            let anonymisation    = getCellValueOptimized(cells, at: anonymisationCol, sharedStrings: sharedStrings) ?? ""
            let volee            = getCellValueOptimized(cells, at: voleeCol, sharedStrings: sharedStrings) ?? ""
            let option           = getCellValueOptimized(cells, at: optionCol, sharedStrings: sharedStrings) ?? ""
            let enseignant       = getCellValueOptimized(cells, at: enseignantCol, sharedStrings: sharedStrings) ?? ""

            var salle = getCellValueOptimized(cells, at: salleCol, sharedStrings: sharedStrings) ?? ""
            if ["#REF!", "#N/A", "#VALUE!", "#DIV/0!", "#NAME?", "0"].contains(salle) { salle = "" }

            guard let selectedVolee = selectedVolee else { continue }
            guard matchesVoleeForExamens(volee: volee, modalite: modalite, option: option, selectedVolee: selectedVolee, selectedModalites: modalites) else { continue }

            if let selectedOption = selectedOption, !selectedOption.isEmpty {
                guard matchesOption(courseOption: option, selectedOption: selectedOption) else { continue }
            }

            var cours = coursRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            if cours.isEmpty || Int(cours) != nil {
                cours = "⚠️ Erreur de lecture du fichier Excel"
            }

            guard let date = parseDate(dateStr) else { continue }

            let heureComplete: String
            if !arriveeControle.isEmpty && arriveeControle != "Ø" {
                let arriveeFormatted = formatSingleHeureUniform(arriveeControle)
                if !heureDebut.isEmpty && !heureFin.isEmpty {
                    heureComplete = "Arrivée: \(arriveeFormatted) | Examen: \(formatSingleHeureUniform(heureDebut)) - \(formatSingleHeureUniform(heureFin))"
                } else {
                    heureComplete = "Arrivée: \(arriveeFormatted)"
                }
            } else {
                heureComplete = (!heureDebut.isEmpty && !heureFin.isEmpty)
                    ? formatHeure(debut: heureDebut, fin: heureFin)
                    : "Horaire non spécifié"
            }

            var contenuExamen = ""
            if !modalite.isEmpty      { contenuExamen += "📝 \(modalite)" }
            if !anonymisation.isEmpty { contenuExamen += (contenuExamen.isEmpty ? "" : "\n") + "🔒 Anonymisation: \(anonymisation)" }
            if !option.isEmpty        { contenuExamen += (contenuExamen.isEmpty ? "" : "\n") + "📚 \(option)" }

            scheduleItems.append(CourseSchedule(
                date: date,
                heure: heureComplete,
                cours: cours,
                salle: salle,
                enseignant: enseignant,
                duration: extractDuration(debut: heureDebut, fin: heureFin),
                color: colors[colorIndex % colors.count],
                contenuCours: contenuExamen,
                nombrePeriode: ""
            ))
            colorIndex += 1
        }

        return scheduleItems
    }

    // MARK: - Filtrage volée / modalité / option

    private static func matchesVoleeAndModalites(cursus: String, selectedVolee: String, modalites: [Modalite]) -> Bool {
        let cleanCursus = cursus.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSelected = selectedVolee.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !cleanCursus.isEmpty else { return false }

        for singleCursus in cleanCursus.components(separatedBy: "/").map({ $0.trimmingCharacters(in: .whitespaces) }) {
            let lower = singleCursus.lowercased()
            guard lower.contains(cleanSelected) else { continue }

            if modalites.count == 2 || lower.contains("tous") { return true }

            for modalite in modalites {
                switch modalite {
                case .tempsPlein:
                    if lower.contains("temps plein") || lower.contains("plein") { return true }
                case .partiel:
                    if lower.contains("partiel") { return true }
                }
            }
        }

        return false
    }

    private static func matchesVoleeForExamens(volee: String, modalite: String, option: String, selectedVolee: String, selectedModalites: [Modalite]) -> Bool {
        let cleanVolee    = volee.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanSelected = selectedVolee.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanModalite = modalite.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanOption   = option.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !cleanVolee.isEmpty else { return false }

        let voleeMatches = cleanVolee.components(separatedBy: CharacterSet(charactersIn: "/,"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .contains { $0.contains(cleanSelected) }

        guard voleeMatches else { return false }

        if cleanOption.contains("toutes orientations") || selectedModalites.count == 2 { return true }

        for selectedModalite in selectedModalites {
            switch selectedModalite {
            case .tempsPlein:
                if cleanVolee.contains("temps plein") || cleanVolee.contains("plein") ||
                   cleanModalite.contains("temps plein") || cleanModalite.contains("plein") { return true }
            case .partiel:
                if cleanVolee.contains("partiel") || cleanModalite.contains("partiel") { return true }
            }
        }

        // Pas de modalité spécifiée dans l'examen : accepter par défaut
        if cleanModalite.isEmpty && !cleanVolee.contains("temps plein") &&
           !cleanVolee.contains("plein") && !cleanVolee.contains("partiel") { return true }

        return false
    }

    /// Vérifie si l'option d'un cours correspond à l'option sélectionnée par l'étudiant.
    /// Les cours "Tous" / "Toutes orientations" sont toujours affichés.
    private static func matchesOption(courseOption: String, selectedOption: String) -> Bool {
        let cleanOption = courseOption.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowerClean  = cleanOption.lowercased()

        // Cours ouvert à toutes les orientations
        if cleanOption.isEmpty || lowerClean.contains("tous") || lowerClean.contains("toutes orientations") {
            return true
        }

        let selectedLower = selectedOption.lowercased()
        let parts = cleanOption.components(separatedBy: CharacterSet(charactersIn: "/,"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        return parts.contains { part in
            guard !part.isEmpty else { return false }
            let lowerPart = part.lowercased()
            if lowerPart == selectedLower || selectedLower.contains(lowerPart) || lowerPart.contains(selectedLower) { return true }
            if selectedLower.contains("primaire")  && (lowerPart == "primaires"   || lowerPart.contains("primaire"))  { return true }
            if selectedLower.contains("adulte")    && (lowerPart == "adultes"     || lowerPart.contains("adulte"))    { return true }
            if selectedLower.contains("enfant")    && (lowerPart == "pédiatriques" || lowerPart == "pediatriques" ||
                                                        lowerPart == "pédiatrie"   || lowerPart == "pediatrie" ||
                                                        lowerPart.contains("enfant"))                                  { return true }
            if selectedLower.contains("mentale")   && lowerPart.contains("mentale")                                   { return true }
            return false
        }
    }

    // MARK: - Lecture des cellules par référence de colonne
    //
    // CoreXLSX omet les cellules vides dans le tableau `cells`.
    // On lit donc par référence de colonne (A, B, C…) plutôt que par index positionnel,
    // ce qui évite tout décalage lors de cellules fusionnées ou vides.

    private static func getCellValueOptimized(_ cells: [Cell], at index: Int, sharedStrings: SharedStrings?) -> String? {
        let columnLetter = columnIndexToLetter(index)
        guard let columnRef = ColumnReference(columnLetter),
              let cell = cells.first(where: { $0.reference.column == columnRef }) else {
            return nil
        }

        if let sharedStrings = sharedStrings, let stringValue = cell.stringValue(sharedStrings) {
            return stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Fallback richText pour les shared strings mal parsées
        if let sharedStrings = sharedStrings,
           cell.type == .sharedString,
           let valueString = cell.value,
           let idx = Int(valueString),
           idx < sharedStrings.items.count {

            let item = sharedStrings.items[idx]

            if !item.richText.isEmpty {
                let fullText = item.richText.compactMap { $0.text }.joined()
                if !fullText.isEmpty { return fullText.trimmingCharacters(in: .whitespacesAndNewlines) }
            }

            if let simpleText = item.text {
                return simpleText.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return cell.value?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func getDateCellValue(_ cells: [Cell], at index: Int, sharedStrings: SharedStrings?) -> String? {
        let columnLetter = columnIndexToLetter(index)
        guard let columnRef = ColumnReference(columnLetter),
              let cell = cells.first(where: { $0.reference.column == columnRef }) else {
            return nil
        }

        if let sharedStrings = sharedStrings, let stringValue = cell.stringValue(sharedStrings) {
            return stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let inlineString = cell.inlineString {
            return inlineString.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return cell.value?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Convertit un index de colonne (0-based) en lettre Excel (0→A, 1→B, 25→Z, 26→AA…)
    private static func columnIndexToLetter(_ index: Int) -> String {
        var result = ""
        var n = index
        repeat {
            result = String(UnicodeScalar(65 + (n % 26))!) + result
            n = n / 26 - 1
        } while n >= 0
        return result
    }

    // MARK: - Parsing de date (serial number Excel uniquement)

    private static func parseDate(_ dateString: String) -> Date? {
        guard let serialNumber = Double(dateString) else { return nil }

        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        let referenceDate = DateComponents(calendar: utcCalendar, year: 1899, month: 12, day: 30)
        guard let excelEpoch = utcCalendar.date(from: referenceDate) else { return nil }

        return utcCalendar.date(byAdding: .day, value: Int(serialNumber), to: excelEpoch)
    }

    // MARK: - Formatage des heures

    private static func formatHeure(debut: String, fin: String) -> String {
        "\(formatSingleHeureUniform(debut)) - \(formatSingleHeureUniform(fin))"
    }

    private static func formatSingleHeureUniform(_ heure: String) -> String {
        let cleaned = heure.trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return "00:00" }

        if cleaned.contains("."), let doubleValue = Double(cleaned) {
            let hours = Int(doubleValue)
            let decimalString = String(format: "%.1f", doubleValue - Double(hours))
            if let dotIndex = decimalString.firstIndex(of: "."),
               decimalString.count > dotIndex.utf16Offset(in: decimalString) + 1,
               let minuteDigit = Int(String(decimalString[decimalString.index(after: dotIndex)])) {
                return String(format: "%02d:%02d", hours, minuteDigit * 10)
            }
            return String(format: "%02d:00", hours)
        }

        if cleaned.contains(":") {
            let parts = cleaned.components(separatedBy: ":")
            if parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) {
                return String(format: "%02d:%02d", h, m)
            }
        }

        if let hour = Int(cleaned) { return String(format: "%02d:00", hour) }

        return cleaned
    }

    private static func extractDuration(debut: String, fin: String) -> String {
        func toMinutes(_ s: String) -> Int? {
            let c = s.trimmingCharacters(in: .whitespaces)
            if c.contains(":") {
                let parts = c.components(separatedBy: ":")
                guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
                return h * 60 + m
            }
            if c.contains("."), let d = Double(c) {
                let h = Int(d)
                let decStr = String(format: "%.1f", d - Double(h))
                if let dotIdx = decStr.firstIndex(of: "."),
                   let digit = Int(String(decStr[decStr.index(after: dotIdx)])) {
                    return h * 60 + digit * 10
                }
                return h * 60
            }
            if let h = Int(c) { return h * 60 }
            return nil
        }

        guard let start = toMinutes(debut), let end = toMinutes(fin) else { return "" }

        var total = end - start
        if total < 0 { total += 24 * 60 }
        guard total > 0 && total <= 24 * 60 else { return "" }

        let h = total / 60, m = total % 60
        if h > 0 && m > 0 { return "\(h)h\(m)min" }
        if h > 0 { return "\(h)h" }
        if m > 0 { return "\(m)min" }
        return ""
    }

    // MARK: - Date de mise à jour dans l'en-tête Excel

    static func extractUpdateDate(_ data: Data) -> Date? {
        guard let xlsx = try? XLSXFile(data: data),
              let firstWorkbook = try? xlsx.parseWorkbooks().first else { return nil }

        let worksheetPaths = (try? xlsx.parseWorksheetPathsAndNames(workbook: firstWorkbook)) ?? []
        guard let horairePath = worksheetPaths.first(where: { $0.name!.lowercased().contains("horaire") })?.path
              ?? worksheetPaths.first?.path else { return nil }

        guard let worksheet = try? xlsx.parseWorksheet(at: horairePath) else { return nil }

        let sharedStrings = try? xlsx.parseSharedStrings()
        let rows = worksheet.data?.rows ?? []

        guard let firstRow = rows.first else { return nil }

        for (index, _) in firstRow.cells.enumerated() {
            guard let value = getCellValueOptimized(firstRow.cells, at: index, sharedStrings: sharedStrings),
                  value.contains("2025") || value.contains("2024"),
                  let dateMatch = value.range(of: "\\d{2}\\.\\d{2}\\.\\d{4}", options: .regularExpression) else { continue }

            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM.yyyy"
            return formatter.date(from: String(value[dateMatch]))
        }

        return nil
    }

    // MARK: - Validation de la structure du fichier

    static func validateFileStructure(_ data: Data, fileType: FileType) throws -> Bool {
        guard let xlsx = try? XLSXFile(data: data),
              let firstWorkbook = try? xlsx.parseWorkbooks().first else { return false }

        let worksheetPaths = try xlsx.parseWorksheetPathsAndNames(workbook: firstWorkbook)
        guard worksheetPaths.first(where: { $0.name!.lowercased().contains("horaire") }) != nil else { return false }

        if fileType == .cours {
            guard worksheetPaths.first(where: {
                $0.name!.lowercased().contains("menu") ||
                $0.name!.lowercased().contains("déroulant") ||
                $0.name!.lowercased().contains("deroulant")
            }) != nil else { return false }
        }

        switch fileType {
        case .cours:    return try validateCoursStructure(xlsx, workbook: firstWorkbook)
        case .examens:  return try validateExamensStructure(xlsx, workbook: firstWorkbook)
        }
    }

    private static func validateCoursStructure(_ xlsx: XLSXFile, workbook: Workbook) throws -> Bool {
        let paths = try xlsx.parseWorksheetPathsAndNames(workbook: workbook)
        guard let path = paths.first(where: { $0.name!.lowercased().contains("horaire") })?.path else { return false }
        let rows = (try? xlsx.parseWorksheet(at: path))?.data?.rows ?? []
        return rows.count >= 3 && (rows.first?.cells.count ?? 0) >= 11
    }

    private static func validateExamensStructure(_ xlsx: XLSXFile, workbook: Workbook) throws -> Bool {
        let paths = try xlsx.parseWorksheetPathsAndNames(workbook: workbook)
        guard let path = paths.first(where: { $0.name!.lowercased().contains("horaire") })?.path else { return false }
        let rows = (try? xlsx.parseWorksheet(at: path))?.data?.rows ?? []
        return rows.count >= 4 && (rows.dropFirst(3).first?.cells.count ?? 0) >= 12
    }
}
