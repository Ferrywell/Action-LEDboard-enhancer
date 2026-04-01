import SwiftUI

@main
struct ActionLEDboardApp: App {
    @StateObject private var ble = BKLightBleClient()
    @StateObject private var calendar = CalendarEventsProvider()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ble)
                .environmentObject(calendar)
        }
    }
}
