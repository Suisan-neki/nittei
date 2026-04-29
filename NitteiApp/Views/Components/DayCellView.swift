import SwiftUI

struct DayCellView: View {
    let date: Date
    let isSelected: Bool
    let entryCount: Int
    let examCount: Int
    let practicalCount: Int
    let normalCount: Int
    let calendar: Calendar

    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()

    private enum Palette {
        static let selectionBlue = Color(red: 0.10, green: 0.47, blue: 0.95)
        static let sundayRed = Color(red: 0.85, green: 0.26, blue: 0.27)
        static let saturdayBlue = Color(red: 0.12, green: 0.43, blue: 0.89)
        static let weekdayText = Color(red: 0.18, green: 0.21, blue: 0.26)
        static let practicalYellow = Color(red: 0.95, green: 0.72, blue: 0.12)
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(dayFormatter.string(from: date))
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 30, height: 30)
                .foregroundStyle(dayNumberColor)
                .background {
                    if isSelected {
                        Circle().fill(Palette.selectionBlue)
                    } else if isToday {
                        Circle().stroke(Palette.selectionBlue, lineWidth: 1.4)
                    }
                }

            HStack(spacing: 3) {
                ForEach(Array(displayDotColors.enumerated()), id: \.offset) { _, color in
                    Circle()
                        .fill(color)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .contentShape(Rectangle())
    }

    private var isToday: Bool {
        calendar.isDateInToday(date)
    }

    private var dayNumberColor: Color {
        if isSelected {
            return .white
        }
        let weekday = calendar.component(.weekday, from: date)
        if weekday == 1 {
            return Palette.sundayRed
        }
        if weekday == 7 {
            return Palette.saturdayBlue
        }
        return Palette.weekdayText
    }

    private var displayDotCount: Int {
        min(entryCount, 3)
    }

    private var displayDotColors: [Color] {
        guard displayDotCount > 0 else { return [] }

        let red = Array(repeating: Palette.sundayRed, count: examCount)
        let yellow = Array(repeating: Palette.practicalYellow, count: practicalCount)
        let blue = Array(repeating: Palette.selectionBlue, count: normalCount)
        let merged = red + yellow + blue
        if merged.isEmpty {
            return Array(repeating: Palette.selectionBlue, count: displayDotCount)
        }
        return Array(merged.prefix(displayDotCount))
    }
}
