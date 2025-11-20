// Views/Components/OfflineBanner.swift

import SwiftUI

struct OfflineBanner: View {
    let lastUpdate: Date?
    let isOffline: Bool
    let onRefresh: () -> Void
    
    var formattedDate: String {
        guard let date = lastUpdate else { return "Jamais" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: date)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            if isOffline {
                Image(systemName: "wifi.slash")
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mode hors ligne")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Text("Dernière mise à jour: \(formattedDate)")
                        .font(.system(size: 11))
                        .foregroundColor(Color(white: 0.7))
                }
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Horaires à jour")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Text("Mis à jour: \(formattedDate)")
                        .font(.system(size: 11))
                        .foregroundColor(Color(white: 0.7))
                }
            }
            
            Spacer()
            
            // Bouton de rechargement
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(isOffline ? Color(red: 255/255, green: 246/255, blue: 230/255) : Color(red: 233/255, green: 250/255, blue: 239/255))
    }
}
