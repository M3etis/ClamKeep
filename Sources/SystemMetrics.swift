import Foundation
import IOKit
import IOKit.ps
import Darwin

/// Read-only snapshot of host metrics for the menu bar.
struct SystemSnapshot {
    var batteryPercent: Int?
    var batteryIsCharging: Bool?
    var batteryTimeRemaining: TimeInterval?
    var cpuPercent: Double?
    var ramUsedBytes: UInt64?
    var ramTotalBytes: UInt64?
    var cpuTemperatureCelsius: Double?
    var fanRPMs: [Double] = []
}

enum SystemMetrics {
    /// Guards `previousCPUInfo` and SMC I/O — `warmUp()` runs off the main thread.
    private static let stateLock = NSLock()

    static func snapshot() -> SystemSnapshot {
        stateLock.lock()
        defer { stateLock.unlock() }

        var s = SystemSnapshot()
        readBattery(into: &s)
        readCPU(into: &s)
        readRAM(into: &s)
        SMCReader.shared.read(into: &s)
        return s
    }

    /// Two samples with a short gap so `cpuPercent` is ready before the first menu open.
    /// Call off the main thread — this blocks for ~80 ms.
    static func warmUp() {
        DispatchQueue.global(qos: .utility).async {
            _ = snapshot()
            Thread.sleep(forTimeInterval: 0.08)
            _ = snapshot()
        }
    }

    // MARK: - Battery

    private static func readBattery(into s: inout SystemSnapshot) {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return
        }

        for ps in list {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, ps)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            let type = desc[kIOPSTypeKey] as? String
            if type != nil && type != kIOPSInternalBatteryType { continue }

            if let cur = desc[kIOPSCurrentCapacityKey] as? Int,
               let max = desc[kIOPSMaxCapacityKey] as? Int,
               max > 0 {
                s.batteryPercent = Int((Double(cur) / Double(max) * 100).rounded())
            }
            if let charging = desc[kIOPSIsChargingKey] as? Bool {
                s.batteryIsCharging = charging
            } else if let state = desc[kIOPSPowerSourceStateKey] as? String {
                s.batteryIsCharging = (state == kIOPSACPowerValue)
            }
            if let time = desc[kIOPSTimeToEmptyKey] as? Int, time >= 0 {
                s.batteryTimeRemaining = TimeInterval(time) * 60
            } else if let time = desc[kIOPSTimeToFullChargeKey] as? Int, time >= 0 {
                s.batteryTimeRemaining = TimeInterval(time) * 60
            }
            if s.batteryPercent != nil { break }
        }
    }

    // MARK: - CPU

    private static var previousCPUInfo: [UInt32]?

    private static func readCPU(into s: inout SystemSnapshot) {
        var cpuCount: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var cpuInfoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                         &cpuCount, &cpuInfo, &cpuInfoCount)
        guard result == KERN_SUCCESS, let info = cpuInfo else { return }
        defer {
            vm_deallocate(mach_task_self_,
                          vm_address_t(UInt(bitPattern: info)),
                          vm_size_t(Int(cpuInfoCount) * MemoryLayout<integer_t>.stride))
        }

        let stride = Int(CPU_STATE_MAX)
        let raw = UnsafeBufferPointer(start: info, count: Int(cpuInfoCount))
        var ticks = [UInt32]()
        ticks.reserveCapacity(Int(cpuCount) * stride)
        for i in 0..<Int(cpuCount) * stride {
            ticks.append(UInt32(bitPattern: raw[i]))
        }

        if let prev = previousCPUInfo, prev.count == ticks.count {
            var totalBusy: UInt64 = 0
            var totalAll: UInt64 = 0
            for cpu in 0..<Int(cpuCount) {
                let base = cpu * stride
                let user = UInt64(ticks[base + Int(CPU_STATE_USER)] &- prev[base + Int(CPU_STATE_USER)])
                let system = UInt64(ticks[base + Int(CPU_STATE_SYSTEM)] &- prev[base + Int(CPU_STATE_SYSTEM)])
                let nice = UInt64(ticks[base + Int(CPU_STATE_NICE)] &- prev[base + Int(CPU_STATE_NICE)])
                let idle = UInt64(ticks[base + Int(CPU_STATE_IDLE)] &- prev[base + Int(CPU_STATE_IDLE)])
                totalBusy += user + system + nice
                totalAll += user + system + nice + idle
            }
            if totalAll > 0 {
                s.cpuPercent = Double(totalBusy) / Double(totalAll) * 100
            }
        }

        previousCPUInfo = ticks
    }

    // MARK: - RAM

    private static func readRAM(into s: inout SystemSnapshot) {
        s.ramTotalBytes = ProcessInfo.processInfo.physicalMemory

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS, let total = s.ramTotalBytes else { return }

        let page = UInt64(vm_kernel_page_size)
        let used = (UInt64(stats.active_count) + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)) * page
        s.ramUsedBytes = min(used, total)
    }
}

