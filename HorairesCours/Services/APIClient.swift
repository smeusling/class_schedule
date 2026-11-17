//
//  APIClient.swift
//  HorairesCours
//
//  Created by Stéphanie Meusling on 17.11.2026.
//

import Foundation

// MARK: - Réponses de l'API (https://horaires-api.fly.dev/documentation)

/// Un choix proposé pour une volée : modalité ou option (identifiant de l'API + libellé affiché).
struct APIChoice: Decodable, Hashable {
    let id: String      // ex. "tempsPartiel6", "santeMentale"
    let label: String   // ex. "Temps partiel 6 semestres", "Santé mentale"
}

/// Une volée et les choix qui la concernent (GET /api/volees).
struct APIVolee: Decodable, Hashable {
    let volee: String          // ex. "IPS 2025"
    let modalites: [APIChoice]
    let options: [APIChoice]
}

/// Un cours (GET /api/schedule).
struct APICours: Decodable {
    let cours: String
    let contenuCours: String
    let volee: String
    let option: String
    let enseignant: String
    let salle: String
    let date: String?        // AAAA-MM-JJ
    let heureDebut: String?  // HH:MM
    let heureFin: String?    // HH:MM
}

/// Un examen (GET /api/exams).
struct APIExamen: Decodable {
    let cours: String
    let modaliteExamen: String   // forme de l'examen, ex. "Oral individuel" (rien à voir avec la modalité temps plein / partiel)
    let anonymisation: String    // "Oui", "Non" ou ""
    let volee: String
    let option: String
    let enseignant: String
    let salle: String
    let date: String?            // AAAA-MM-JJ
    let heureDebut: String?      // HH:MM, absente pour les travaux à rendre
    let heureFin: String?
    let heureArrivee: String?    // HH:MM, arrivée pour le contrôle d'identité
}

struct APIScheduleResponse: Decodable {
    let dateFichier: String?     // AAAA-MM-JJ, date du fichier publié par l'UNIL
    let cours: [APICours]
}

struct APIExamsResponse: Decodable {
    let dateFichier: String?
    let examens: [APIExamen]
}

/// Corps des réponses d'erreur de l'API : { error } ou { error, message } (404).
private struct APIErrorBody: Decodable {
    let error: String
    let message: String?
}

// MARK: - Erreurs

enum APIError: LocalizedError {
    case notAvailable(String)   // 404 : horaire pas encore publié (message de l'API)
    case server                 // autre réponse que 200 ou 404
    case network                // pas de connexion, serveur injoignable
    case timeout                // pas de réponse dans le délai
    case invalidResponse        // réponse illisible

    var errorDescription: String? {
        switch self {
        case .notAvailable(let message):
            return message
        case .server:
            return "Le serveur des horaires a rencontré un problème. Veuillez réessayer plus tard."
        case .network:
            return "Impossible de joindre le serveur des horaires. Vérifiez votre connexion."
        case .timeout:
            return "Le serveur des horaires met trop de temps à répondre. Veuillez réessayer."
        case .invalidResponse:
            return "La réponse du serveur des horaires est illisible."
        }
    }
}

// MARK: - Semestre au format de l'API

extension SemestreType {
    /// Valeur du paramètre "semestre" de l'API.
    var apiValue: String {
        switch self {
        case .automne:   return "automne"
        case .printemps: return "printemps"
        }
    }
}

// MARK: - Client

enum APIClient {
    static let baseURL = "https://horaires-api.fly.dev"

    /// 20 secondes : le premier appel après une période sans trafic réveille le serveur (quelques secondes).
    private static let timeout: TimeInterval = 20

    /// Volées du semestre, avec leurs modalités et options (catalogue des cours, utilisé aussi pour les examens).
    static func fetchVolees(semestre: SemestreType) async throws -> [APIVolee] {
        try await get("/api/volees", query: [URLQueryItem(name: "semestre", value: semestre.apiValue)])
    }

    /// Cours d'une volée, filtrés par modalité et option (facultatives, identifiants de l'API).
    static func fetchSchedule(semestre: SemestreType, volee: String, modalite: String?, option: String?) async throws -> APIScheduleResponse {
        try await get("/api/schedule", query: selectionQuery(semestre: semestre, volee: volee, modalite: modalite, option: option))
    }

    /// Examens d'une volée, mêmes paramètres que fetchSchedule.
    static func fetchExams(semestre: SemestreType, volee: String, modalite: String?, option: String?) async throws -> APIExamsResponse {
        try await get("/api/exams", query: selectionQuery(semestre: semestre, volee: volee, modalite: modalite, option: option))
    }

    // Paramètres communs à /api/schedule et /api/exams.
    private static func selectionQuery(semestre: SemestreType, volee: String, modalite: String?, option: String?) -> [URLQueryItem] {
        var items = [
            URLQueryItem(name: "semestre", value: semestre.apiValue),
            URLQueryItem(name: "volee", value: volee)
        ]
        if let modalite { items.append(URLQueryItem(name: "modalite", value: modalite)) }
        if let option { items.append(URLQueryItem(name: "option", value: option)) }
        return items
    }

    private static func get<T: Decodable>(_ path: String, query: [URLQueryItem]) async throws -> T {
        guard var components = URLComponents(string: baseURL + path) else { throw APIError.invalidResponse }
        components.queryItems = query
        guard let url = components.url else { throw APIError.invalidResponse }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            LogManager.shared.log("⏱️ API : délai dépassé pour \(url.absoluteString)")
            throw APIError.timeout
        } catch {
            LogManager.shared.log("❌ API : erreur réseau pour \(url.absoluteString) : \(error.localizedDescription)")
            throw APIError.network
        }

        guard let httpResponse = response as? HTTPURLResponse else { throw APIError.invalidResponse }

        switch httpResponse.statusCode {
        case 200:
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                LogManager.shared.log("❌ API : réponse illisible pour \(url.absoluteString) : \(error)")
                throw APIError.invalidResponse
            }
        case 404:
            let body = try? JSONDecoder().decode(APIErrorBody.self, from: data)
            LogManager.shared.log("ℹ️ API : 404 pour \(url.absoluteString) : \(body?.message ?? body?.error ?? "?")")
            throw APIError.notAvailable(body?.message ?? "Horaire non disponible.")
        default:
            LogManager.shared.log("❌ API : statut \(httpResponse.statusCode) pour \(url.absoluteString)")
            throw APIError.server
        }
    }
}
