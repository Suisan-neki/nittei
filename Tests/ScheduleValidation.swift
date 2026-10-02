import Foundation

@main
struct ScheduleValidation {
    @MainActor
    static func main() throws {
        // 端末の地域設定が異なっても、それぞれの現地日付で同じ時間割になること。
        for zone in ["Asia/Tokyo", "UTC", "America/Los_Angeles"] {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: zone)!
            let entries = AutumnSchedule.entries(calendar: calendar)
            func date(_ key: Int) -> Date {
                calendar.date(from: DateComponents(year: key / 10000, month: key / 100 % 100, day: key % 100))!
            }
            func subjects(_ key: Int) -> [String] {
                entries.filter { calendar.isDate($0.date, inSameDayAs: date(key)) }.map(\.subject)
            }
            func expect(_ key: Int, _ expected: [String]) {
                precondition(subjects(key) == expected, "\(zone) \(key): \(subjects(key))")
            }
            expect(20261002, ["診断・検査学"])
            expect(20261005, ["顎機能学", "歯科放射線学Ⅱ"])
            expect(20261006, ["歯周病学Ⅰ", "補綴学Ⅰ", "衛生学・口腔衛生学基礎実習Ⅰ"])
            expect(20261016, ["顎機能学", "歯科放射線学Ⅱ"])
            expect(20261201, ["歯周病学Ⅰ", "補綴学Ⅰ", "衛生学・口腔衛生学基礎実習Ⅰ"])
            expect(20261202, ["社会福祉学", "特別科目（情報）", "歯科麻酔学基礎演習"])
            expect(20261204, ["社会歯科学", "義歯補綴学Ⅱ", "特別科目"])
            expect(20261211, ["社会歯科学", "義歯補綴学Ⅱ"])
            expect(20270106, ["補綴学Ⅱ", "衛生学・口腔衛生学基礎実習Ⅱ"])
            expect(20270114, ["歯周病学Ⅱ", "歯科放射線学基礎演習"])
            expect(20270122, ["社会歯科学", "義歯補綴学Ⅱ", "特別科目", "特別科目"])
            expect(20270129, ["社会歯科学", "義歯補綴学Ⅱ", "特別科目", "特別科目", "歯周病学Ⅱ"])
            expect(20270205, ["社会歯科学", "義歯補綴学Ⅱ", "特別科目", "特別科目"])
            expect(20270208, ["歯周病学Ⅱ", "歯科放射線学基礎演習"])
            for key in [20261003, 20261012, 20261103, 20261123, 20261128,
                        20261205, 20261228, 20270101, 20270105, 20270111,
                        20270115, 20270131, 20270209] { expect(key, []) }
            precondition(entries.allSatisfy { !$0.isExam })
            precondition(Set(entries.map(\.id)).count == entries.count)
            precondition(entries.map(\.id) == AutumnSchedule.entries(calendar: calendar).map(\.id))
            precondition(!entries.contains { $0.subject.contains("臨床見学") })
            precondition(AcademicCalendar.kind(on: date(20261125), calendar: calendar) == .examPeriod)
            precondition(AcademicCalendar.kind(on: date(20261201), calendar: calendar) == .examPeriod)
            precondition(AcademicCalendar.kind(on: date(20261202), calendar: calendar) == .ordinary)
            precondition(AcademicCalendar.kind(on: date(20270209), calendar: calendar) == .reserve)
            precondition(AcademicCalendar.kind(on: date(20261226), calendar: calendar) == .vacation)
            precondition(!AcademicCalendar.notes(on: date(20261008), calendar: calendar).contains { $0.contains("臨床見学") })
            precondition(!AcademicCalendar.notes(on: date(20261203), calendar: calendar).contains { $0.contains("臨床見学") })
            precondition(!AcademicCalendar.notes(on: date(20261016), calendar: calendar).contains { $0.contains("臨床見学") })
            precondition(!AcademicCalendar.notes(on: date(20270114), calendar: calendar).contains { $0.contains("臨床見学") })
            let first = entries.first { AcademicCalendar.dateKey($0.date, calendar: calendar) == 20261005 }!
            precondition(first.periodTitle == "1・2限" && first.timeRange == "08:45 - 12:00")
            precondition(entries.first { $0.subject == "衛生学・口腔衛生学基礎実習Ⅰ" }?.timeRange == "12:50 - 16:05")
            print("\(zone): \(entries.count) autumn entries validated")
        }

        let suite = "nittei.validation.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let initialStore = ScheduleStore(calendar: calendar, defaults: defaults)
        let tuesday = calendar.date(from: DateComponents(year: 2026, month: 10, day: 6))!
        precondition(initialStore.indicatorKinds(on: tuesday) == [.normal, .normal, .practical],
                     "Tuesday dots must follow the class order")
        let substituteTuesday = calendar.date(from: DateComponents(year: 2027, month: 1, day: 6))!
        precondition(initialStore.indicatorKinds(on: substituteTuesday) == [.normal, .practical])
        let springEntries = initialStore.entries.filter { AcademicCalendar.dateKey($0.date, calendar: calendar) < 20261002 }
        let manual = ClassEntry(date: calendar.date(from: DateComponents(year: 2026, month: 10, day: 2))!,
                                period: 3, subject: "手動登録の実習", location: "手動教室", isExam: false)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        defaults.set(try encoder.encode(springEntries + [manual]), forKey: "nittei.schedule.entries")
        defaults.set("2026-ophthalmology-pharmacology-dentalspecial-psychiatry-internal1-internal2-clinicalpsych-surgery1-surgery2-ent-dermatology-pediatrics-radiation-dentalradiology-teammedicine-microbio-oralpath-oralhealth-v29", forKey: "nittei.schedule.seedVersion")

        let upgraded = ScheduleStore(calendar: calendar, defaults: defaults)
        precondition(upgraded.entries.contains(manual), "Manual entry lost during upgrade")
        precondition(Set(springEntries).isSubset(of: Set(upgraded.entries)), "Spring entries changed")
        precondition(upgraded.months.count == 12)
        precondition(AcademicCalendar.dateKey(upgraded.supportedRange.upperBound, calendar: calendar) == 20270331)
        precondition(upgraded.entries.count == springEntries.count + AutumnSchedule.entries(calendar: calendar).count + 1)
        let reloaded = ScheduleStore(calendar: calendar, defaults: defaults)
        precondition(Set(reloaded.entries) == Set(upgraded.entries), "Reload duplicated or changed entries")
        let testDay = calendar.date(from: DateComponents(year: 2027, month: 3, day: 31))!
        reloaded.addEntry(date: testDay, period: 5, subject: "追加試験", location: "1講", isExam: true)
        let afterAddition = ScheduleStore(calendar: calendar, defaults: defaults)
        precondition(afterAddition.hasExam(on: testDay))
        precondition(afterAddition.indicatorKinds(on: testDay) == [.exam])
        afterAddition.addEntry(date: testDay, period: 1, subject: "通常授業", location: "1講", isExam: false)
        afterAddition.addEntry(date: testDay, period: 3, subject: "追加実習", location: "1実", isExam: false)
        precondition(afterAddition.indicatorKinds(on: testDay) == [.normal, .practical, .exam],
                     "Exam and practical dots must retain their class positions")
        afterAddition.addEntry(date: testDay, period: 6, subject: "4件目", location: "1講", isExam: false)
        precondition(afterAddition.indicatorKinds(on: testDay) == [.normal, .practical, .exam])
        precondition(afterAddition.entries.contains(manual))
        print("v29 migration, spring preservation, manual entries, reload and date range validated")
    }
}