// MARK: - SMC parameter layout
//
// Must match C `SMCKeyData_t` byte-for-byte (80 bytes). Swift reuses trailing
// padding of nested structs, so the layout is kept flat with explicit pads.

private typealias SMCBytes = (
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
)

private struct SMCParamStruct {
    var key: UInt32 = 0                 // 0
    var vMajor: UInt8 = 0               // 4
    var vMinor: UInt8 = 0               // 5
    var vBuild: UInt8 = 0               // 6
    var vReserved: UInt8 = 0            // 7
    var vRelease: UInt16 = 0            // 8
    var padAfterVers: UInt16 = 0        // 10
    var pLimitVersion: UInt16 = 0       // 12
    var pLimitLength: UInt16 = 0        // 14
    var cpuPLimit: UInt32 = 0           // 16
    var gpuPLimit: UInt32 = 0           // 20
    var memPLimit: UInt32 = 0           // 24
    var dataSize: UInt32 = 0            // 28
    var dataType: UInt32 = 0            // 32
    var dataAttributes: UInt8 = 0       // 36
    var padKeyInfo0: UInt8 = 0          // 37
    var padKeyInfo1: UInt8 = 0          // 38
    var padKeyInfo2: UInt8 = 0          // 39
    var result: UInt8 = 0               // 40
    var status: UInt8 = 0               // 41
    var data8: UInt8 = 0                // 42
    var padBeforeData32: UInt8 = 0      // 43
    var data32: UInt32 = 0              // 44
    var bytes: SMCBytes = (
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    )                                   // 48..79
}

private let kSMCHandleYPCEvent: UInt32 = 2
private let kSMC_CMD_READ_BYTES: UInt8 = 5
private let kSMC_CMD_READ_KEYINFO: UInt8 = 9

private func smcFourChar(_ s: String) -> UInt32 {
    var result: UInt32 = 0
    for b in s.utf8 { result = (result << 8) + UInt32(b) }
    return result
}

/// Minimal AppleSMC client. Keys this Mac does not expose return nil.
private final class SMCClient {
    private var connection: io_connect_t = 0
    private let isOpen: Bool

    init() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else {
            isOpen = false
            return
        }
        defer { IOObjectRelease(service) }
        var conn: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, 0, &conn) == KERN_SUCCESS else {
            isOpen = false
            return
        }
        connection = conn
        isOpen = true
    }

    deinit {
        if isOpen { IOServiceClose(connection) }
    }

    func read(key: String) -> (type: UInt32, bytes: [UInt8])? {
        guard isOpen, key.utf8.count == 4 else { return nil }

        let code = smcFourChar(key)
        var input = SMCParamStruct()
        input.key = code
        input.data8 = kSMC_CMD_READ_KEYINFO
        guard call(&input) == KERN_SUCCESS, input.result == 0 else { return nil }

        let size = input.dataSize
        let type = input.dataType
        guard size > 0, size <= 32 else { return nil }

        // Kernel response does not echo `key`; reuse the original code.
        var output = SMCParamStruct()
        output.key = code
        output.dataSize = size
        output.data8 = kSMC_CMD_READ_BYTES
        guard call(&output) == KERN_SUCCESS, output.result == 0 else { return nil }

        let b = output.bytes
        var bytes: [UInt8] = [
            b.0, b.1, b.2, b.3, b.4, b.5, b.6, b.7,
            b.8, b.9, b.10, b.11, b.12, b.13, b.14, b.15,
            b.16, b.17, b.18, b.19, b.20, b.21, b.22, b.23,
            b.24, b.25, b.26, b.27, b.28, b.29, b.30, b.31
        ]
        if Int(size) < bytes.count {
            bytes.removeLast(bytes.count - Int(size))
        }
        return (type, bytes)
    }

    private func call(_ input: inout SMCParamStruct) -> kern_return_t {
        // SMCParamStruct is a flat 80-byte C mirror — both must match `SMCKeyData_t`.
        assert(MemoryLayout<SMCParamStruct>.size == 80 && MemoryLayout<SMCParamStruct>.stride == 80)
        let inputSize = MemoryLayout<SMCParamStruct>.size
        var output = SMCParamStruct()
        var outputSize = MemoryLayout<SMCParamStruct>.size
        let kr = IOConnectCallStructMethod(connection, kSMCHandleYPCEvent, &input, inputSize, &output, &outputSize)
        input = output
        return kr
    }
}

