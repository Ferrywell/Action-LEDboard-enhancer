import Combine
import CoreBluetooth
import Foundation

/// Shared timing; keep in sync with user-facing `BKLightError.gattDiscoveryTimeout` text.
private enum BKLightTiming {
    static let gattReadyTimeoutSeconds: TimeInterval = 18
}

enum BKLightError: LocalizedError {
    case bluetoothUnavailable
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

/// BK-Light BLE Central: scan `LED_BLE_*`, GATT fa02/fa03, writes with notification ACKs (see display_session.py).
@MainActor
final class BKLightBleClient: NSObject, ObservableObject {
    @Published private(set) var isScanning = false
    @Published private(set) var discoveredPeripherals: [CBPeripheral] = []
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
        lastError = nil
        discoveredPeripherals.removeAll()
        isScanning = true
        connectionState = .scanning
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    func stopScan() {
        central.stopScan()
        isScanning = false
        if connectionState == .scanning { connectionState = .idle }
    }

    func connect(_ peripheral: CBPeripheral) {
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
        central.cancelPeripheralConnection(p)
    }

    // MARK: - High-level send (32×32 PNG pipeline; 16×32 needs hardware agreement)

    func sendPNG(_ pngData: Data, rotationDegrees: Int = 0, brightness: CGFloat = 1.0, stopAnimationFirst: Bool = true) async throws {
        try await ensureReady()
        if stopAnimationFirst {
            _ = try await sendCommandAndWaitAck(BKLightProtocol.displayModeCommand(mode: 1), timeout: 2.0)
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        let processed = PanelBitmapRenderer.adjustPNG(pngData, rotationDegrees: rotationDegrees, brightness: brightness)
        let frame = BKLightProtocol.buildFrame(pngBytes: processed)
        try await sendFramePacket(frame)
    }

    func setBrightness(_ value: UInt8) async throws {
        try await ensureReady()
        _ = try await sendCommandAndWaitAck(BKLightProtocol.brightnessCommand(value: value), timeout: 2.0)
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
            if central.state != .poweredOn {
                self.lastError = BKLightError.bluetoothUnavailable.localizedDescription
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? ""
        guard name.hasPrefix("LED_BLE_") else { return }
        Task { @MainActor in
            if !self.discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
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
