// Views/Components/ErrorView.swift

import SwiftUI

struct ErrorView: View {
    let message: String
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(Color(white: 0.7))
                .padding(.horizontal)
            Button("Réessayer", action: retry)
                .buttonStyle(.bordered)
        }
        .padding()
    }
}
