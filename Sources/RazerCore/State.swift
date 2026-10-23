import Foundation

public struct DeviceDescriptor: Identifiable, Equatable, Codable, Sendable {
  public let id: String
  public let name: String
  public let productID: Int
  public var supported: Bool { productID == 0xAA || productID == 0xAB }
  public var connection: String { productID == 0xAA ? "USB 有线" : "2.4G 接收器" }
  public init(id: String, name: String, productID: Int) {
    self.id = id
    self.name = name
    self.productID = productID
  }
}

public struct Reading: Codable, Equatable, Sendable {
  public let battery: Int
  public let charging: Bool?
  public let dpi: DPI?
  public let pollingRate: Int?
  public let date: Date
  public init(battery: Int, charging: Bool?, dpi: DPI?, pollingRate: Int?, date: Date = Date()) {
    self.battery = battery
    self.charging = charging
    self.dpi = dpi
    self.pollingRate = pollingRate
    self.date = date
  }
}
public enum ConnectionState: String, Sendable {
  case disconnected, unsupported, unreadable, sleeping, ready
}
public struct DeviceState: Sendable {
  public private(set) var device: DeviceDescriptor?
  public private(set) var reading: Reading?
  public private(set) var status: ConnectionState = .disconnected
  public private(set) var error: String?
  public init() {}
  public mutating func select(_ device: DeviceDescriptor?, cached: Reading? = nil) {
    self.device = device
    reading = cached
    error = nil
    status = device == nil ? .disconnected : (device!.supported ? .unreadable : .unsupported)
  }
  public mutating func success(_ reading: Reading) {
    self.reading = reading
    status = .ready
    error = nil
  }
  public mutating func fail(_ message: String) {
    status = device == nil ? .disconnected : .unreadable
    error = message
  }
  public mutating func sleep(_ message: String? = nil) {
    guard device != nil, reading != nil else {
      fail(message ?? "暂不可读")
      return
    }
    status = .sleeping
    error = message
  }
  public mutating func disconnect() {
    device = nil
    reading = nil
    status = .disconnected
    error = nil
  }
}
public struct LowBatteryGate {
  public private(set) var notified: Bool
  public init(notified: Bool = false) { self.notified = notified }
  public mutating func shouldNotify(battery: Int, charging: Bool?) -> Bool {
    if battery > 20 {
      notified = false
      return false
    }
    guard charging == false, !notified else { return false }
    notified = true
    return true
  }
  public mutating func deliveryFailed() { notified = false }
}
