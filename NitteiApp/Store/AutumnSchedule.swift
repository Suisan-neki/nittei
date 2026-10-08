import Foundation

/// 2026/9/11版の歯学科時間割、3年生の第3・第4ターム。
/// 授業期間末尾の試験期間もPDFの範囲どおり登録し、個別試験は別途追加する。
/// 臨床見学演習・実習Ⅱは、2026年10月配布のB班ローテーション表で判明した日程を追加する。
enum AutumnSchedule {
    private struct Lesson {
        let code: Int
        let firstDay: Int
        let lastDay: Int
        let weekday: Int
        let period: Int
        let lastPeriod: Int
        let subject: String
        let location: String
        let onlyDays: Set<Int>?

        init(_ code: Int, _ firstDay: Int, _ lastDay: Int, _ weekday: Int,
             _ period: Int, _ lastPeriod: Int, _ subject: String, _ location: String,
             onlyDays: Set<Int>? = nil) {
            self.code = code
            self.firstDay = firstDay
            self.lastDay = lastDay
            self.weekday = weekday
            self.period = period
            self.lastPeriod = lastPeriod
            self.subject = subject
            self.location = location
            self.onlyDays = onlyDays
        }
    }

    private struct FixedLesson {
        let code: Int
        let day: Int
        let period: Int
        let periodDisplay: String
        let subject: String
        let location: String
        let customTimeRange: String

        init(_ code: Int, _ day: Int, _ period: Int, _ periodDisplay: String,
             _ subject: String, _ location: String, _ customTimeRange: String) {
            self.code = code
            self.day = day
            self.period = period
            self.periodDisplay = periodDisplay
            self.subject = subject
            self.location = location
            self.customTimeRange = customTimeRange
        }
    }

    private static let lessons: [Lesson] = [
        Lesson(301, 20261005, 20261130, 2, 1, 2, "顎機能学", "1講（D棟4F）"),
        Lesson(302, 20261005, 20261130, 2, 3, 4, "歯科放射線学Ⅱ", "1講（D棟4F）"),
        Lesson(303, 20261006, 20261201, 3, 1, 1, "歯周病学Ⅰ", "1講（D棟4F）"),
        Lesson(304, 20261006, 20261201, 3, 2, 2, "補綴学Ⅰ", "1講（D棟4F）"),
        Lesson(305, 20261006, 20261201, 3, 3, 4, "衛生学・口腔衛生学基礎実習Ⅰ", "1実（D棟1F）"),
        Lesson(306, 20261007, 20261125, 4, 1, 2, "義歯補綴学Ⅰ", "1講（D棟4F）"),
        Lesson(307, 20261007, 20261125, 4, 3, 4, "歯科麻酔学", "7講（A棟6F）"),
        Lesson(308, 20261008, 20261126, 5, 1, 1, "歯内療法学Ⅰ", "7講（A棟6F）"),
        Lesson(309, 20261008, 20261126, 5, 2, 2, "保存修復学Ⅰ", "7講（A棟6F）"),
        Lesson(310, 20261002, 20261127, 6, 1, 2, "診断・検査学", "7講（A棟6F）"),
        Lesson(401, 20261207, 20270208, 2, 1, 2, "歯周病学Ⅱ", "1講（D棟4F）"),
        Lesson(402, 20261207, 20270208, 2, 3, 4, "歯科放射線学基礎演習", "7講・CST（A棟6F・A棟3F）"),
        Lesson(403, 20261208, 20270202, 3, 1, 2, "補綴学Ⅱ", "1講（D棟4F）"),
        Lesson(404, 20261208, 20270202, 3, 3, 4, "衛生学・口腔衛生学基礎実習Ⅱ", "1実（D棟1F）"),
        Lesson(405, 20261202, 20270203, 4, 1, 1, "社会福祉学", "大講（A棟6F）"),
        Lesson(406, 20261202, 20270203, 4, 2, 2, "特別科目（情報）", "大講（A棟6F）"),
        Lesson(407, 20261202, 20270203, 4, 3, 4, "歯科麻酔学基礎演習", "7講（A棟6F）"),
        Lesson(408, 20261203, 20270204, 5, 1, 1, "歯内療法学Ⅱ", "7講（A棟6F）"),
        Lesson(409, 20261203, 20270204, 5, 2, 2, "保存修復学Ⅱ", "7講（A棟6F）"),
        Lesson(410, 20261204, 20270205, 6, 1, 1, "社会歯科学", "大講（A棟6F）"),
        Lesson(411, 20261204, 20270205, 6, 2, 2, "義歯補綴学Ⅱ", "7講（A棟6F）"),
        Lesson(412, 20261204, 20270205, 6, 3, 3, "特別科目", "7講（A棟6F）",
               onlyDays: [20261204, 20270108, 20270122, 20270129, 20270205]),
        Lesson(413, 20261204, 20270205, 6, 4, 4, "特別科目", "7講（A棟6F）",
               onlyDays: [20270122, 20270129, 20270205]),
        Lesson(414, 20270129, 20270129, 6, 5, 5, "歯周病学Ⅱ", "7講（A棟6F）")
    ]

