import SwiftUI

struct DayCellView: View {
    let date: Date
    let isSelected: Bool
    let entryCount: Int
    let hasExam: Bool
    let practicalCount: Int
    let normalCount: Int

    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
    private let calendar = Calendar.autoupdatingCurrent

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Text(dayFormatter.string(from: date))
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .foregroundStyle(dayNumberColor)
                    .background {
                        if isSelected {
                            Circle().fill(Color(red: 0.10, green: 0.47, blue: 0.95))
                        } else if isToday {
                            Circle().stroke(Color(red: 0.10, green: 0.47, blue: 0.95), lineWidth: 1.4)
                        }
                    }

                if hasExam {
                    Circle()
                        .fill(Color(red: 0.85, green: 0.26, blue: 0.27))
                        .frame(width: 6, height: 6)
                        .offset(x: 2, y: 2)
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
            return Color(red: 0.85, green: 0.26, blue: 0.27)
        }
        if weekday == 7 {
            return Color(red: 0.12, green: 0.43, blue: 0.89)
        }
        return Color(red: 0.18, green: 0.21, blue: 0.26)
    }

    private var displayDotCount: Int {
        min(entryCount, 3)
    }

    private var displayDotColors: [Color] {
        guard displayDotCount > 0 else { return [] }

        if hasExam {
            return Array(repeating: Color(red: 0.85, green: 0.26, blue: 0.27), count: displayDotCount)
        }

        let yellow = Array(repeating: Color(red: 0.95, green: 0.72, blue: 0.12), count: practicalCount)
        let blue = Array(repeating: Color(red: 0.10, green: 0.47, blue: 0.95), count: normalCount)
        let merged = yellow + blue
        if merged.isEmpty {
            return Array(repeating: Color(red: 0.10, green: 0.47, blue: 0.95), count: displayDotCount)
        }
        return Array(merged.prefix(displayDotCount))
    }
}
