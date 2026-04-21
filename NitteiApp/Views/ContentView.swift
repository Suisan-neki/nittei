import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ScheduleStore

    @State private var selectedDate = Date()
    @State private var selectedMonth = Date()
    @State private var isPresentingAddSheet = false

    private let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            backgroundView

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    headerView
                    monthSwitcher
                    MonthCalendarView(month: selectedMonth, selectedDate: $selectedDate)
                    DayScheduleView(
                        selectedDate: selectedDate,
                        entries: store.entries(for: selectedDate),
                        onDelete: store.deleteEntry
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 120)
            }

            addButton
        }
        .sheet(isPresented: $isPresentingAddSheet) {
            AddEntryView(
                initialDate: selectedDate,
                allowedRange: store.supportedRange
            ) { date, period, subject, location, isExam in
                store.addEntry(
                    date: date,
                    period: period,
                    subject: subject,
                    location: location,
                    isExam: isExam
                )
                selectedDate = store.clampToSupportedRange(date)
                selectedMonth = store.startOfMonth(for: selectedDate)
            }
        }
        .onAppear {
            let initialDate = store.clampToSupportedRange(.now)
            selectedDate = initialDate
            selectedMonth = store.startOfMonth(for: initialDate)
        }
        .onChange(of: selectedDate) { _, newValue in
            selectedMonth = store.startOfMonth(for: newValue)
        }
    }

    private var backgroundView: some View {
        LinearGradient(
            colors: [
                Color(red: 0.99, green: 0.97, blue: 0.93),
                Color(red: 0.91, green: 0.95, blue: 0.91),
                Color(red: 0.86, green: 0.92, blue: 0.98)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(Color.white.opacity(0.45))
                .frame(width: 260, height: 260)
                .blur(radius: 24)
                .offset(x: -70, y: -90)
        }
        .overlay(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 48, style: .continuous)
                .fill(Color(red: 0.96, green: 0.83, blue: 0.67).opacity(0.28))
                .frame(width: 240, height: 240)
                .rotationEffect(.degrees(18))
                .blur(radius: 8)
                .offset(x: 80, y: 80)
        }
        .ignoresSafeArea()
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nittei")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.16, green: 0.21, blue: 0.29))

            Text("2026年4月から8月までの変則時間割を、日付ベースでそのまま置いていく。試験日は赤く強調。")
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundStyle(Color(red: 0.29, green: 0.34, blue: 0.40))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var monthSwitcher: some View {
        HStack(spacing: 12) {
            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canMoveMonth(by: -1))
            .opacity(canMoveMonth(by: -1) ? 1 : 0.35)

            VStack(alignment: .leading, spacing: 4) {
                Text(monthFormatter.string(from: selectedMonth))
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundStyle(Color(red: 0.11, green: 0.16, blue: 0.24))

                Text("タップすると、その日の授業が下に時系列で出ます")
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color(red: 0.36, green: 0.40, blue: 0.46))
            }

            Spacer()

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canMoveMonth(by: 1))
            .opacity(canMoveMonth(by: 1) ? 1 : 0.35)
        }
    }

    private var addButton: some View {
        Button {
            isPresentingAddSheet = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .heavy))
                Text("予定を追加")
                    .font(.system(.headline, design: .rounded, weight: .heavy))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.93, green: 0.37, blue: 0.29),
                        Color(red: 0.85, green: 0.19, blue: 0.21)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: Capsule()
            )
            .shadow(color: Color.black.opacity(0.14), radius: 18, x: 0, y: 10)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }

    private func canMoveMonth(by value: Int) -> Bool {
        guard let newMonth = Calendar.autoupdatingCurrent.date(byAdding: .month, value: value, to: selectedMonth) else {
            return false
        }
        return store.months.contains(store.startOfMonth(for: newMonth))
    }

    private func moveMonth(by value: Int) {
        guard let newMonth = Calendar.autoupdatingCurrent.date(byAdding: .month, value: value, to: selectedMonth) else {
            return
        }

        let normalizedMonth = store.startOfMonth(for: newMonth)
        guard store.months.contains(normalizedMonth) else { return }

        selectedMonth = normalizedMonth
        selectedDate = normalizedMonth
    }
}

#Preview {
    ContentView()
        .environmentObject(ScheduleStore())
}
