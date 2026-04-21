import SwiftUI

struct DayScheduleView: View {
    let selectedDate: Date
    let entries: [ClassEntry]

    private let titleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日(E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(titleFormatter.string(from: selectedDate))
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(Color(red: 0.15, green: 0.18, blue: 0.24))
                }

                Spacer()

                if entries.contains(where: \.isExam) {
                    Label("試験あり", systemImage: "exclamationmark.circle.fill")
                        .font(.system(.footnote, design: .rounded, weight: .heavy))
                        .foregroundStyle(Color(red: 0.82, green: 0.17, blue: 0.18))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(red: 1.0, green: 0.93, blue: 0.92), in: Capsule())
                }
            }

            if entries.isEmpty {
                emptyState
            } else {
                VStack(spacing: 12) {
                    ForEach(entries) { entry in
                        ScheduleCard(entry: entry)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1.2)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("予定なし")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(Color(red: 0.20, green: 0.24, blue: 0.30))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.98, blue: 0.95),
                    Color(red: 0.93, green: 0.96, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
    }
}

private struct ScheduleCard: View {
    let entry: ClassEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 6) {
                Text(entry.periodTitle)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                Text(entry.timeRange)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(red: 0.36, green: 0.40, blue: 0.47))
            }
            .frame(width: 82)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(entry.subject)
                        .font(.system(.headline, design: .rounded, weight: .heavy))
                        .foregroundStyle(Color(red: 0.13, green: 0.17, blue: 0.23))

                    if entry.isExam {
                        Text("TEST")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color(red: 0.85, green: 0.21, blue: 0.21), in: Capsule())
                    }
                }

                Label(entry.location, systemImage: "mappin.and.ellipse")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(Color(red: 0.33, green: 0.37, blue: 0.44))
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var cardBackground: LinearGradient {
        if entry.isExam {
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.95, blue: 0.94),
                    Color(red: 1.0, green: 0.88, blue: 0.86)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [
                Color(red: 0.94, green: 0.98, blue: 0.96),
                Color(red: 0.90, green: 0.95, blue: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
