import Foundation

public enum RazerError: Error, LocalizedError, Equatable, Sendable {
  case malformed(String)
  case device(UInt8)
  case timeout, mismatch, unsupported
  case verification(String)
  case transport(String)
  public var errorDescription: String? {
    switch self {
    case .malformed(let s): return "设备响应无效：\(s)"
    case .device(let code): return String(format: "设备拒绝请求（状态 0x%02X）", code)
    case .timeout: return "设备暂未响应，可能休眠或被其他软件占用"
    case .mismatch: return "设备响应与请求不匹配"
    case .unsupported: return "此型号或设置尚未支持"
    case .verification(let s): return "\(s)写入后读回不一致，请刷新确认实际设置"
    case .transport(let s): return s
    }
  }
}

public protocol FeatureTransport: AnyObject {
  func send(_ bytes: [UInt8]) throws
  func receive() throws -> [UInt8]
}

public struct Command: Equatable, Sendable {
  public let group: UInt8
  public let id: UInt8
  public let size: Int
  public let arguments: [UInt8]
  public init(_ group: UInt8, _ id: UInt8, _ size: Int, _ arguments: [UInt8] = []) {
    self.group = group
    self.id = id
    self.size = size
    self.arguments = arguments
  }
  public func encoded() throws -> [UInt8] {
    guard (0...80).contains(size), arguments.count <= size else {
      throw RazerError.malformed("参数长度")
    }
    var bytes = [UInt8](repeating: 0, count: 90)
    bytes[1] = 0x1F
    bytes[5] = UInt8(size)
    bytes[6] = group
    bytes[7] = id
    for (i, value) in arguments.enumerated() { bytes[8 + i] = value }
    bytes[88] = Self.checksum(bytes)
    return bytes
  }
  public static func checksum(_ bytes: [UInt8]) -> UInt8 { bytes[2..<88].reduce(0, ^) }
  public func validate(_ bytes: [UInt8]) throws {
    guard bytes.count == 90 else { throw RazerError.malformed("报告应为 90 字节") }
    guard bytes[5] <= 80, bytes[4] == 0, bytes[2] == 0, bytes[3] == 0 else {
      throw RazerError.malformed("报告头")
    }
    guard bytes[88] == Self.checksum(bytes) else { throw RazerError.malformed("校验和") }
    guard bytes[1] == 0x1F, bytes[6] == group, bytes[7] == id else { throw RazerError.mismatch }
    if bytes[0] == 2 && bytes[5] < size { throw RazerError.malformed("响应参数不足") }
  }
}

public struct DPI: Equatable, Codable, Sendable {
  public let x: Int
  public let y: Int
  public init(x: Int, y: Int) {
    self.x = x
    self.y = y
  }
}

// One instance is owned exclusively by the HID worker's serial queue.
public final class RazerClient {
  private let transport: FeatureTransport
  private let pause: (TimeInterval) -> Void
  public let attempts: Int
  public init(
    transport: FeatureTransport, attempts: Int = 5,
    pause: @escaping (TimeInterval) -> Void = Thread.sleep
  ) {
    self.transport = transport
    self.attempts = max(1, attempts)
    self.pause = pause
  }
  public func execute(_ command: Command) throws -> [UInt8] {
    try transport.send(command.encoded())
    for attempt in 0..<attempts {
      pause(0.05 + Double(attempt) * 0.02)
      let bytes = try transport.receive()
      do { try command.validate(bytes) } catch RazerError.mismatch {
        if attempt + 1 < attempts { continue }
        throw RazerError.mismatch
      }
      switch bytes[0] {
      case 2: return bytes
      case 0, 1: continue
      default: throw RazerError.device(bytes[0])
      }
    }
    throw RazerError.timeout
  }
  public func battery() throws -> Int {
    let b = try execute(Command(7, 0x80, 2))
    return Int((Double(b[9]) * 100 / 255).rounded())
  }
  public func charging() throws -> Bool {
    let b = try execute(Command(7, 0x84, 2))
    guard b[9] <= 1 else { throw RazerError.malformed("充电状态") }
    return b[9] == 1
  }
  public func dpi() throws -> DPI {
    let b = try execute(Command(4, 0x85, 7, [0]))
    let result = DPI(x: Int(b[9]) << 8 | Int(b[10]), y: Int(b[11]) << 8 | Int(b[12]))
    guard (100...30000).contains(result.x), (100...30000).contains(result.y) else {
      throw RazerError.malformed("DPI 范围")
    }
    return result
  }
  public static let pollingCodes: [Int: UInt8] = [125: 8, 500: 2, 1000: 1]
  public func pollingRate() throws -> Int {
    let b = try execute(Command(0, 0x85, 1))
    guard let hz = Self.pollingCodes.first(where: { $0.value == b[8] })?.key else {
      throw RazerError.unsupported
    }
    return hz
  }
  public func setDPI(_ value: DPI) throws {
    guard (100...30000).contains(value.x), (100...30000).contains(value.y) else {
      throw RazerError.unsupported
    }
    _ = try execute(
      Command(
        4, 5, 7,
        [
          1, UInt8(value.x >> 8), UInt8(value.x & 255), UInt8(value.y >> 8), UInt8(value.y & 255),
          0, 0,
        ]))
    pause(0.08)
    guard try dpi() == value else { throw RazerError.verification("DPI") }
  }
  public func setPollingRate(_ hz: Int) throws {
    guard let code = Self.pollingCodes[hz] else { throw RazerError.unsupported }
    _ = try execute(Command(0, 5, 1, [code]))
    pause(0.08)
    guard try pollingRate() == hz else { throw RazerError.verification("回报率") }
  }
}
