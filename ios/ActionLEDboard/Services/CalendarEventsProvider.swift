import EventKit
import Foundation

/// Reads calendar titles for on-panel summary (EventKit). User must grant calendar access.
@MainActor
final class CalendarEventsProvider: ObservableObject {
    private let store = EKEventStore()

    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined

    init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    func requestAccess() async throws -> Bool {
        let granted = try await store.requestFullAccessToEvents()
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        return granted
    }

    /// Short lines for 32×32 bitmap (very small).
    func todaySummaryLines(maxLines: Int = 4) -> [String] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return ["Geen data"] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
        if events.isEmpty {
            return ["Geen", "items", "vandaag"]
        }
        return events.prefix(maxLines).map { ev in
            let t = DateFormatter()
            t.dateFormat = "HH:mm"
            let time = t.string(from: ev.startDate)
            let title = ev.title ?? "?"
            let short = title.count > 8 ? String(title.prefix(8)) + "…" : title
            return "\(time) \(short)"
        }
    }
}