    private static let fixedLessons: [FixedLesson] = [
        FixedLesson(3501, 20261008, 3, "3・4限",
                    "臨床見学演習・実習Ⅱ（B班）：歯周", "歯周", "13:30 - 16:05"),
        FixedLesson(3502, 20261009, 3, "3・4限",
                    "臨床見学演習・実習Ⅱ（B班）：歯科放射線科",
                    "研究棟A 5階 歯科放射線学セミナー室（12:50集合）", "12:50 - 16:05"),
        FixedLesson(3503, 20261015, 3, "3・4限",
                    "臨床見学演習・実習Ⅱ（B班）：歯科保存", "歯科保存", "12:50 - 16:05"),
        FixedLesson(3504, 20261022, 3, "3・4限",
                    "臨床見学演習・実習Ⅱ（B班）：歯診", "歯診", "12:50 - 16:05"),
        FixedLesson(3505, 20261023, 3, "3・4限",
                    "臨床見学演習・実習Ⅱ（B班）：口腔検査センター",
                    "診療棟3階 口腔検査センター（白衣・13:45集合）", "13:45集合（3・4限）"),
        FixedLesson(3506, 20261029, 3, "3・4限",
                    "臨床見学演習・実習Ⅱ（B班）：障害者歯科", "障害者歯科", "12:50 - 16:05"),
        FixedLesson(3507, 20261105, 3, "3・4限",
                    "臨床見学演習・実習Ⅱ（B班）：小児歯科", "小児歯科", "12:50 - 16:05"),
        FixedLesson(3508, 20261112, 3, "3・4限",
                    "臨床見学演習・実習Ⅱ（B班）：矯正歯科", "矯正歯科", "12:50 - 16:05"),
        FixedLesson(3509, 20261119, 3, "3・4限",
                    "臨床見学演習・実習Ⅱ（B班）：咬合義歯", "咬合義歯", "12:50 - 16:05"),
        FixedLesson(3510, 20261120, 3, "3・4限",
                    "医療関連部門講義：矯正歯科・小児歯科", "第7講義室", "12:50 - 16:05"),
        FixedLesson(3511, 20261126, 3, "3・4限",
                    "臨床見学演習・実習Ⅱ（B班）：インプラント", "インプラント", "12:50 - 16:05"),
        FixedLesson(3512, 20261203, 3, "3・4限",
                    "臨床見学演習・実習Ⅱ（B班）：2口外", "2口外", "12:50 - 16:05"),
        FixedLesson(3513, 20261218, 3, "3・4限",
                    "臨床見学演習・実習Ⅱ（B班）：1口外", "1口外", "12:50 - 16:05")
    ]

    static func entries(calendar: Calendar) -> [ClassEntry] {
        let first = calendar.date(from: DateComponents(year: 2026, month: 10, day: 2))!
        let last = calendar.date(from: DateComponents(year: 2027, month: 2, day: 8))!
        var date = first
        var entries: [ClassEntry] = []

        while date <= last {
            let key = AcademicCalendar.dateKey(date, calendar: calendar)
            if let weekday = AcademicCalendar.teachingWeekday(on: date, calendar: calendar) {
                for lesson in lessons where lesson.weekday == weekday
                    && (lesson.firstDay...lesson.lastDay).contains(key)
                    && (lesson.onlyDays?.contains(key) ?? true) {
                    // 日付と科目枠に固定したUUIDで、起動や更新による重複を防ぐ。
                    let id = UUID(uuidString: String(format: "A0260000-0000-4000-8000-%08d%04d", key, lesson.code))!
                    let display = lesson.period == lesson.lastPeriod
                        ? "\(lesson.period)限" : "\(lesson.period)・\(lesson.lastPeriod)限"
                    let starts = [1: "08:45", 2: "10:30", 3: "12:50", 4: "14:35", 5: "16:20"]
                    let ends = [1: "10:15", 2: "12:00", 3: "14:20", 4: "16:05", 5: "17:50"]
                    entries.append(ClassEntry(
                        id: id, date: date, period: lesson.period, periodDisplay: display,
                        subject: lesson.subject, location: lesson.location, isExam: false,
                        customTimeRange: "\(starts[lesson.period]!) - \(ends[lesson.lastPeriod]!)"
                    ))
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }

        for lesson in fixedLessons {
            let lessonDate = calendar.date(from: DateComponents(
                year: lesson.day / 10000,
                month: lesson.day / 100 % 100,
                day: lesson.day % 100
            ))!
            let id = UUID(uuidString: String(
                format: "A0260000-0000-4000-8000-%08d%04d", lesson.day, lesson.code
            ))!
            entries.append(ClassEntry(
                id: id,
                date: lessonDate,
                period: lesson.period,
                periodDisplay: lesson.periodDisplay,
                subject: lesson.subject,
                location: lesson.location,
                isExam: false,
                customTimeRange: lesson.customTimeRange
            ))
        }

        return entries.sorted {
            if $0.date == $1.date {
                if $0.period == $1.period {
                    return $0.subject.localizedCompare($1.subject) == .orderedAscending
                }
                return $0.period < $1.period
            }
            return $0.date < $1.date
        }
    }
}
