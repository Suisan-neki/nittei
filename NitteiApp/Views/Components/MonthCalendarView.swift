import SwiftUI

struct MonthCalendarView: View {
    @EnvironmentObject private var store: ScheduleStore

    let month: Date
    @Binding var selectedDate: Date

    private let calendar = Calendar.autoupdatingCurrent
    private let weekdaySymbols = ["月", "火", "水", "木", "金", "土", "日"]

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(Color(red: 0.43, green: 0.47, blue: 0.52))
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 7), spacing: 10) {
                ForEach(Array(makeDays().enumerated()), id: \.offset) { _, day in
                    if let date = day {
                        DayCellView(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            entryCount: store.entryCount(on: date),
                            hasExam: store.hasExam(on: date)
                        )
                        .onTapGesture {
                            selectedDate = date
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.clear)
                            .frame(height: 74)
                    }
                }
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.68), lineWidth: 1.2)
        }
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
