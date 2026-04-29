import Foundation

struct ClassEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var date: Date
    var period: Int
    var periodDisplay: String?
    var subject: String
    var location: String
    var isExam: Bool
    var customTimeRange: String?

    init(
        id: UUID = UUID(),
        date: Date,
        period: Int,
        periodDisplay: String? = nil,
        subject: String,
        location: String,
        isExam: Bool,
        customTimeRange: String? = nil
    ) {
        self.id = id
        self.date = date
        self.period = period
        self.periodDisplay = periodDisplay
        self.subject = subject
        self.location = location
        self.isExam = isExam
        self.customTimeRange = customTimeRange
    }

    var periodTitle: String {
        periodDisplay ?? "\(period)限"
    }

    var timeRange: String {
        if let customTimeRange {
            return customTimeRange
        }

        return switch period {
        case 1: "08:45 - 10:15"
        case 2: "10:30 - 12:00"
        case 3: "12:50 - 14:20"
        case 4: "14:35 - 16:05"
        case 5: "16:20 - 17:50"
        case 6: "18:00 - 19:30"
        case 7: "19:40 - 21:10"
        case 8: "21:20 - 22:50"
        case 9: "16:20 - 17:05"
        case 10: "17:05 - 17:50"
        default: "時間未設定"
        }
    }
}
