import CoreBluetooth
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
    @State private var showBleTip = false
    /// 0…100 — hardware brightness (`BKLightBleClient.setBrightness`); debounced when sliding.
    @State private var panelBrightness = 70.0
    @State private var brightnessSendTask: Task<Void, Never>?

    enum PanelMode: String, CaseIterable, Identifiable {
        case calendar = "Kalender"
        case message = "Bericht"
        case flights = "Vluchten"
        var id: String { rawValue }
    }

    private var canSendToPanel: Bool {
        ble.connectedPeripheral != nil && ble.isPanelReady
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    connectionSection
                    if ble.connectedPeripheral != nil {
                        brightnessSection
                    }
                    modeSection
                    modeContentSection
                    sendSection
                    DisclosureGroup {
                        Text(
                            "Voor langere sessies op de achtergrond: UIBackgroundModes bluetooth-central en state restoration. Writes worden in segmenten verstuurd conform het BK-Light-protocol (MTU/chunks)."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    } label: {
                        Label("Ontwikkelaarsnotities", systemImage: "chevron.left.forwardslash.chevron.right")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Action LEDboard")
            .navigationBarTitleDisplayMode(.large)
            .alert("Fout", isPresented: Binding(
                get: { showError != nil },
                set: { if !$0 { showError = nil } }
            )) {
                Button("OK", role: .cancel) { showError = nil }
            } message: {
                Text(showError ?? "")
            }
            .onChange(of: ble.connectedPeripheral?.identifier) { _, _ in
                brightnessSendTask?.cancel()
                brightnessSendTask = nil
            }
            .sheet(isPresented: $showBleTip) {
                NavigationStack {
                    ScrollView {
                        Text(
                            "Het LED-paneel staat meestal niet bij Instellingen → Bluetooth (dat is voor koptelefoons en koppelen). Deze app zoekt via BLE, net als iPixel Color. Zorg dat het paneel aan staat, niet door een andere telefoon of PC is verbonden, en dat deze app Bluetooth mag gebruiken (Instellingen → Privacy en beveiliging → Bluetooth)."
                        )
                        .font(.body)
                        .padding()
                    }
                    .navigationTitle("Zo werkt BLE")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Sluiten") { showBleTip = false }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Verbinding (BLE)

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Paneel")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Meer info") { showBleTip = true }
                    .font(.caption)
                    .buttonStyle(.borderless)
            }

            Text(bleStatusLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button {
                    ble.startScan()
                } label: {
                    Label("Zoek paneel", systemImage: "antenna.radiowaves.left.and.right")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(ble.connectionState == .connecting)

                Button("Stop") {
                    ble.stopScan()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            if let bleErr = ble.lastError {
                Text(bleErr)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if ble.isScanning {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Zoeken naar paneel…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if ble.discoveredPeripherals.isEmpty, !ble.isScanning, ble.lastError == nil {
                Text(emptyDiscoveryHint)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(ble.discoveredPeripherals, id: \.identifier) { p in
                panelRow(p)
            }

            if let cp = ble.connectedPeripheral {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: "link.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Verbonden")
                                .font(.subheadline.weight(.medium))
                            Text(ble.displayLabel(for: cp))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Verbreken") {
                            ble.disconnect()
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                    if ble.connectionState == .connected, !ble.isPanelReady {
                        Label("Paneel initialiseren (GATT)…", systemImage: "hourglass")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                )
            }

            if let h = ble.lastNotifyHex {
                Text("Laatste notify: \(h)")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    private var brightnessSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Helderheid paneel")
                .font(.title3.weight(.semibold))
            HStack {
                Image(systemName: "sun.min")
                    .foregroundStyle(.secondary)
                Slider(value: $panelBrightness, in: 0...100, step: 1)
                    .tint(.white)
                Image(systemName: "sun.max.fill")
                    .foregroundStyle(.secondary)
            }
            Text("\(Int(panelBrightness))%")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            Text("Stel helderheid in op het LED-paneel (los van je bericht).")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .opacity(ble.isPanelReady ? 1 : 0.45)
        .disabled(!ble.isPanelReady)
        .onChange(of: panelBrightness) { _, new in
            scheduleBrightnessSend(new)
        }
    }

    private func scheduleBrightnessSend(_ value: Double) {
        brightnessSendTask?.cancel()
        let target = UInt8(clamping: Int(value.rounded()))
        brightnessSendTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard !Task.isCancelled else { return }
            guard ble.isPanelReady else { return }
            do {
                try await ble.setBrightness(target)
            } catch {
                showError = error.localizedDescription
            }
        }
    }

    private var bleStatusLine: String {
        switch ble.connectionState {
        case .idle:
            return ble.isScanning ? "Zoeken…" : "Niet verbonden. Tik op Zoek paneel."
        case .scanning:
            return "Zoeken naar een BK-Light / Pixel board in de buurt."
        case .connecting:
            return "Verbinden…"
        case .connected:
            return ble.isPanelReady ? "Klaar om te sturen." : "Verbonden, wacht op paneel…"
        case .disconnecting:
            return "Verbreken…"
        }
    }

    private var emptyDiscoveryHint: String {
        "Nog geen paneel in de lijst. Tik op Zoek paneel, houd het paneel dichtbij en aan."
    }

    private func panelRow(_ p: CBPeripheral) -> some View {
        let isActive = ble.connectedPeripheral?.identifier == p.identifier
        return Button {
            ble.connect(p)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isActive ? Color.green : Color.secondary)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ble.displayLabel(for: p))
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text("Tik om te verbinden")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(uiColor: .tertiarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Verbindt met dit paneel")
    }

    // MARK: - Modus

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Weergave")
                .font(.title3.weight(.semibold))
            Picker("Weergave", selection: $mode) {
                ForEach(PanelMode.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Kies wat je op het paneel toont")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    // MARK: - Inhoud per modus

    private var modeContentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inhoud")
                .font(.title3.weight(.semibold))

            Group {
                switch mode {
                case .calendar:
                    Text("Toont agenda van vandaag (EventKit). Ruimte is 32×32 — korte tekst.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button {
                        Task {
                            do {
                                _ = try await calendar.requestAccess()
                            } catch {
                                showError = error.localizedDescription
                            }
                        }
                    } label: {
                        Label("Kalendertoegang geven", systemImage: "calendar")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                case .message:
                    TextField("Tekst op het paneel", text: $messageText)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.sentences)

                case .flights:
                    Text("Vluchten in de regio via OpenSky (indicatief, geen API-key).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    // MARK: - Versturen

    private var sendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Naar het paneel")
                .font(.title3.weight(.semibold))

            Button {
                Task { await sendCurrentMode() }
            } label: {
                HStack {
                    if isSending {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.up.circle.fill")
                            .font(.title2)
                    }
                    Text(isSending ? "Bezig…" : "Naar paneel sturen")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canSendToPanel || isSending)

            Text(sendHint)
                .font(.footnote)
                .foregroundStyle(sendHintStyle)
                .fixedSize(horizontal: false, vertical: true)

            if let s = statusMessage {
                Label(s, systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    private var sendHint: String {
        if isSending { return "Even geduld…" }
        if ble.connectedPeripheral == nil {
            return "Verbind eerst: kies een paneel in de lijst hierboven wanneer die verschijnt."
        }
        if !ble.isPanelReady {
            return "Wacht tot het paneel klaar is (initialisatie na verbinden)."
        }
        return "Stuurt de huidige weergave naar het verbonden paneel."
    }

    private var sendHintStyle: Color {
        if canSendToPanel && !isSending { return .secondary }
        if isSending { return .secondary }
        return .orange
    }

    // MARK: - Acties

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
            statusMessage = "Verzonden naar het paneel."
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
