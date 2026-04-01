import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var ble: BKLightBleClient
    @EnvironmentObject private var calendar: CalendarEventsProvider

    @State private var mode: PanelMode = .message
    @State private var messageText = "Hoi"
    @State private var isSending = false
    @State private var statusMessage: String?
    @State private var showError: String?

    enum PanelMode: String, CaseIterable, Identifiable {
        case calendar = "Kalender"
        case message = "Bericht"
        case flights = "Vluchten"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("BLE") {
                    HStack {
                        Button("Scan LED_BLE_*") {
                            ble.startScan()
                        }
                        .disabled(ble.connectionState == .connecting)
                        Button("Stop") { ble.stopScan() }
                    }
                    if let bleErr = ble.lastError {
                        Text(bleErr)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .accessibilityLabel("BLE-fout: \(bleErr)")
                    }
                    if ble.isScanning {
                        Text("Scannen…")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(ble.discoveredPeripherals, id: \.identifier) { p in
                        Button {
                            ble.connect(p)
                        } label: {
                            HStack {
                                Text(p.name ?? p.identifier.uuidString)
                                Spacer()
                                if ble.connectedPeripheral?.identifier == p.identifier {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                    if let cp = ble.connectedPeripheral {
                        Text("Verbonden: \(cp.name ?? cp.identifier.uuidString)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if ble.connectionState == .connected, !ble.isPanelReady {
                            Text("Wacht op GATT (schrijf fa02 + notify fa03)…")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        Button("Verbreken", role: .destructive) {
                            ble.disconnect()
                        }
                    }
                    if let h = ble.lastNotifyHex {
                        Text("Laatste notify: \(h)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Section("Modus") {
                    Picker("Weergave", selection: $mode) {
                        ForEach(PanelMode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    switch mode {
                    case .calendar:
                        Text("Toont vandaag’s agenda-items (EventKit). 32×32 — korte tekst.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Kalender-toegang") {
                            Task {
                                do {
                                    _ = try await calendar.requestAccess()
                                } catch {
                                    showError = error.localizedDescription
                                }
                            }
                        }
                    case .message:
                        TextField("Tekst", text: $messageText)
                            .textInputAutocapitalization(.never)
                    case .flights:
                        Text("OpenSky in je regio (URLSession). Geen API-key; alleen indicatief.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        Task { await sendCurrentMode() }
                    } label: {
                        if isSending {
                            ProgressView()
                        } else {
                            Text("Naar paneel sturen")
                        }
                    }
                    .disabled(!ble.isPanelReady || isSending)

                    if let s = statusMessage {
                        Text(s)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("iOS BLE") {
                    Text("Achtergrond: voeg UIBackgroundModes bluetooth-central toe en gebruik state restoration voor langere sessies. MTU: writes worden in stukken verstuurd (zie protocol).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.insetGrouped)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Action LEDboard")
            .alert("Fout", isPresented: Binding(
                get: { showError != nil },
                set: { if !$0 { showError = nil } }
            )) {
                Button("OK", role: .cancel) { showError = nil }
            } message: {
                Text(showError ?? "")
            }
        }
    }

    @MainActor
    private func sendCurrentMode() async {
        guard ble.connectedPeripheral != nil else {
            showError = BKLightError.notConnected.localizedDescription
            return
        }
        guard ble.isPanelReady else {
            showError = BKLightError.characteristicMissing.localizedDescription
            return
        }
        isSending = true
        statusMessage = nil
        defer { isSending = false }
        do {
            let png: Data?
            switch mode {
            case .calendar:
                let lines = calendar.todaySummaryLines()
                png = PanelBitmapRenderer.renderLines(lines)
            case .message:
                let lines = [messageText].flatMap { chunkLine($0) }
                png = PanelBitmapRenderer.renderLines(lines)
            case .flights:
                let lines = try await FlightBoardProvider.summaryLines()
                png = PanelBitmapRenderer.renderLines(lines)
            }
            guard let data = png else {
                showError = "Geen afbeelding gegenereerd."
                return
            }
            try await ble.sendPNG(data, rotationDegrees: 0, brightness: 1.0, stopAnimationFirst: true)
            statusMessage = "Verzonden."
        } catch {
            showError = error.localizedDescription
        }
    }

    private func chunkLine(_ s: String) -> [String] {
        if s.count <= 10 { return [s] }
        return [String(s.prefix(10)), String(s.dropFirst(10).prefix(10))]
    }
}

#Preview {
    ContentView()
        .environmentObject(BKLightBleClient())
        .environmentObject(CalendarEventsProvider())
}
