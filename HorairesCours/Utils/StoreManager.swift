// Utils/StoreManager.swift

import StoreKit
import SwiftUI

@MainActor
class StoreManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var isPurchasing = false
    @Published var purchaseSuccess = false
    @Published var errorMessage: String?
    
    // Tes product IDs — adapte selon ce que tu as créé dans App Store Connect
    private let productIDs = [
        "ch.smeusling.HorairesCours.don1",
        "ch.smeusling.HorairesCours.don2",
        "ch.smeusling.HorairesCours.don5"
    ]
    
    init() {
        Task { await loadProducts() }
    }
    
    func loadProducts() async {
        do {
            products = try await Product.products(for: productIDs)
                .sorted { $0.price < $1.price }
            LogManager.shared.log("✅ \(products.count) produits IAP chargés")
        } catch {
            LogManager.shared.log("❌ Erreur chargement produits IAP: \(error)")
        }
    }
    
    func purchase(_ product: Product) async {
        isPurchasing = true
        errorMessage = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    purchaseSuccess = true
                    LogManager.shared.log("✅ Don réussi: \(product.displayName)")
                case .unverified:
                    errorMessage = "Transaction non vérifiée"
                }
            case .userCancelled:
                LogManager.shared.log("ℹ️ Don annulé par l'utilisateur")
            case .pending:
                LogManager.shared.log("⏳ Don en attente")
            @unknown default:
                break
            }
        } catch {
            errorMessage = "Erreur: \(error.localizedDescription)"
            LogManager.shared.log("❌ Erreur achat: \(error)")
        }
        
        isPurchasing = false
    }
}
