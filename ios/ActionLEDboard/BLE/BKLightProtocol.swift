import CoreBluetooth
import Foundation
import zlib

// Bytes aligned with `reference/panel-hopper-github/vendor/bk_light/display_session.py`.
// Do not change without protocol agreement. 16×32 panels may need different handshake values — see docs/reference/HARDWARE.md.

enum BKLightGATT {
    static let write = CBUUID(string: "0000FA02-0000-1000-8000-00805F9B34FB")
    static let notify = CBUUID(string: "0000FA03-0000-1000-8000-00805F9B34FB")
}

enum BKLightProtocol {
    static let uuidWrite = BKLightGATT.write
    static let uuidNotify = BKLightGATT.notify

    static let handshakeFirst = Data([0x08, 0x00, 0x01, 0x80, 0x0E, 0x06, 0x32, 0x00])
    static let handshakeSecond = Data([0x04, 0x00, 0x05, 0x80])

    static let ackStageOne = Data([0x0C, 0x00, 0x01, 0x80, 0x81, 0x06, 0x32, 0x00, 0x00, 0x01, 0x00, 0x01])
    static let ackStageTwo = Data([0x08, 0x00, 0x05, 0x80, 0x0B, 0x03, 0x07, 0x02])
    static let ackStageThree = Data([0x05, 0x00, 0x02, 0x00, 0x03])

    static let cmdBrightnessPrefix = Data([0x05, 0x00, 0x04, 0x80])
    static let cmdRotationPrefix = Data([0x05, 0x00, 0x06, 0x80])
    static let cmdOnOffPrefix = Data([0x05, 0x00, 0x07, 0x01])
    static let cmdDeleteAll = Data([0x04, 0x00, 0x03, 0x80])
    static let cmdEditEnd = Data([0x05, 0x00, 0x04, 0x01, 0x00])
    static let cmdSavePrepare = Data([0x07, 0x00, 0x02, 0x01, 0x01, 0x00, 0x01])
    static let cmdSaveCommit = Data([0x07, 0x00, 0x02, 0x01, 0x01, 0x00, 0x02])
    static let cmdDisplayModePrefix = Data([0x07, 0x00, 0x08, 0x80, 0x01, 0x00])

    static let dataTypeImage = Data([0x02, 0x00])
    static let dataTypeGIF = Data([0x03, 0x00])

    /// Same chunk size as iPixel analysis in display_session.py (GIF path).
    static let gifChunkPayloadMax = 12288
    /// BLE sub-packet size when splitting writes (matches Python GIF `MTU_SIZE = 500`).
    static let bleWriteChunkSize = 500

    static func crc32(_ data: Data) -> UInt32 {
        data.withUnsafeBytes { buf in
            let base = buf.bindMemory(to: UInt8.self).baseAddress!
            return UInt32(zlib.crc32(0, base, UInt32(data.count)))
        }
    }

    /// Static image frame (iPixel / SendCore layout).
    static func buildFrame(pngBytes: Data, isGIFFrame: Bool = false, frameIndex: Int = 0) -> Data {
        let dataLength = UInt32(pngBytes.count)
        let totalLength = UInt16(pngBytes.count + 15)
        var frame = Data()
        frame.append(contentsOf: withUnsafeBytes(of: totalLength.littleEndian) { Data($0) })
        frame.append(isGIFFrame ? dataTypeGIF : dataTypeImage)
        frame.append(UInt8(frameIndex > 0 ? 0x02 : 0x00))
        frame.append(contentsOf: withUnsafeBytes(of: dataLength.littleEndian) { Data($0) })
        let c = crc32(pngBytes)
        frame.append(contentsOf: withUnsafeBytes(of: c.littleEndian) { Data($0) })
        frame.append(isGIFFrame ? 0x02 : 0x00)
        frame.append(0x65)
        frame.append(pngBytes)
        return frame
    }

    static func displayModeCommand(mode: UInt8) -> Data {
        var d = cmdDisplayModePrefix
        d.append(mode)
        return d
    }

    static func brightnessCommand(value: UInt8) -> Data {
        cmdBrightnessPrefix + Data([Swift.min(100 as UInt8, value)])
    }

    static func rotationCommand(quarterTurns: UInt8) -> Data {
        cmdRotationPrefix + Data([quarterTurns % 4])
    }

    static func onOffCommand(on: Bool) -> Data {
        cmdOnOffPrefix + Data([on ? 1 : 0])
    }
}

extension BKLightProtocol {
    /// Whether notification payload matches known command ACK pattern (see AckWatcher.handler in Python).
    static func isCommandAck(_ payload: Data) -> Bool {
        guard payload.count >= 4 else { return false }
        let id = payload.subdata(in: 2..<4)
        let known: Set<Data> = [
            Data([0x04, 0x80]), Data([0x06, 0x80]), Data([0x07, 0x01]),
            Data([0x02, 0x01]), Data([0x08, 0x80]), Data([0x04, 0x01]), Data([0x03, 0x80]),
        ]
        return known.contains(id)
    }

    static func isGIFChunkAck(_ payload: Data) -> Bool {
        payload.count == 5 && payload[0..<4] == Data([0x05, 0x00, 0x03, 0x00])
    }

    static func gifChunkAckKind(_ payload: Data) -> UInt8? {
        guard isGIFChunkAck(payload) else { return nil }
        return payload[4]
    }
}
