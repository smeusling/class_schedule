// Views/Components/WeekNavigationHeader.swift

import SwiftUI

struct WeekNavigationHeader: View {
    @ObservedObject var viewModel: ScheduleViewModel

    var dateRange: String {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: viewModel.selectedDate) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMM"
        let start = formatter.string(from: weekInterval.start)
        let end = calendar.date(byAdding: .day, value: 6, to: weekInterval.start)!
        return "\(start) - \(formatter.string(from: end))"
    }

    var body: some View {
        HStack(spacing: 16) {
            Button(action: {
                viewModel.selectedDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: viewModel.selectedDate) ?? viewModel.selectedDate
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color(hex: "7B6FE8"))
                    .clipShape(Circle())
            }

            Spacer()

            Text(dateRange)
                .font(.system(size: 21, weight: .bold))
                .foregroundColor(.primary)

            Spacer()

            Button(action: {
                viewModel.selectedDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: viewModel.selectedDate) ?? viewModel.selectedDate
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color(hex: "7B6FE8"))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .padding(.bottom, 10)
        .padding(.top, 10)
        .background(Color.white)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}
