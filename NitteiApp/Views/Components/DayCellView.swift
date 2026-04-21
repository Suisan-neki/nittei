import SwiftUI

struct DayCellView: View {
    let date: Date
    let isSelected: Bool
    let entryCount: Int
    let hasExam: Bool

    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(dayFormatter.string(from: date))
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(isSelected ? .white : Color(red: 0.16, green: 0.20, blue: 0.26))

                Spacer(minLength: 6)

                if hasExam {
                    Text("試")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.86, green: 0.21, blue: 0.22), in: Capsule())
                }
            }

            Spacer(minLength: 0)

            if entryCount > 0 {
                HStack(spacing: 6) {
                    Circle()
                        .fill(hasExam ? Color(red: 0.86, green: 0.21, blue: 0.22) : Color(red: 0.17, green: 0.58, blue: 0.48))
                        .frame(width: 8, height: 8)

                    Text("\(entryCount)件")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? .white.opacity(0.95) : Color(red: 0.33, green: 0.37, blue: 0.43))
                }
            } else {
                Text(" ")
                    .font(.caption2)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .topLeading)
        .background(backgroundStyle, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(borderColor, lineWidth: isSelected || hasExam ? 2 : 1)
        }
    }

    private var backgroundStyle: LinearGradient {
        if isSelected {
            return LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.40, blue: 0.58),
                    Color(red: 0.14, green: 0.64, blue: 0.67)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        if hasExam {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.95),
                    Color(red: 1.0, green: 0.93, blue: 0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [
                Color.white.opacity(0.92),
                Color.white.opacity(0.74)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var borderColor: Color {
        if isSelected {
            return Color.white.opacity(0.92)
        }
        if hasExam {
            return Color(red: 0.88, green: 0.41, blue: 0.38)
        }
        return Color.white.opacity(0.62)
    }
}
