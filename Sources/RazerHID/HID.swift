import Foundation
import IOKit
import IOKit.hid
import RazerCore

public struct HIDCandidate {
  public let descriptor: DeviceDescriptor
  public let device: IOHIDDevice
  public let featureSize: Int
  public let inputSize: Int
  public let usagePage: Int
  public let usage: Int
  public let transport: String
  public var suitable: Bool { descriptor.supported && featureSize == 90 && transport == "USB" }
}

public enum HIDAccessStatus: Equatable, Sendable {
  case granted
  case denied
  case unknown
}

public enum HIDDiscovery {
  public static func enumerate() -> [HIDCandidate] {
    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: 0x1532] as CFDictionary)
    let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? []
    return devices.map { device in
      func number(_ key: String) -> Int {
        (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.intValue ?? 0
      }
      func string(_ key: String) -> String {
        IOHIDDeviceGetProperty(device, key as CFString) as? String ?? ""
      }
      let pid = number(kIOHIDProductIDKey)
      let location = number(kIOHIDLocationIDKey)
      // Registry identity is used only when no physical location is exposed. Serial numbers are not logged.
      var entry: UInt64 = 0
      IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(device), &entry)
      let identity = location != 0 ? "\(pid)-\(location)" : "\(pid)-registry-\(entry)"
      let name = string(kIOHIDProductKey)
      return HIDCandidate(
        descriptor: DeviceDescriptor(
          id: identity, name: name.isEmpty ? "Razer 设备" : name, productID: pid),
        device: device, featureSize: number(kIOHIDMaxFeatureReportSizeKey),
        inputSize: number(kIOHIDMaxInputReportSizeKey),
        usagePage: number(kIOHIDPrimaryUsagePageKey), usage: number(kIOHIDPrimaryUsageKey),
        transport: string(kIOHIDTransportKey))
    }.sorted {
      if $0.suitable != $1.suitable { return $0.suitable }
      return $0.descriptor.id < $1.descriptor.id
    }
  }
  public static func accessStatus() -> HIDAccessStatus {
    switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
    case kIOHIDAccessTypeGranted: return .granted
    case kIOHIDAccessTypeDenied: return .denied
    default: return .unknown
    }
  }
  public static func requestAccess() -> Bool { IOHIDRequestAccess(kIOHIDRequestTypeListenEvent) }
}

private enum HIDTransportError: Error, LocalizedError {
  case permission(String)
  case busy(String)
  case unavailable(String)
  case communication(String)

  var errorDescription: String? {
    switch self {
    case .permission(let message), .busy(let message), .unavailable(let message),
      .communication(let message):
      return message
    }
  }
}

private final class HIDActivityBox {
  let callback: @Sendable () -> Void
  init(_ callback: @escaping @Sendable () -> Void) { self.callback = callback }
}

public final class HIDTransport: FeatureTransport {
  private let device: IOHIDDevice
  private let inputBuffer: UnsafeMutablePointer<UInt8>
  private let inputBufferSize: Int
  private var activityContext: UnsafeMutableRawPointer?
  private var opened = false

  public init(candidate: HIDCandidate, onActivity: @escaping @Sendable () -> Void = {}) throws {
    guard candidate.suitable else { throw RazerError.unsupported }
    device = candidate.device
    inputBufferSize = max(1, candidate.inputSize)
    inputBuffer = .allocate(capacity: inputBufferSize)
    inputBuffer.initialize(repeating: 0, count: inputBufferSize)
    activityContext = nil
    try Self.check(
      IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone)), operation: "打开控制接口")
    opened = true
    let context = Unmanaged.passRetained(HIDActivityBox(onActivity)).toOpaque()
    activityContext = context
    IOHIDDeviceRegisterInputReportCallback(
      device, inputBuffer, inputBufferSize, Self.inputReportCallback, context)
    IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
  }
  deinit {
    if let activityContext {
      IOHIDDeviceRegisterInputReportCallback(device, inputBuffer, inputBufferSize, nil, nil)
      IOHIDDeviceUnscheduleFromRunLoop(
        device, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
      Unmanaged<HIDActivityBox>.fromOpaque(activityContext).release()
    }
    if opened { IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone)) }
    inputBuffer.deinitialize(count: inputBufferSize)
    inputBuffer.deallocate()
  }
  private static let inputReportCallback: IOHIDReportCallback = {
    context, result, _, type, _, _, reportLength in
    guard result == kIOReturnSuccess, type == kIOHIDReportTypeInput, reportLength > 0, let context
    else { return }
    Unmanaged<HIDActivityBox>.fromOpaque(context).takeUnretainedValue().callback()
  }
  public func send(_ bytes: [UInt8]) throws {
    let result = bytes.withUnsafeBufferPointer {
      IOHIDDeviceSetReport(device, kIOHIDReportTypeFeature, 0, $0.baseAddress!, bytes.count)
    }
    try Self.check(result, operation: "发送查询")
  }
  public func receive() throws -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: 90)
    var count = bytes.count
    let result = bytes.withUnsafeMutableBufferPointer {
      IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 0, $0.baseAddress!, &count)
    }
    try Self.check(result, operation: "读取响应")
    guard count >= 0, count <= bytes.count else { throw RazerError.malformed("HID 长度") }
    return Array(bytes.prefix(count))
  }
  private static func check(_ result: IOReturn, operation: String) throws {
    guard result != kIOReturnSuccess else { return }
    let code = String(format: "0x%08X", result)
    if result == kIOReturnNotPermitted || result == kIOReturnNotPrivileged {
      throw HIDTransportError.permission(
        "\(operation)被 macOS 拒绝（\(code)）。请允许本应用的「输入监控」后重新启动；若仍失败，检查其他鼠标软件是否占用接口。")
    }
    if result == kIOReturnExclusiveAccess || result == kIOReturnBusy {
      throw HIDTransportError.busy("控制接口被其他软件占用（\(code)），请退出其他鼠标管理软件后重试。")
    }
    if result == kIOReturnNoDevice || result == kIOReturnNotResponding || result == kIOReturnOffline
    {
      throw HIDTransportError.unavailable("设备暂未响应（\(code)）")
    }
    throw HIDTransportError.communication("\(operation)失败（\(code)）")
  }
}

