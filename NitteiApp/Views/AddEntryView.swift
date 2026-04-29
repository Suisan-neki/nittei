import SwiftUI

struct AddEntryView: View {
    @Environment(\.dismiss) private var dismiss

    let initialDate: Date
    let allowedRange: ClosedRange<Date>
    let onSave: (Date, Int, String, String, Bool) -> Void

    @State private var date = Date()
    @State private var period = 1
    @State private var subject = ""
    @State private var location = ""
    @State private var isExam = false

    var body: some View {
        NavigationStack {
            Form {
                Section("いつ") {
                    DatePicker(
                        "日付",
                        selection: $date,
                        in: allowedRange,
                        displayedComponents: .date
                    )

                    Picker("何限", selection: $period) {
                        ForEach(1..<6) { value in
                            Text("\(value)限").tag(value)
                        }
                    }
                }

                Section("内容") {
                    TextField("科目", text: $subject)
                    TextField("場所", text: $location)
                    Toggle("この日はテスト", isOn: $isExam)
                }

                Section {
                    Text("最低限の登録だけにしてあります。繰り返し設定は入れず、変則日程をそのまま日付ごとに積む前提です。")
                        .font(.system(.footnote, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.97, blue: 0.93),
                        Color(red: 0.91, green: 0.96, blue: 0.98)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .navigationTitle("予定を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(date, period, subject, location, isExam)
                        dismiss()
                    }
                    .disabled(subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                date = min(max(initialDate, allowedRange.lowerBound), allowedRange.upperBound)
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    AddEntryView(initialDate: .now, allowedRange: Date()...Date().addingTimeInterval(60 * 60 * 24 * 30)) { _, _, _, _, _ in }
}
