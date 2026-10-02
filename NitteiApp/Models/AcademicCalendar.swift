import Foundation

/// 令和8年度学年暦。試験期間・補講予備日は、個別の試験・授業とは区別する。
enum AcademicCalendar {
    enum DayKind: Equatable {
        case ordinary, substitute, examPeriod, vacation, reserve, cancelled, holiday
    }

    static func dateKey(_ date: Date, calendar: Calendar) -> Int {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return (c.year ?? 0) * 10000 + (c.month ?? 0) * 100 + (c.day ?? 0)
    }

    // Calendarのweekday値（日曜=1）。この日の通常曜日の授業は行わない。
    static let substituteWeekdays = [
        20260501: 4, 20260507: 3, 20260714: 2,
        20261016: 2, 20270106: 3, 20270114: 2
    ]

    private static let holidays = [
        20260429: "昭和の日", 20260503: "憲法記念日", 20260504: "みどりの日",
        20260505: "こどもの日", 20260506: "振替休日", 20260720: "海の日",
        20260811: "山の日", 20260921: "敬老の日", 20260922: "国民の休日",
        20260923: "秋分の日", 20261012: "スポーツの日", 20261103: "文化の日",
        20261123: "勤労感謝の日", 20270101: "元日", 20270111: "成人の日",
        20270211: "建国記念の日", 20270223: "天皇誕生日"
    ]
    private static let reserveDays: Set<Int> = [
        20260530, 20260614, 20260719, 20260726, 20260808,
        20261128, 20261205, 20270131, 20270209
    ]

    static func vacationName(for key: Int) -> String? {
        switch key {
        case 20260401...20260407: "授業開始前"
        case 20260805...20261001: "夏季休業"
        case 20261226...20270105: "冬季休業"
        case 20270209...20270331: "学年末休業"
        default: nil
        }
    }

    static func examPeriodName(for key: Int) -> String? {
        switch key {
        case 20260602...20260608: "第1ターム試験期間"
        case 20260729...20260804: "第2ターム・前期セメスター試験期間"
        case 20261125...20261201: "第3ターム試験期間"
        case 20270202...20270208: "第4ターム・後期セメスター試験期間"
        default: nil
        }
    }

    static func kind(on date: Date, calendar: Calendar) -> DayKind {
        let key = dateKey(date, calendar: calendar)
        if substituteWeekdays[key] != nil { return .substitute }
        if reserveDays.contains(key) { return .reserve }
        if key == 20270115 { return .cancelled }
        if vacationName(for: key) != nil { return .vacation }
        if holidays[key] != nil { return .holiday }
        if examPeriodName(for: key) != nil { return .examPeriod }
        return .ordinary
    }

    static func teachingWeekday(on date: Date, calendar: Calendar) -> Int? {
        let key = dateKey(date, calendar: calendar)
        guard vacationName(for: key) == nil, holidays[key] == nil, key != 20270115 else {
            return nil
        }
        let weekday = substituteWeekdays[key] ?? calendar.component(.weekday, from: date)
        return (2...6).contains(weekday) ? weekday : nil
    }

    static func notes(on date: Date, calendar: Calendar) -> [String] {
        let key = dateKey(date, calendar: calendar)
        var notes: [String] = []
        if let weekday = substituteWeekdays[key] {
            let name = [2: "月曜日", 3: "火曜日", 4: "水曜日"][weekday] ?? ""
            notes.append("振替授業日：\(name)の授業")
        }
        if let name = vacationName(for: key) { notes.append(name) }
        if let name = holidays[key] { notes.append(name) }
        if let name = examPeriodName(for: key) {
            notes.append("\(name)（科目別の日程・実施有無はもみじ／担当教員の連絡を確認）")
        }
        if reserveDays.contains(key) {
            notes.append("補講（試験）予備日：実施の有無はもみじ／担当教員の連絡を確認")
        }
        if key == 20270115 { notes.append("共通テスト前日：3年生の金曜授業は休講") }

        return notes
    }
}