public enum PollFailure: Equatable, Sendable {
  case disconnected, unsupported, permission, busy, sleeping, communication
}

public struct PollResult: Sendable {
  public let device: DeviceDescriptor?
  public let reading: Reading?
  public let error: String?
  public let failure: PollFailure?
  public let diagnostics: String
}

// A recursive lock protects the complete request/readback transaction and discovery state.
public final class HIDWorker: @unchecked Sendable {
  private let lock = NSRecursiveLock()
  private var client: RazerClient?
  private var selected: DeviceDescriptor?
  private var candidates: [HIDCandidate] = []
  private let activityLock = NSLock()
  private var activityHandler: (@Sendable () -> Void)?
  public init() {}
  public func setActivityHandler(_ handler: (@Sendable () -> Void)?) {
    activityLock.lock()
    activityHandler = handler
    activityLock.unlock()
  }
  private func emitActivity() {
    activityLock.lock()
    let handler = activityHandler
    activityLock.unlock()
    handler?()
  }
  public func reset() {
    lock.lock()
    defer { lock.unlock() }
    client = nil
    selected = nil
    candidates = []
  }
  public func inventory() -> [DeviceDescriptor] {
    lock.lock()
    defer { lock.unlock() }
    candidates = HIDDiscovery.enumerate()
    var seen = Set<String>()
    return candidates.filter { seen.insert($0.descriptor.id).inserted }.map(\.descriptor)
  }
  public func poll(preferredID: String? = nil) -> PollResult {
    lock.lock()
    defer { lock.unlock() }
    let devices = inventory()
    let choice =
      preferredID.flatMap { id in devices.first { $0.id == id } } ?? devices.first(
        where: \.supported) ?? devices.first
    let diagnostic = candidates.map { c in
      String(
        format: "%@ | VID 1532 PID %04X | %@ | usage %04X:%04X | feature %d", c.descriptor.name,
        c.descriptor.productID, c.transport, c.usagePage, c.usage, c.featureSize)
    }.joined(separator: "\n")
    guard let choice else {
      reset()
      return PollResult(
        device: nil, reading: nil, error: nil, failure: .disconnected, diagnostics: "未发现雷蛇 HID 设备")
    }
    if selected?.id != choice.id {
      client = nil
      selected = choice
    }
    guard choice.supported else {
      return PollResult(
        device: choice, reading: nil, error: "已识别该设备，但首版仅支持普通 Basilisk V3 Pro（00AA / 00AB）。",
        failure: .unsupported, diagnostics: diagnostic)
    }
    do {
      if client == nil {
        let controls = candidates.filter { $0.descriptor.id == choice.id && $0.suitable }
        guard !controls.isEmpty else {
          throw RazerError.transport("没有找到 90 字节 USB 控制接口。请检查连接方式或鼠标驱动。")
        }
        var lastError: Error = RazerError.unsupported
        for c in controls {
          do {
            client = RazerClient(
              transport: try HIDTransport(candidate: c) { [weak self] in self?.emitActivity() })
            break
          } catch { lastError = error }
        }
        if client == nil { throw lastError }
      }
      let c = client!
      let battery = try c.battery()
      var warnings: [String] = []
      func optional<T>(_ label: String, _ read: () throws -> T) -> T? {
        do { return try read() } catch {
          warnings.append("\(label)：\(error.localizedDescription)")
          return nil
        }
      }
      let charging = optional("充电状态", c.charging)
      let dpi = optional("DPI", c.dpi)
      let rate = optional("回报率", c.pollingRate)
      return PollResult(
        device: choice,
        reading: Reading(battery: battery, charging: charging, dpi: dpi, pollingRate: rate),
        error: warnings.isEmpty ? nil : warnings.joined(separator: "\n"), failure: nil,
        diagnostics: diagnostic)
    } catch {
      let failure = Self.classify(error)
      if failure != .sleeping { client = nil }
      return PollResult(
        device: choice, reading: nil, error: error.localizedDescription, failure: failure,
        diagnostics: diagnostic)
    }
  }
  private static func classify(_ error: Error) -> PollFailure {
    if case RazerError.timeout = error { return .sleeping }
    switch error {
    case HIDTransportError.permission: return .permission
    case HIDTransportError.busy: return .busy
    case HIDTransportError.unavailable: return .sleeping
    default: return .communication
    }
  }
  public func setDPI(_ value: DPI, expectedID: String) throws {
    lock.lock()
    defer { lock.unlock() }
    guard selected?.id == expectedID, let client else { throw RazerError.transport("设备已变化，请刷新后重试") }
    try client.setDPI(value)
  }
  public func setPollingRate(_ value: Int, expectedID: String) throws {
    lock.lock()
    defer { lock.unlock() }
    guard selected?.id == expectedID, let client else { throw RazerError.transport("设备已变化，请刷新后重试") }
    try client.setPollingRate(value)
  }
}
