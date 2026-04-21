import SwiftUI

@main
struct NitteiApp: App {
    @StateObject private var store = ScheduleStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
