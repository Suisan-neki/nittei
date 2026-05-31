import Foundation

@MainActor
final class ScheduleStore: ObservableObject {
    @Published private(set) var entries: [ClassEntry] = [] {
        didSet { save() }
    }

    let supportedRange: ClosedRange<Date>

    let calendar: Calendar
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let storageKey = "nittei.schedule.entries"
    private let seedVersionKey = "nittei.schedule.seedVersion"
    private let currentSeedVersion = "2026-ophthalmology-pharmacology-dentalspecial-psychiatry-internal1-internal2-clinicalpsych-surgery1-surgery2-ent-dermatology-pediatrics-radiation-dentalradiology-teammedicine-microbio-oralpath-oralhealth-v27"

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar

        let startDate = ScheduleStore.makeDate(year: 2026, month: 4, day: 1, calendar: calendar)
        let endDate = ScheduleStore.makeDate(year: 2026, month: 8, day: 31, calendar: calendar)
        self.supportedRange = startDate...endDate

        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        load()
    }

    var months: [Date] {
        var dates: [Date] = []
        var cursor = startOfMonth(for: supportedRange.lowerBound)
        let lastMonth = startOfMonth(for: supportedRange.upperBound)

        while cursor <= lastMonth {
            dates.append(cursor)
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else {
                break
            }
            cursor = next
        }

        return dates
    }

    func entries(for date: Date) -> [ClassEntry] {
        let target = calendar.startOfDay(for: date)

        return entries
            .filter { calendar.isDate($0.date, inSameDayAs: target) }
            .sorted {
                if $0.period == $1.period {
                    return $0.subject.localizedCompare($1.subject) == .orderedAscending
                }
                return $0.period < $1.period
            }
    }

    func entryCount(on date: Date) -> Int {
        entries(for: date).count
    }

    func hasExam(on date: Date) -> Bool {
        entries(for: date).contains(where: \.isExam)
    }

    func indicatorCounts(on date: Date) -> (normal: Int, practical: Int, exam: Int) {
        let dayEntries = entries(for: date)
        let examCount = dayEntries.filter(\.isExam).count
        let practicalCount = dayEntries.filter { !$0.isExam && $0.subject.contains("実習") }.count
        let normalCount = max(dayEntries.count - examCount - practicalCount, 0)
        return (normal: normalCount, practical: practicalCount, exam: examCount)
    }

    func addEntry(date: Date, period: Int, subject: String, location: String, isExam: Bool) {
        let normalizedDate = calendar.startOfDay(for: date)
        guard supportedRange.contains(normalizedDate) else { return }

        entries.append(
            ClassEntry(
                date: normalizedDate,
                period: period,
                subject: subject.trimmingCharacters(in: .whitespacesAndNewlines),
                location: location.trimmingCharacters(in: .whitespacesAndNewlines),
                isExam: isExam
            )
        )
        sortEntries()
    }

    func deleteEntry(_ entry: ClassEntry) {
        entries.removeAll { $0.id == entry.id }
    }

    func clampToSupportedRange(_ date: Date) -> Date {
        let normalizedDate = calendar.startOfDay(for: date)
        if normalizedDate < supportedRange.lowerBound { return supportedRange.lowerBound }
        if normalizedDate > supportedRange.upperBound { return supportedRange.upperBound }
        return normalizedDate
    }

    func startOfMonth(for date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    func supportedMonth(byAdding value: Int, to month: Date) -> Date? {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: month) else {
            return nil
        }

        let normalizedMonth = startOfMonth(for: newMonth)
        return months.contains(normalizedMonth) ? normalizedMonth : nil
    }

    private func load() {
        if
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? decoder.decode([ClassEntry].self, from: data)
        {
            entries = sortedEntries(decoded)
        } else {
            entries = []
        }

        seedIfNeeded()
        restoreMissingSeedEntries()
        cleanupStoredEntries()
    }

    private func seedIfNeeded() {
        guard UserDefaults.standard.string(forKey: seedVersionKey) != currentSeedVersion else {
            return
        }

        let seedEntries = Self.seedEntries(calendar: calendar)
        let seedIDs = Set(seedEntries.map(\.id))
        let obsoleteSeedIDs = Self.obsoleteSeedIDs

        entries.removeAll { seedIDs.contains($0.id) || obsoleteSeedIDs.contains($0.id) }
        entries.append(contentsOf: seedEntries)
        sortEntries()
        UserDefaults.standard.set(currentSeedVersion, forKey: seedVersionKey)
    }

    private func restoreMissingSeedEntries() {
        let seedEntries = Self.seedEntries(calendar: calendar)
        let existingIDs = Set(entries.map(\.id))
        let missingEntries = seedEntries.filter { !existingIDs.contains($0.id) }

        guard !missingEntries.isEmpty else { return }

        entries.append(contentsOf: missingEntries)
        sortEntries()
    }

    private func cleanupStoredEntries() {
        let obsoleteSeedIDs = Self.obsoleteSeedIDs
        var seenKeys: Set<StoredEntryKey> = []

        entries = entries.filter { entry in
            guard !obsoleteSeedIDs.contains(entry.id) else { return false }

            let key = StoredEntryKey(entry: entry, calendar: calendar)
            return seenKeys.insert(key).inserted
        }
        sortEntries()
    }

    private func save() {
        guard let data = try? encoder.encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func sortEntries() {
        entries = sortedEntries(entries)
    }

    private func sortedEntries(_ values: [ClassEntry]) -> [ClassEntry] {
        values.sorted(by: areInScheduleOrder)
    }

    private func areInScheduleOrder(_ lhs: ClassEntry, _ rhs: ClassEntry) -> Bool {
        if lhs.date == rhs.date {
            return lhs.period < rhs.period
        }
        return lhs.date < rhs.date
    }

    private static func makeDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }

    private struct StoredEntryKey: Hashable {
        let date: Date
        let period: Int
        let periodDisplay: String?
        let subject: String
        let location: String
        let isExam: Bool
        let customTimeRange: String?

        init(entry: ClassEntry, calendar: Calendar) {
            date = calendar.startOfDay(for: entry.date)
            period = entry.period
            periodDisplay = entry.periodDisplay
            subject = entry.subject
            location = entry.location
            isExam = entry.isExam
            customTimeRange = entry.customTimeRange
        }
    }

    private static var obsoleteSeedIDs: Set<UUID> {
        let values = [
            "7C2F5F58-D830-4BD7-AF56-D670D52CEC01",
            "7C2F5F58-D830-4BD7-AF56-D670D52CEC02",
            "7C2F5F58-D830-4BD7-AF56-D670D52CEC03",
            "7C2F5F58-D830-4BD7-AF56-D670D52CEC04",
            "7C2F5F58-D830-4BD7-AF56-D670D52CEC05",
            "7C2F5F58-D830-4BD7-AF56-D670D52CEC06",
            "7C2F5F58-D830-4BD7-AF56-D670D52CEC07",
            "7C2F5F58-D830-4BD7-AF56-D670D52CEC08",
            "7C2F5F58-D830-4BD7-AF56-D670D52CED01",
            "7C2F5F58-D830-4BD7-AF56-D670D52CED02",
            "7C2F5F58-D830-4BD7-AF56-D670D52CED03",
            "7C2F5F58-D830-4BD7-AF56-D670D52CED04",
            "7C2F5F58-D830-4BD7-AF56-D670D52CED05",
            "7C2F5F58-D830-4BD7-AF56-D670D52CED06",
            "7C2F5F58-D830-4BD7-AF56-D670D52CED07",
            "7C2F5F58-D830-4BD7-AF56-D670D52CED08"
        ]

        return Set(values.compactMap(UUID.init(uuidString:)))
    }

    private static func seedEntries(calendar: Calendar) -> [ClassEntry] {
        [
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE001") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 13, calendar: calendar),
                period: 9,
                periodDisplay: "5限",
                subject: "眼科学: 目の構造と機能",
                location: "7講",
                isExam: false,
                customTimeRange: "16:20 - 17:50"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE002") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 16, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "眼科学: 角結膜",
                location: "7講",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE003") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 23, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "眼科学: 眼付属器",
                location: "7講",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE004") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 30, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "眼科学: 網膜硝子体",
                location: "7講",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE005") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 14, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "眼科学: 白内障、緑内障",
                location: "7講",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE006") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 21, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "眼科学: 眼科救急疾患",
                location: "7講",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE007") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 28, calendar: calendar),
                period: 5,
                periodDisplay: "3限",
                subject: "眼科学: 予備日",
                location: "7講",
                isExam: false,
                customTimeRange: "12:50 - 14:20"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE008") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 4, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "眼科学 試験",
                location: "7講",
                isExam: true,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE101") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 24, calendar: calendar),
                period: 5,
                periodDisplay: "3・4限",
                subject: "薬理学実習",
                location: "1実",
                isExam: false,
                customTimeRange: "12:50 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE102") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 15, calendar: calendar),
                period: 5,
                periodDisplay: "3・4限",
                subject: "薬理学実習",
                location: "1実",
                isExam: false,
                customTimeRange: "12:50 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE103") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 29, calendar: calendar),
                period: 5,
                periodDisplay: "3・4限",
                subject: "薬理学実習",
                location: "1実",
                isExam: false,
                customTimeRange: "12:50 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE201") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 15, calendar: calendar),
                period: 9,
                periodDisplay: "5限",
                subject: "歯学研究特論: ガイダンス",
                location: "7講",
                isExam: false,
                customTimeRange: "16:20 - 17:50"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE202") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 27, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "歯学研究特論: 歯科麻酔学研究",
                location: "7講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE203") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 27, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "歯学研究特論: 口腔生理学",
                location: "7講",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE204") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 11, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "歯学研究特論: 口腔顎顔面病理病態学",
                location: "7講",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE205") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 18, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "歯学研究特論: 細胞分子薬理学",
                location: "7講",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE206") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 25, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "歯学研究特論: 口腔総合診療科",
                location: "7講",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE207") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 1, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "歯学研究特論: ゲノム口腔腫瘍学",
                location: "7講",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE208") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 8, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "歯学研究特論: 顎顔面解剖学",
                location: "7講",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE209") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 12, calendar: calendar),
                period: 5,
                periodDisplay: "3限",
                subject: "歯学研究特論: 粘膜免疫学",
                location: "7講",
                isExam: false,
                customTimeRange: "12:50 - 14:20"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE210") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 15, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "歯学研究特論: 細菌学",
                location: "大講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE211") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 19, calendar: calendar),
                period: 5,
                periodDisplay: "3限",
                subject: "歯学研究特論: 小児歯科学",
                location: "7講",
                isExam: false,
                customTimeRange: "12:50 - 14:20"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE212") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 22, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "歯学研究特論: 歯科放射線学",
                location: "大講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE213") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 22, calendar: calendar),
                period: 5,
                periodDisplay: "3限",
                subject: "歯学研究特論: 歯周病態学",
                location: "オンデマンド",
                isExam: false,
                customTimeRange: "12:50 - 14:20"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE214") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 26, calendar: calendar),
                period: 5,
                periodDisplay: "3限",
                subject: "歯学研究特論: 口腔腫瘍制御学",
                location: "7講",
                isExam: false,
                customTimeRange: "12:50 - 14:20"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE215") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 29, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "歯学研究特論: 先端歯科補綴学①",
                location: "大講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE216") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 29, calendar: calendar),
                period: 5,
                periodDisplay: "3限",
                subject: "歯学研究特論: 歯科矯正学",
                location: "7講",
                isExam: false,
                customTimeRange: "12:50 - 14:20"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE217") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 6, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "歯学研究特論: 生体材料学",
                location: "大講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE218") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 6, calendar: calendar),
                period: 5,
                periodDisplay: "3限",
                subject: "歯学研究特論: 障害者歯科",
                location: "7講",
                isExam: false,
                customTimeRange: "12:50 - 14:20"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE219") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 13, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "歯学研究特論: 口腔検査センター",
                location: "大講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE220") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 13, calendar: calendar),
                period: 5,
                periodDisplay: "3限",
                subject: "歯学研究特論: 先端歯科補綴学②",
                location: "7講",
                isExam: false,
                customTimeRange: "12:50 - 14:20"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE221") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 14, calendar: calendar),
                period: 5,
                periodDisplay: "3限",
                subject: "歯学研究特論: 生体分子機能学",
                location: "7講",
                isExam: false,
                customTimeRange: "12:50 - 14:20"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE222") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 24, calendar: calendar),
                period: 5,
                periodDisplay: "3限",
                subject: "歯学研究特論: 歯髄生物学",
                location: "7講",
                isExam: false,
                customTimeRange: "12:50 - 14:20"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE223") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 27, calendar: calendar),
                period: 5,
                periodDisplay: "3限",
                subject: "歯学研究特論: 口腔外科学",
                location: "7講",
                isExam: false,
                customTimeRange: "12:50 - 14:20"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE301") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 14, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "精神科: 精神医学総論",
                location: "大講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE302") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 21, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "精神科: 認知症・睡眠障害・アルコール精神障害",
                location: "大講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE303") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 28, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "精神科: 発達障害・摂食障害",
                location: "大講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE304") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 11, calendar: calendar),
                period: 9,
                periodDisplay: "5限",
                subject: "精神科: リエゾン精神医学・精神腫瘍学・症状性精神障害",
                location: "大講",
                isExam: false,
                customTimeRange: "16:20 - 17:50"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE305") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 12, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "精神科: 気分障害",
                location: "大講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE306") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 19, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "精神科: 神経症・心身症",
                location: "大講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE307") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 26, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "精神科: 統合失調症",
                location: "大講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE308") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 2, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "精神科 試験",
                location: "大講",
                isExam: true,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE401") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 10, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "内科学1: 消化器疾患・胆膵疾患",
                location: "7講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE402") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 23, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "内科学1: 消化器疾患・肝疾患1",
                location: "7講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE403") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 30, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "内科学1: 消化器疾患・食道、胃、大腸の腫瘍性疾患",
                location: "7講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE404") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 8, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "内科学1: 消化器疾患・肝疾患2",
                location: "7講",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE405") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 20, calendar: calendar),
                period: 9,
                periodDisplay: "5限",
                subject: "内科学1: 消化器疾患・ヘリコバクター・ピロリ関連疾患",
                location: "7講",
                isExam: false,
                customTimeRange: "16:20 - 17:50"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE406") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 27, calendar: calendar),
                period: 9,
                periodDisplay: "5限",
                subject: "内科学1: 消化器疾患・炎症性腸疾患",
                location: "7講",
                isExam: false,
                customTimeRange: "16:20 - 17:50"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE407") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 28, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "内科学1: 消化器疾患・肝疾患3",
                location: "7講",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE408") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 5, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "内科学1: 予備日",
                location: "未定",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE409") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 17, calendar: calendar),
                period: 9,
                periodDisplay: "5限",
                subject: "内科学1: 神経疾患・神経免疫疾患、重症筋無力症",
                location: "7講",
                isExam: false,
                customTimeRange: "16:20 - 17:50"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE410") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 26, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "内科学1: 神経疾患・パーキンソン病、認知症",
                location: "大講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE411") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 9, calendar: calendar),
                period: 7,
                periodDisplay: "4限",
                subject: "内科学1: 神経疾患・頭痛、神経感染症",
                location: "7講",
                isExam: false,
                customTimeRange: "14:35 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE412") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 16, calendar: calendar),
                period: 7,
                periodDisplay: "4限",
                subject: "内科学1: 神経疾患・脳卒中",
                location: "7講",
                isExam: false,
                customTimeRange: "14:35 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE413") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 23, calendar: calendar),
                period: 7,
                periodDisplay: "4限",
                subject: "内科学1: 予備日",
                location: "未定",
                isExam: false,
                customTimeRange: "14:35 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE414") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 24, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "内科学1 試験",
                location: "大講",
                isExam: true,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE501") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 9, calendar: calendar),
                period: 5,
                periodDisplay: "3限",
                subject: "内科学2: 呼吸器系疾患・総論・呼吸器感染症",
                location: "7講",
                isExam: false,
                customTimeRange: "12:50 - 14:20"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE502") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 13, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "内科学2: 呼吸器系疾患・肺癌",
                location: "7講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE503") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 20, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "内科学2: 呼吸器系疾患・びまん性肺疾患・慢性閉塞性肺疾患",
                location: "7講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE504") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 23, calendar: calendar),
                period: 5,
                periodDisplay: "3限",
                subject: "内科学2: 呼吸器系疾患・気管支喘息",
                location: "7講",
                isExam: false,
                customTimeRange: "12:50 - 14:20"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE505") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 14, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "内科学2: 代謝疾患・糖尿病の合併症と治療",
                location: "7講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE506") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 14, calendar: calendar),
                period: 5,
                periodDisplay: "3限",
                subject: "内科学2: 循環器疾患・心不全、弁膜症",
                location: "オンデマンド",
                isExam: false,
                customTimeRange: "12:50 - 14:20"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE507") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 21, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "内科学2: 循環器疾患・高血圧",
                location: "オンデマンド",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE508") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 21, calendar: calendar),
                period: 5,
                periodDisplay: "3限",
                subject: "内科学2: 内分泌疾患・診断概要",
                location: "7講",
                isExam: false,
                customTimeRange: "12:50 - 14:20"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE509") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 28, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "内科学2: 循環器疾患・虚血性心疾患",
                location: "7講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE510") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 1, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "内科学2: 腎疾患・総論・糸球体疾患",
                location: "7講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE511") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 8, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "内科学2: 腎疾患・腎不全",
                location: "7講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE512") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 11, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "内科学2: 血液疾患・造血免疫系の全体像",
                location: "7講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE513") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 18, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "内科学2: 血液疾患・赤血球系疾患・貧血",
                location: "7講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE514") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 19, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "内科学2: 循環器疾患・不整脈",
                location: "大講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE515") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 25, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "内科学2: 血液疾患・造血器腫瘍",
                location: "7講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE516") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 2, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "内科学2: 血液疾患・出血血栓性疾患",
                location: "7講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE517") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 16, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "内科学2 試験",
                location: "7講",
                isExam: true,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE601") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 27, calendar: calendar),
                period: 7,
                periodDisplay: "4限",
                subject: "臨床心理学: なぜ歯科で臨床心理学？",
                location: "大講",
                isExam: false,
                customTimeRange: "14:35 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE602") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 11, calendar: calendar),
                period: 7,
                periodDisplay: "4限",
                subject: "臨床心理学: 治療の満足度はどう決まるのか？",
                location: "大講",
                isExam: false,
                customTimeRange: "14:35 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE603") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 18, calendar: calendar),
                period: 7,
                periodDisplay: "4限",
                subject: "臨床心理学: 習慣を変化させる",
                location: "大講",
                isExam: false,
                customTimeRange: "14:35 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE604") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 25, calendar: calendar),
                period: 7,
                periodDisplay: "4限",
                subject: "臨床心理学: その言葉がどう伝わるのか？",
                location: "大講",
                isExam: false,
                customTimeRange: "14:35 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE605") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 1, calendar: calendar),
                period: 7,
                periodDisplay: "4限",
                subject: "臨床心理学: 精神障害を抱える患者さん",
                location: "大講",
                isExam: false,
                customTimeRange: "14:35 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE606") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 8, calendar: calendar),
                period: 7,
                periodDisplay: "4限",
                subject: "臨床心理学: 発達障害を抱える患者さん",
                location: "大講",
                isExam: false,
                customTimeRange: "14:35 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE607") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 15, calendar: calendar),
                period: 9,
                periodDisplay: "5限",
                subject: "臨床心理学: 痛みについての心理学",
                location: "オンデマンド",
                isExam: false,
                customTimeRange: "16:20 - 17:35"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE608") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 22, calendar: calendar),
                period: 9,
                periodDisplay: "5限",
                subject: "臨床心理学: まとめ",
                location: "オンデマンド",
                isExam: false,
                customTimeRange: "16:20 - 17:35"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE701") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 9, calendar: calendar),
                period: 7,
                periodDisplay: "4限",
                subject: "外科学1: 小児外科",
                location: "7講",
                isExam: false,
                customTimeRange: "14:35 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE702") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 13, calendar: calendar),
                period: 5,
                periodDisplay: "3限",
                subject: "外科学1: 肝胆膵の外科",
                location: "大講",
                isExam: false,
                customTimeRange: "12:50 - 14:20"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE703") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 16, calendar: calendar),
                period: 7,
                periodDisplay: "4限",
                subject: "外科学1: 外科総論（全身管理、救急処置など）",
                location: "7講",
                isExam: false,
                customTimeRange: "14:35 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE704") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 20, calendar: calendar),
                period: 5,
                periodDisplay: "3限",
                subject: "外科学1: 上部消化管（胃）の外科",
                location: "大講",
                isExam: false,
                customTimeRange: "12:50 - 14:20"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE705") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 23, calendar: calendar),
                period: 7,
                periodDisplay: "4限",
                subject: "外科学1: 心臓外科・ペースメーカー",
                location: "7講",
                isExam: false,
                customTimeRange: "14:35 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE706") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 27, calendar: calendar),
                period: 5,
                periodDisplay: "3限",
                subject: "外科学1: 外科周術管理",
                location: "大講",
                isExam: false,
                customTimeRange: "12:50 - 14:20"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE707") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 30, calendar: calendar),
                period: 7,
                periodDisplay: "4限",
                subject: "外科学1: 血管外科",
                location: "7講",
                isExam: false,
                customTimeRange: "14:35 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE708") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 11, calendar: calendar),
                period: 5,
                periodDisplay: "3限",
                subject: "外科学1: 臓器移植と人工臓器",
                location: "大講",
                isExam: false,
                customTimeRange: "12:50 - 14:20"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE709") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 14, calendar: calendar),
                period: 7,
                periodDisplay: "4限",
                subject: "外科学1: 外科総論（全身管理、救急処置など）",
                location: "7講",
                isExam: false,
                customTimeRange: "14:35 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE710") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 18, calendar: calendar),
                period: 5,
                periodDisplay: "3限",
                subject: "外科学1: 下部消化管の外科",
                location: "大講",
                isExam: false,
                customTimeRange: "12:50 - 14:20"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE711") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 21, calendar: calendar),
                period: 7,
                periodDisplay: "4限",
                subject: "外科学1: 乳腺の外科",
                location: "7講",
                isExam: false,
                customTimeRange: "14:35 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE712") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 28, calendar: calendar),
                period: 7,
                periodDisplay: "4限",
                subject: "外科学1: 肺、胸部外科",
                location: "7講",
                isExam: false,
                customTimeRange: "14:35 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE713") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 4, calendar: calendar),
                period: 7,
                periodDisplay: "4限",
                subject: "外科学1: 消化管（食道）の外科",
                location: "7講",
                isExam: false,
                customTimeRange: "14:35 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE714") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 11, calendar: calendar),
                period: 7,
                periodDisplay: "4限",
                subject: "外科学1: 外科腫瘍学総論",
                location: "7講",
                isExam: false,
                customTimeRange: "14:35 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE715") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 25, calendar: calendar),
                period: 7,
                periodDisplay: "4限",
                subject: "外科学1 試験",
                location: "7講",
                isExam: true,
                customTimeRange: "14:35 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF101") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 10, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "外科学2: 脊椎・脊髄疾患",
                location: "大講",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF102") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 17, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "外科学2: 四肢の運動と知覚",
                location: "大講",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF103") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 24, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "外科学2: 四肢の外傷",
                location: "大講",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF104") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 1, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "外科学2: 頭部外傷",
                location: "大講",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF105") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 6, calendar: calendar),
                period: 7,
                periodDisplay: "4限",
                subject: "外科学2: 脳血管障害",
                location: "7講",
                isExam: false,
                customTimeRange: "14:35 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF106") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 15, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "外科学2: 脳腫瘍",
                location: "大講",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF107") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 22, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "外科学2: 神経血管圧迫症候群",
                location: "大講",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF108") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 29, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "外科学2 試験",
                location: "大講",
                isExam: true,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF201") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 11, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "耳鼻咽喉科学: 鼻副鼻腔の解剖・生理、鼻アレルギー",
                location: "7講",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF202") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 11, calendar: calendar),
                period: 5,
                periodDisplay: "3限",
                subject: "耳鼻咽喉科学: 耳下腺疾患の症候と治療",
                location: "7講",
                isExam: false,
                customTimeRange: "12:50 - 14:20"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF203") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 18, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "耳鼻咽喉科学: 気管・食道の解剖・生理、気道・食道の歯科的異物",
                location: "7講",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF204") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 18, calendar: calendar),
                period: 5,
                periodDisplay: "3限",
                subject: "耳鼻咽喉科学: 耳の解剖・検査、耳疾患の症候と治療法",
                location: "7講",
                isExam: false,
                customTimeRange: "12:50 - 14:20"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF205") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 25, calendar: calendar),
                period: 5,
                periodDisplay: "3限",
                subject: "耳鼻咽喉科学: 咽頭・喉頭の解剖・生理および疾患",
                location: "7講",
                isExam: false,
                customTimeRange: "12:50 - 14:20"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF206") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 2, calendar: calendar),
                period: 5,
                periodDisplay: "3限",
                subject: "耳鼻咽喉科学: 頭頸部癌（咽頭・喉頭癌）の診断と治療",
                location: "7講",
                isExam: false,
                customTimeRange: "12:50 - 14:20"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF207") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 9, calendar: calendar),
                period: 5,
                periodDisplay: "3限",
                subject: "耳鼻咽喉科学: 鼻副鼻腔の良性疾患など（副鼻腔炎、外傷、腫瘍）",
                location: "7講",
                isExam: false,
                customTimeRange: "12:50 - 14:20"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF208") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 16, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "耳鼻咽喉科学 試験",
                location: "7講",
                isExam: true,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF301") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 9, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "皮膚科学: 構造,機能,症候学",
                location: "大講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF302") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 16, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "皮膚科学: 母斑,皮膚腫瘍",
                location: "大講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF303") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 23, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "皮膚科学: 水疱症,膠原病",
                location: "大講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF304") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 30, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "皮膚科学: 蕁麻疹,紅斑症,紫斑",
                location: "大講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF305") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 7, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "皮膚科学: 皮膚感染症,角化症",
                location: "大講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF306") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 14, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "皮膚科学: 湿疹・皮膚炎群,皮膚そう痒症",
                location: "大講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF307") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 21, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "皮膚科学: 熱傷,薬疹",
                location: "大講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF308") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 28, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "皮膚科学 試験",
                location: "大講",
                isExam: true,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF401") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 10, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "小児科学: 小児の感染症、予防接種、消化器疾患、循環器疾患",
                location: "大講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF402") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 17, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "小児科学: 小児の血液疾患・がん",
                location: "大講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF403") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 24, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "小児科学: 小児のアレルギー疾患・リウマチ性疾患・免疫不全",
                location: "大講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF404") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 1, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "小児科学: 小児の発達と神経病・筋疾患",
                location: "大講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF405") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 8, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "小児科学: 小児患児に対する歯科的連携",
                location: "大講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF406") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 15, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "小児科学: 妊娠期の歯科治療",
                location: "大講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF407") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 22, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "小児科学: 予備日",
                location: "大講",
                isExam: false,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF408") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 29, calendar: calendar),
                period: 1,
                periodDisplay: "1限",
                subject: "小児科学 試験",
                location: "大講",
                isExam: true,
                customTimeRange: "08:45 - 10:15"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE801") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 14, calendar: calendar),
                period: 2,
                subject: "放射線",
                location: "医5講",
                isExam: false
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE802") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 21, calendar: calendar),
                period: 2,
                subject: "放射線",
                location: "医5講",
                isExam: false
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE803") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 28, calendar: calendar),
                period: 2,
                subject: "放射線",
                location: "医5講",
                isExam: false
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE804") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 12, calendar: calendar),
                period: 2,
                subject: "放射線",
                location: "医5講",
                isExam: false
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE805") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 19, calendar: calendar),
                period: 2,
                subject: "放射線",
                location: "医5講",
                isExam: false
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE806") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 26, calendar: calendar),
                period: 2,
                subject: "放射線",
                location: "医5講",
                isExam: false
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE807") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 2, calendar: calendar),
                period: 2,
                subject: "放射線",
                location: "医5講",
                isExam: false
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE808") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 9, calendar: calendar),
                period: 2,
                subject: "放射線",
                location: "医5講",
                isExam: false
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE809") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 16, calendar: calendar),
                period: 2,
                subject: "放射線",
                location: "医5講",
                isExam: false
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE810") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 23, calendar: calendar),
                period: 2,
                subject: "放射線",
                location: "医5講",
                isExam: false
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE811") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 30, calendar: calendar),
                period: 2,
                subject: "放射線",
                location: "医5講",
                isExam: false
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE812") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 7, calendar: calendar),
                period: 2,
                subject: "放射線",
                location: "医5講",
                isExam: false
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE813") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 21, calendar: calendar),
                period: 2,
                subject: "放射線",
                location: "医5講",
                isExam: false
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE814") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 28, calendar: calendar),
                period: 2,
                subject: "放射線",
                location: "医5講",
                isExam: false
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE815") ?? UUID(),
                date: makeDate(year: 2026, month: 8, day: 4, calendar: calendar),
                period: 2,
                subject: "放射線 テスト",
                location: "医5講",
                isExam: true
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF501") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 15, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "歯科放射線: 放射線物理（種類と性質）",
                location: "7講",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF502") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 15, calendar: calendar),
                period: 5,
                periodDisplay: "3限",
                subject: "歯科放射線: X線フィルム、増感紙、現像",
                location: "7講",
                isExam: false,
                customTimeRange: "12:50 - 14:20"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF503") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 22, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "歯科放射線: デジタルX線検出器、X線装置、X線撮影法の原理",
                location: "7講",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF504") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 29, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "歯科放射線: 放射線生物学（人体への影響）",
                location: "7講",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF505") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 6, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "歯科放射線: 放射線の防護",
                location: "7講",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF506") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 13, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "歯科放射線: 口内法",
                location: "7講",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF507") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 14, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "歯科放射線: パノラマ撮影法",
                location: "7講",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF508") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 27, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "歯科放射線 テスト",
                location: "7講",
                isExam: true,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF601") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 12, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "チーム医療学",
                location: "大講",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF602") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 19, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "チーム医療学",
                location: "大講",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF603") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 26, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "チーム医療学",
                location: "大講",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF604") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 3, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "チーム医療学",
                location: "大講",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF605") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 10, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "チーム医療学",
                location: "大講",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF606") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 17, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "チーム医療学",
                location: "大講",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF607") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 24, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "チーム医療学",
                location: "大講",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CF608") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 31, calendar: calendar),
                period: 3,
                periodDisplay: "2限",
                subject: "チーム医療学",
                location: "大講",
                isExam: false,
                customTimeRange: "10:30 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CEA01") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 14, calendar: calendar),
                period: 5,
                periodDisplay: "3限",
                subject: "口腔病理学実習Ⅰ",
                location: "2実",
                isExam: false,
                customTimeRange: "12:50 - 14:20"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CEA02") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 21, calendar: calendar),
                period: 5,
                periodDisplay: "3限",
                subject: "口腔病理学実習Ⅰ",
                location: "2実",
                isExam: false,
                customTimeRange: "12:50 - 14:20"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CEA03") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 28, calendar: calendar),
                period: 5,
                periodDisplay: "3限",
                subject: "口腔病理学実習Ⅰ",
                location: "2実",
                isExam: false,
                customTimeRange: "12:50 - 14:20"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CEA04") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 7, calendar: calendar),
                period: 5,
                periodDisplay: "3限",
                subject: "口腔病理学実習Ⅰ",
                location: "2実",
                isExam: false,
                customTimeRange: "12:50 - 14:20"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CEA05") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 12, calendar: calendar),
                period: 5,
                periodDisplay: "3限",
                subject: "口腔病理学実習Ⅰ",
                location: "2実",
                isExam: false,
                customTimeRange: "12:50 - 14:20"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CEA06") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 19, calendar: calendar),
                period: 5,
                periodDisplay: "3限",
                subject: "口腔病理学実習Ⅰ",
                location: "2実",
                isExam: false,
                customTimeRange: "12:50 - 14:20"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CEA07") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 26, calendar: calendar),
                period: 5,
                periodDisplay: "3限",
                subject: "口腔病理学実習Ⅰ",
                location: "2実",
                isExam: false,
                customTimeRange: "12:50 - 14:20"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CEA08") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 2, calendar: calendar),
                period: 5,
                periodDisplay: "3限",
                subject: "口腔病理学実習Ⅰ",
                location: "2実",
                isExam: false,
                customTimeRange: "12:50 - 14:20"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CEB01") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 8, calendar: calendar),
                period: 3,
                periodDisplay: "3・4限",
                subject: "口腔衛生学",
                location: "大講",
                isExam: false,
                customTimeRange: "12:50 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CEB02") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 15, calendar: calendar),
                period: 3,
                periodDisplay: "3・4限",
                subject: "口腔衛生学",
                location: "大講",
                isExam: false,
                customTimeRange: "12:50 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CEB03") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 22, calendar: calendar),
                period: 3,
                periodDisplay: "3・4限",
                subject: "口腔衛生学",
                location: "大講",
                isExam: false,
                customTimeRange: "12:50 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CEB04") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 1, calendar: calendar),
                period: 3,
                periodDisplay: "3・4限",
                subject: "口腔衛生学",
                location: "大講",
                isExam: false,
                customTimeRange: "12:50 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CEB05") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 6, calendar: calendar),
                period: 3,
                periodDisplay: "3・4限",
                subject: "口腔衛生学",
                location: "大講",
                isExam: false,
                customTimeRange: "12:50 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CEB06") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 13, calendar: calendar),
                period: 3,
                periodDisplay: "3・4限",
                subject: "口腔衛生学",
                location: "大講",
                isExam: false,
                customTimeRange: "12:50 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CEB07") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 20, calendar: calendar),
                period: 3,
                periodDisplay: "3・4限",
                subject: "口腔衛生学",
                location: "大講",
                isExam: false,
                customTimeRange: "12:50 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CEB08") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 27, calendar: calendar),
                period: 3,
                periodDisplay: "3・4限",
                subject: "口腔衛生学",
                location: "大講",
                isExam: false,
                customTimeRange: "12:50 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CEB09") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 3, calendar: calendar),
                period: 3,
                periodDisplay: "3・4限",
                subject: "口腔衛生学",
                location: "大講",
                isExam: false,
                customTimeRange: "12:50 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE901") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 8, calendar: calendar),
                period: 1,
                periodDisplay: "1・2限",
                subject: "微生物実習: ガイダンス・グラム染色",
                location: "1実",
                isExam: false,
                customTimeRange: "08:45 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE902") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 15, calendar: calendar),
                period: 1,
                periodDisplay: "1・2限",
                subject: "微生物実習: グラム染色・手指・落下細菌",
                location: "1実",
                isExam: false,
                customTimeRange: "08:45 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE903") ?? UUID(),
                date: makeDate(year: 2026, month: 4, day: 22, calendar: calendar),
                period: 1,
                periodDisplay: "1・2限",
                subject: "微生物実習: 手指・落下細菌",
                location: "1実",
                isExam: false,
                customTimeRange: "08:45 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE904") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 1, calendar: calendar),
                period: 1,
                periodDisplay: "1・2限",
                subject: "微生物実習: レンサ球菌・特別講義",
                location: "1実",
                isExam: false,
                customTimeRange: "08:45 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE905") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 13, calendar: calendar),
                period: 1,
                periodDisplay: "1・2限",
                subject: "微生物実習: レンサ球菌",
                location: "1実",
                isExam: false,
                customTimeRange: "08:45 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE906") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 20, calendar: calendar),
                period: 1,
                periodDisplay: "1・2限",
                subject: "微生物実習: 歯周病原因菌",
                location: "1実",
                isExam: false,
                customTimeRange: "08:45 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE907") ?? UUID(),
                date: makeDate(year: 2026, month: 5, day: 27, calendar: calendar),
                period: 1,
                periodDisplay: "1・2限",
                subject: "微生物実習: 歯周病原因菌・薬剤感受性試験",
                location: "1実",
                isExam: false,
                customTimeRange: "08:45 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE908") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 3, calendar: calendar),
                period: 1,
                periodDisplay: "1・2限",
                subject: "微生物実習: 薬剤感受性試験",
                location: "1実",
                isExam: false,
                customTimeRange: "08:45 - 12:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE909") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 10, calendar: calendar),
                period: 5,
                periodDisplay: "3・4限",
                subject: "微生物実習",
                location: "1実",
                isExam: false,
                customTimeRange: "12:50 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE910") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 17, calendar: calendar),
                period: 5,
                periodDisplay: "3-5限",
                subject: "微生物実習: 実技試験",
                location: "1実",
                isExam: true,
                customTimeRange: "12:50 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE911") ?? UUID(),
                date: makeDate(year: 2026, month: 6, day: 24, calendar: calendar),
                period: 5,
                periodDisplay: "3-5限",
                subject: "微生物実習: 筆記試験",
                location: "1実",
                isExam: true,
                customTimeRange: "12:50 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE912") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 1, calendar: calendar),
                period: 5,
                periodDisplay: "3・4限",
                subject: "免疫学実習: オリエンテーション・動物実験講習",
                location: "1実",
                isExam: false,
                customTimeRange: "12:50 - 16:05"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE913") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 8, calendar: calendar),
                period: 5,
                periodDisplay: "3-5限",
                subject: "免疫学実習: 対面実習・課題学習",
                location: "1実",
                isExam: false,
                customTimeRange: "12:50 - 17:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE914") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 15, calendar: calendar),
                period: 5,
                periodDisplay: "3-5限",
                subject: "免疫学実習: 対面実習・課題学習",
                location: "1実",
                isExam: false,
                customTimeRange: "12:50 - 17:00"
            ),
            ClassEntry(
                id: UUID(uuidString: "7C2F5F58-D830-4BD7-AF56-D670D52CE915") ?? UUID(),
                date: makeDate(year: 2026, month: 7, day: 22, calendar: calendar),
                period: 5,
                periodDisplay: "3・4限",
                subject: "免疫学実習: 実験レヴュー・理解度評価",
                location: "1実",
                isExam: true,
                customTimeRange: "12:50 - 16:05"
            )
        ]
    }
}
