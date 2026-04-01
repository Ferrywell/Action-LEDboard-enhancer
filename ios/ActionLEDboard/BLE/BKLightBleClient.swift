import Combine
import CoreBluetooth
import Foundation

/// Shared timing; keep in sync with user-facing `BKLightError.gattDiscoveryTimeout` text.
private enum BKLightTiming {
    static let gattReadyTimeoutSeconds: TimeInterval = 18
}

enum BKLightError: LocalizedError {
    case bluetoothUnavailable
    /// Simulator or device without BLE hardware.
    case bluetoothUnsupported
    case bluetoothUnauthorized
    case notConnected
    case characteristicMissing
    case scanFailed
    case timeout(String)
    case transferFailed(String)
    case peripheralDisconnected
    /// GATT fa02/fa03 not discovered within `BKLightTiming.gattReadyTimeoutSeconds` after connect.
    case gattDiscoveryTimeout

    var errorDescription: String? {
        switch self {
        case .bluetoothUnavailable: return "Bluetooth is niet beschikbaar of uit."
        case .bluetoothUnsupported:
            return "Bluetooth LE is niet beschikbaar (bijv. Simulator). Gebruik een echte iPhone met Bluetooth."
        case .bluetoothUnauthorized:
            return "Geen Bluetooth-toegang. Zet dit aan bij Instellingen → Privacy → Bluetooth → Action LEDboard."
        case .notConnected: return "Geen verbinding met het paneel."
        case .characteristicMissing: return "Schrijf-/notify-kenmerk niet gevonden."
        case .scanFailed: return "Scannen mislukt."
        case .timeout(let s): return "Timeout: \(s)"
        case .transferFailed(let s): return s
        case .peripheralDisconnected: return "Verbinding verbroken."
        case .gattDiscoveryTimeout:
            return "Na \(Int(BKLightTiming.gattReadyTimeoutSeconds)) seconden geen GATT-kenmerken (schrijven fa02, notify fa03). Controleer het paneel of probeer opnieuw."
        }
    }
}

/// BK-Light BLE Central: scan via CoreBluetooth (same class of API as iPixel — not the same as Instellingen → Bluetooth).
/// Matches panels by advertised name and/or advertised service UUIDs (FA02/FA03); GATT fa02/fa03 after connect.
@MainActor
final class BKLightBleClient: NSObject, ObservableObject {
    @Published private(set) var isScanning = false
    @Published private(set) var discoveredPeripherals: [CBPeripheral] = []
    /// Local name from `CBAdvertisementDataLocalNameKey` (often arrives before `peripheral.name` is set).
    @Published private(set) var advertisementLocalNames: [UUID: String] = [:]
    @Published private(set) var connectedPeripheral: CBPeripheral?
    @Published private(set) var connectionState: ConnectionState = .idle
    @Published private(set) var isPanelReady = false
    @Published var lastNotifyHex: String?
    @Published var lastError: String?

    enum ConnectionState: Equatable {
        case idle
        case scanning
        case connecting
        case connected
        case disconnecting
    }

    private var central: CBCentralManager!
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?

    private var handshakeDone = false

    private struct NotifyAwaiter {
        let id: UUID
        let predicate: (Data) -> Bool
        let continuation: CheckedContinuation<Data, Error>
    }

    private var notifyAwaiters: [NotifyAwaiter] = []
    private var notifyTimeoutTasks: [UUID: Task<Void, Never>] = [:]
    /// If fa02/fa03 are not ready within `BKLightTiming.gattReadyTimeoutSeconds`, we set `lastError` and disconnect.
    private var gattReadyWatchTask: Task<Void, Never>?