final class SMCReader {
    static let shared = SMCReader()

    private let client = SMCClient()

    /// Common CPU-temperature keys across Intel and Apple Silicon.
    private static let tempKeys = [
        "Tp09", "Tp01", "Tp0T", "Tp0P",   // Apple Silicon CPU/package
        "TC0P", "TC0E", "TC0F", "TC0D",   // Intel CPU
        "TG0B", "TG0C", "TG0H",           // package / GPU-adjacent (ioft)
        "TH0T", "Ts0P", "TCXC", "TCGC"
    ]

    func read(into s: inout SystemSnapshot) {
        readTemperature(into: &s)
        readFans(into: &s)
    }

    private func readTemperature(into s: inout SystemSnapshot) {
        for key in Self.tempKeys {
            guard let (type, bytes) = client.read(key: key) else { continue }
            if let value = decodeTemperature(type: type, bytes: bytes), value > 0, value < 110 {
                s.cpuTemperatureCelsius = value
                return
            }
        }
    }

    private func readFans(into s: inout SystemSnapshot) {
        guard let (_, bytes) = client.read(key: "FNum") else { return }
        let count = Int(bytes.first ?? 0)
        guard count > 0, count <= 10 else { return }

        for i in 0..<count {
            let key = String(format: "F%dAc", i)
            guard let (type, b) = client.read(key: key) else { continue }
            if let rpm = decodeFan(type: type, bytes: b), rpm > 0 {
                s.fanRPMs.append(rpm)
            }
        }
    }

    private func decodeTemperature(type: UInt32, bytes: [UInt8]) -> Double? {
        // "sp78" — signed 7.8 fixed point, big-endian
        if type == 0x7370_3738 {
            guard bytes.count >= 2 else { return nil }
            let raw = Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
            return Double(raw) / 256.0
        }
        // "flt " — IEEE-754 float, little-endian on Apple Silicon
        if type == 0x666C_7420 {
            return decodeLEFloat(bytes)
        }
        // "ioft" — 16.16 fixed point, little-endian (8-byte value)
        if type == 0x696F_6674 {
            guard bytes.count >= 4 else { return nil }
            let v = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
            return Double(Int32(bitPattern: v)) / 65536.0
        }
        if type == 0x7569_3820 {
            return Double(bytes.first ?? 0)
        }
        return nil
    }

    private func decodeFan(type: UInt32, bytes: [UInt8]) -> Double? {
        // "flt " — modern Macs report RPM as little-endian float
        if type == 0x666C_7420 {
            return decodeLEFloat(bytes)
        }
        // "fpe2" — unsigned 14.2 fixed point (older Macs)
        if type == 0x6670_6532 {
            guard bytes.count >= 2 else { return nil }
            let raw = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
            return Double(raw) / 4.0
        }
        return nil
    }

    private func decodeLEFloat(_ bytes: [UInt8]) -> Double? {
        guard bytes.count >= 4 else { return nil }
        let v = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
        let f = Float(bitPattern: v)
        guard f.isFinite else { return nil }
        return Double(f)
    }
}
