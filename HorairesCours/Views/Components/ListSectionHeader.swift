// Views/Components/ListSectionHeader.swift

import SwiftUI

struct ListSectionHeader: View {
    let date: Date
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: date)
    }
    
    var body: some View {
        Text(formattedDate)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.gray)
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.95, green: 0.95, blue: 0.97))
    }
}