    private let queue = DispatchQueue(label: "bklight.ble", qos: .userInitiated)

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: queue, options: [
            CBCentralManagerOptionShowPowerAlertKey: true,
        ])
    }

    func startScan() {
        guard central.state == .poweredOn else {
            lastError = BKLightError.bluetoothUnavailable.localizedDescription
            return
        }
        if #available(iOS 13.1, *) {
            switch CBCentralManager.authorization {
            case .denied, .restricted:
                lastError = BKLightError.bluetoothUnauthorized.localizedDescription
                return
            case .notDetermined, .allowedAlways:
                break
            @unknown default:
                break
            }
        }
        lastError = nil
        discoveredPeripherals.removeAll()
        advertisementLocalNames.removeAll()
        isScanning = true
        connectionState = .scanning
        // `nil`: discover by name and/or by advertised UUIDs (vendor apps do not rely on Instellingen → Bluetooth).
        // AllowDuplicates: first adv packet often has no local name; later packets fill it in.
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }

    /// Label for list rows (`peripheral.name` is often nil until connected).
    func displayLabel(for peripheral: CBPeripheral) -> String {
        if let n = peripheral.name, !n.isEmpty { return n }
        if let cached = advertisementLocalNames[peripheral.identifier] { return cached }
        let short = peripheral.identifier.uuidString.prefix(8)
        return "BK-Light paneel (\(short)…)"
    }

    func stopScan() {
        if central.state == .poweredOn {
            central.stopScan()
        }
        isScanning = false
        if connectionState == .scanning { connectionState = .idle }
    }

    func connect(_ peripheral: CBPeripheral) {
        guard central.state == .poweredOn else {
            lastError = BKLightError.bluetoothUnavailable.localizedDescription
            return
        }
        cancelGattReadyTimeout()
        stopScan()
        connectionState = .connecting
        isPanelReady = false
        connectedPeripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
    }

    func disconnect() {
        cancelGattReadyTimeout()
        guard let p = connectedPeripheral else { return }
        connectionState = .disconnecting
        handshakeDone = false
        isPanelReady = false
        writeCharacteristic = nil
        notifyCharacteristic = nil
        cancelAllAwaiters(with: BKLightError.peripheralDisconnected)
        if central.state == .poweredOn {
            central.cancelPeripheralConnection(p)
        } else {
            connectionState = .idle
            connectedPeripheral = nil
        }
    }

    // MARK: - High-level send (32×32 PNG pipeline; 16×32 needs hardware agreement)

    func sendPNG(_ pngData: Data, rotationDegrees: Int = 0, brightness: CGFloat = 1.0, stopAnimationFirst: Bool = true) async throws {
        try await ensureReady()
        if stopAnimationFirst {
            _ = try await sendCommandAndWaitAck(BKLightProtocol.displayModeCommand(mode: 1), timeout: 2.0)
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        // Skip re-encode when unchanged — `adjustPNG` used opaque:false and could produce RGBA PNGs some firmware decodes as blank.
        let processed: Data
        if rotationDegrees % 360 == 0 && abs(brightness - 1.0) < 0.001 {
            processed = pngData
        } else {
            processed = PanelBitmapRenderer.adjustPNG(pngData, rotationDegrees: rotationDegrees, brightness: brightness)
        }
        let frame = BKLightProtocol.buildFrame(pngBytes: processed)
        try await sendFramePacket(frame)
    }

    /// Firmware often treats 0% as “minimum on” or ignores it — use **1…100** only.
    func setBrightness(_ value: UInt8) async throws {
        let clamped = max(1, min(100, value))
        try await ensureReady()
        _ = try await sendCommandAndWaitAck(BKLightProtocol.brightnessCommand(value: clamped), timeout: 2.0)
    }

    func setDisplayMode(_ mode: UInt8) async throws {
        try await ensureReady()
        _ = try await sendCommandAndWaitAck(BKLightProtocol.displayModeCommand(mode: mode), timeout: 2.0)
    }

    // MARK: - GATT ready timeout (fa02 / fa03)

    private func cancelGattReadyTimeout() {
        gattReadyWatchTask?.cancel()
        gattReadyWatchTask = nil
    }

    private func scheduleGattReadyTimeout(for peripheral: CBPeripheral) {
        cancelGattReadyTimeout()
        let peripheralId = peripheral.identifier
        gattReadyWatchTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: UInt64(BKLightTiming.gattReadyTimeoutSeconds * 1_000_000_000))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            guard self.connectedPeripheral?.identifier == peripheralId else { return }
            guard !self.isPanelReady else { return }
            self.gattReadyWatchTask = nil
            self.lastError = BKLightError.gattDiscoveryTimeout.localizedDescription
            self.disconnect()
        }
    }

    // MARK: - Internals

    /// On iPhone the firmware often advertises a friendly name (e.g. `Pixel board – ACT1026`); PC tools may still show `LED_BLE_*`.
    /// `nonisolated`: called from `nonisolated` `CBCentralManagerDelegate` callbacks (BLE queue).
    private nonisolated static func isLikelyBKLightPanel(name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let lower = trimmed.lowercased()
        if lower.hasPrefix("led_ble_") { return true }
        if lower.contains("pixel board") { return true }
        if lower.contains("act1026") { return true }
        return false
    }

    /// Vendor apps (e.g. iPixel) match devices that advertise GATT service/characteristic UUIDs in the BLE advertisement.
    private nonisolated static func advertisedBKLightServiceUUIDs(from advertisementData: [String: Any]) -> [CBUUID] {
        var out: [CBUUID] = []
        if let a = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] { out.append(contentsOf: a) }
        if let b = advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID] { out.append(contentsOf: b) }
        return out
    }

    private nonisolated static func advertisementMatchesBKLightServices(_ uuids: [CBUUID]) -> Bool {
        for u in uuids {
            let s = u.uuidString.uppercased()
            if s.contains("FA02") || s.contains("FA03") { return true }
        }
        return false
    }

    private func ensureReady() async throws {
        guard connectedPeripheral != nil else {
            throw BKLightError.notConnected
        }
        guard isPanelReady, writeCharacteristic != nil, notifyCharacteristic != nil else {
            throw BKLightError.characteristicMissing
        }
    }

    private func cancelAllAwaiters(with error: Error) {
        for a in notifyAwaiters {
            notifyTimeoutTasks[a.id]?.cancel()
            notifyTimeoutTasks[a.id] = nil
            a.continuation.resume(throwing: error)
        }
        notifyAwaiters.removeAll()
    }

    private func failAwaiter(id: UUID, error: Error) {
        guard let idx = notifyAwaiters.firstIndex(where: { $0.id == id }) else { return }
        let entry = notifyAwaiters.remove(at: idx)
        notifyTimeoutTasks[id]?.cancel()
        notifyTimeoutTasks[id] = nil
        entry.continuation.resume(throwing: error)
    }

    private func waitForNotify(id: UUID, predicate: @escaping (Data) -> Bool, timeout: TimeInterval) async throws -> Data {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
            notifyAwaiters.append(NotifyAwaiter(id: id, predicate: predicate, continuation: cont))
            let t = Task {
                do {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    await MainActor.run {
                        guard let idx = notifyAwaiters.firstIndex(where: { $0.id == id }) else { return }
                        let entry = notifyAwaiters.remove(at: idx)
                        notifyTimeoutTasks[id] = nil
                        entry.continuation.resume(throwing: BKLightError.timeout("notify"))
                    }
                } catch {
                    // cancelled
                }
            }
            notifyTimeoutTasks[id] = t
        }
    }

    private func sendCommandAndWaitAck(_ cmd: Data, timeout: TimeInterval) async throws -> Data {
        try await ensureReady()
        let id = UUID()
        async let response = waitForNotify(id: id, predicate: { BKLightProtocol.isCommandAck($0) }, timeout: timeout)
        do {
            try await writeAll(cmd, description: "cmd")
        } catch {
            failAwaiter(id: id, error: error)
            throw error
        }
        return try await response
    }

    private func sendFramePacket(_ frame: Data) async throws {
        try await ensureReady()
        if !handshakeDone {
            try await runHandshake()
        }
        try await writeAll(BKLightProtocol.cmdEditEnd, description: "edit_end")
        try await Task.sleep(nanoseconds: 50_000_000)
        let id = UUID()
        async let response = waitForNotify(id: id, predicate: { $0 == BKLightProtocol.ackStageThree }, timeout: 5.0)
        do {
            try await writeAll(frame, description: "frame")
        } catch {
            failAwaiter(id: id, error: error)
            throw error
        }
        _ = try await response
        try await Task.sleep(nanoseconds: 200_000_000)
    }

    /// Matches Python: optional ACKs on handshake; timeouts are non-fatal for stage one/two.
    private func runHandshake() async throws {
        try await ensureReady()
        cancelAllAwaiters(with: BKLightError.transferFailed("handshake reset"))

        let id1 = UUID()
        do {
            async let response = waitForNotify(id: id1, predicate: { $0 == BKLightProtocol.ackStageOne }, timeout: 5.0)
            do {
                try await writeAll(BKLightProtocol.handshakeFirst, description: "hs1")
            } catch {
                failAwaiter(id: id1, error: error)
                throw error
            }
            _ = try await response
        } catch {
            // Python: log and continue on stage one timeout / missing ACK
        }
        try await Task.sleep(nanoseconds: 200_000_000)

        cancelAllAwaiters(with: BKLightError.transferFailed("handshake stage2 reset"))
        let id2 = UUID()
        do {
            async let response = waitForNotify(id: id2, predicate: { $0 == BKLightProtocol.ackStageTwo }, timeout: 5.0)
            do {
                try await writeAll(BKLightProtocol.handshakeSecond, description: "hs2")
            } catch {
                failAwaiter(id: id2, error: error)
                throw error
            }
            _ = try await response
        } catch {
            // Python: optional stage two
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        handshakeDone = true
    }

    private func writeAll(_ data: Data, description: String) async throws {
        guard let peripheral = connectedPeripheral, let ch = writeCharacteristic else {
            throw BKLightError.notConnected
        }
        let maxChunk = max(20, peripheral.maximumWriteValueLength(for: .withResponse))
        let chunkSize = min(BKLightProtocol.bleWriteChunkSize, maxChunk)
        var offset = 0
        while offset < data.count {
            let end = min(offset + chunkSize, data.count)
            let chunk = data.subdata(in: offset..<end)
            try await writeWithResponse(peripheral, characteristic: ch, data: chunk)
            offset = end
            if offset < data.count {
                try await Task.sleep(nanoseconds: 5_000_000)
            }
        }
    }

    private func writeWithResponse(_ peripheral: CBPeripheral, characteristic: CBCharacteristic, data: Data) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            pendingWriteContinuation = cont
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
        }
    }

    private var pendingWriteContinuation: CheckedContinuation<Void, Error>?

    private func deliverNotify(_ payload: Data) {
        lastNotifyHex = payload.map { String(format: "%02X", $0) }.joined(separator: " ")
        if let i = notifyAwaiters.firstIndex(where: { $0.predicate(payload) }) {
            let entry = notifyAwaiters.remove(at: i)
            notifyTimeoutTasks[entry.id]?.cancel()
            notifyTimeoutTasks[entry.id] = nil
            entry.continuation.resume(returning: payload)
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BKLightBleClient: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            // Do not treat `.unknown` / `.resetting` as failure — avoids false "Bluetooth uit" and API misuse
            // if UI calls APIs before the stack is ready.
            switch central.state {
            case .poweredOn:
                self.lastError = nil
            case .poweredOff:
                self.lastError = BKLightError.bluetoothUnavailable.localizedDescription
            case .unauthorized:
                self.lastError = BKLightError.bluetoothUnauthorized.localizedDescription
            case .unsupported:
                self.lastError = BKLightError.bluetoothUnsupported.localizedDescription
            case .unknown, .resetting:
                break
            @unknown default:
                break
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // Prefer advertisement local name (often set before peripheral.name on iOS).
        let advName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = [advName, peripheral.name].compactMap { $0 }.first { !$0.isEmpty } ?? ""
        let advServices = Self.advertisedBKLightServiceUUIDs(from: advertisementData)
        let matches = Self.isLikelyBKLightPanel(name: name) || Self.advertisementMatchesBKLightServices(advServices)
        guard matches else { return }
        Task { @MainActor in
            if let advName, !advName.isEmpty {
                self.advertisementLocalNames[peripheral.identifier] = advName
            }
            if let idx = self.discoveredPeripherals.firstIndex(where: { $0.identifier == peripheral.identifier }) {
                self.discoveredPeripherals[idx] = peripheral
            } else {
                self.discoveredPeripherals.append(peripheral)
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            self.connectionState = .connected
            self.lastError = nil
            self.connectedPeripheral = peripheral
            peripheral.delegate = self
            self.scheduleGattReadyTimeout(for: peripheral)
            peripheral.discoverServices(nil)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            self.cancelGattReadyTimeout()
            self.connectionState = .idle
            self.connectedPeripheral = nil
            self.isPanelReady = false
            self.writeCharacteristic = nil
            self.notifyCharacteristic = nil
            self.lastError = error?.localizedDescription ?? BKLightError.scanFailed.localizedDescription
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            self.cancelGattReadyTimeout()
            self.connectionState = .idle
            self.connectedPeripheral = nil
            self.writeCharacteristic = nil
            self.notifyCharacteristic = nil
            self.handshakeDone = false
            self.isPanelReady = false
            self.cancelAllAwaiters(with: BKLightError.peripheralDisconnected)
            if let error {
                self.lastError = error.localizedDescription
            }
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BKLightBleClient: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            if let error {
                self.lastError = error.localizedDescription
                return
            }
            guard let services = peripheral.services else { return }
            for s in services {
                peripheral.discoverCharacteristics([BKLightGATT.write, BKLightGATT.notify], for: s)
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        Task { @MainActor in
            if let error {
                self.lastError = error.localizedDescription
                return
            }
            guard let chars = service.characteristics else { return }
            for c in chars {
                if c.uuid == BKLightGATT.write {
                    self.writeCharacteristic = c
                }
                if c.uuid == BKLightGATT.notify {
                    self.notifyCharacteristic = c
                    peripheral.setNotifyValue(true, for: c)
                }
            }
            self.isPanelReady = self.writeCharacteristic != nil && self.notifyCharacteristic != nil
            if self.isPanelReady {
                self.cancelGattReadyTimeout()
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value else { return }
        Task { @MainActor in
            self.deliverNotify(data)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            if let cont = self.pendingWriteContinuation {
                self.pendingWriteContinuation = nil
                if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume()
                }
            }
        }
    }
}
