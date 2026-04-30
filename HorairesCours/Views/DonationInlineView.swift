// Views/DonationInlineView.swift

import SwiftUI

struct DonationInlineView: View {
    @ObservedObject var storeManager: StoreManager
    let onBack: () -> Void
    
    
    
    var body: some View {
        VStack(spacing: 16) {
            
            // Icône + message
            VStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 30))
                    .foregroundColor(Color(hex: "F57667"))
                
                Text("Merci pour votre soutien !")
                    .font(.system(size: 15, weight: .semibold))
                
                Text("Ce don aide à maintenir et améliorer l'application.")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            Divider()
            
            // Produits
            if storeManager.products.isEmpty {
                ProgressView().scaleEffect(1.2).padding()
            } else {
                HStack(spacing: 12) {
                    ForEach(Array(storeManager.products.enumerated()), id: \.element.id) { index, product in
                        Button(action: {
                            Task { await storeManager.purchase(product) }
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                                
                                Text(product.displayPrice)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(donColor(for: index))
                            .cornerRadius(14)
                        }
                        .disabled(storeManager.isPurchasing)
                    }
                }
            }
            
            // Succès
            if storeManager.purchaseSuccess {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Merci pour votre don ! ❤️")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.green)
                }
                .padding(10)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Erreur
            if let error = storeManager.errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
            
            Text("Les achats sont traités par Apple.\nApple prend 15% de commission.")
                .font(.system(size: 11))
                .foregroundColor(.gray.opacity(0.5))
                .multilineTextAlignment(.center)
        }
    }
    
    private func donColor(for index: Int) -> Color {
        switch index {
        case 0: return Color(hex: "7476D8") // violet
        case 1: return Color(hex: "40B5B2") // teal
        case 2: return Color(hex: "F57667") // rouge
        default: return Color(hex: "7476D8")
        }
    }
}
