import SwiftUI

struct MonthCalendarView: View {
    @EnvironmentObject private var store: ScheduleStore

    let month: Date
    @Binding var selectedDate: Date

    private let calendar = Calendar.autoupdatingCurrent
    private let weekdaySymbols = ["月", "火", "水", "木", "金", "土", "日"]

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                    Text(symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(weekdayColor(for: index))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 2)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(Array(makeDays().enumerated()), id: \.offset) { _, day in
                    if let date = day {
                        let indicators = store.indicatorCounts(on: date)
                        DayCellView(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            entryCount: store.entryCount(on: date),
                            hasExam: indicators.exam > 0,
                            practicalCount: indicators.practical,
                            normalCount: indicators.normal
                        )
                        .onTapGesture {
                            selectedDate = date
                        }
                    } else {
                        Color.clear
                            .frame(height: 56)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(red: 0.87, green: 0.89, blue: 0.93), lineWidth: 1)
        }
    }

    private func weekdayColor(for index: Int) -> Color {
        if index == 5 {
            return Color(red: 0.12, green: 0.43, blue: 0.89)
        }
        if index == 6 {
            return Color(red: 0.85, green: 0.26, blue: 0.27)
        }
        return Color(red: 0.45, green: 0.49, blue: 0.55)
    }

    private func makeDays() -> [Date?] {
        guard
            let dayRange = calendar.range(of: .day, in: .month, for: month),
            let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else {
            return []
        }

        let weekday = calendar.component(.weekday, from: firstDay)
        let mondayBasedOffset = (weekday + 5) % 7

        var values = Array(repeating: Optional<Date>.none, count: mondayBasedOffset)
        values.append(contentsOf: dayRange.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: firstDay)
        })

        let remainder = values.count % 7
        if remainder != 0 {
            values.append(contentsOf: Array(repeating: Optional<Date>.none, count: 7 - remainder))
        }

        return values
    }
}
