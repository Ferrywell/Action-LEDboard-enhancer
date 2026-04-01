import SwiftUI
import UIKit

@main
struct ActionLEDboardApp: App {
    @StateObject private var ble = BKLightBleClient()
    @StateObject private var calendar = CalendarEventsProvider()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ble)
                .environmentObject(calendar)
                // Avoids empty/black window on some iOS betas before first List layout.
                .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        }
    }
}
