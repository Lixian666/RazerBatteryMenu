import Foundation
import RazerCore

final class MockTransport: FeatureTransport {
  var sent: [[UInt8]] = []
  var responses: [[UInt8]] = []
  var failure: Error?
  func send(_ bytes: [UInt8]) throws {
    if let failure { throw failure }
    sent.append(bytes)
  }
  func receive() throws -> [UInt8] {
    if let failure { throw failure }
    guard !responses.isEmpty else { throw RazerError.timeout }
    return responses.removeFirst()
  }
}
func response(_ command: Command, args: [UInt8] = [], status: UInt8 = 2) -> [UInt8] {
  var b = try! command.encoded()
  b[0] = status
  for (i, v) in args.enumerated() { b[i + 8] = v }
  b[88] = Command.checksum(b)
  return b
}
final class ProtocolTests {
  let battery = Command(7, 0x80, 2)
  func client(_ mock: MockTransport, attempts: Int = 5) -> RazerClient {
    RazerClient(transport: mock, attempts: attempts, pause: { _ in })
  }
  func testBatteryQueryMatchesWireFixture() throws {
    let bytes = try battery.encoded()
    assertEqual(bytes.count, 90)
    assertEqual(Array(bytes.prefix(10)), [0, 0x1F, 0, 0, 0, 2, 7, 0x80, 0, 0])
    assertEqual(bytes[88], 0x85)
    assertEqual(bytes[89], 0)
  }
  func testBatteryRoundingAndGenuineZero() throws {
    for (raw, expected) in [(0, 0), (128, 50), (214, 84), (255, 100)] {
      let m = MockTransport()
      m.responses = [response(battery, args: [0, UInt8(raw)])]
      assertEqual(try client(m).battery(), expected)
    }
  }
  func testBusyAndNewRetryWithoutResending() throws {
    let m = MockTransport()
    m.responses = [
      response(battery, status: 0), response(battery, status: 1),
      response(battery, args: [0, 255]),
    ]
    assertEqual(try client(m).battery(), 100)
    assertEqual(m.sent.count, 1)
  }
  func testEchoNeverTreatedAsZeroBattery() {
    let m = MockTransport()
    m.responses = Array(repeating: response(battery, status: 0), count: 3)
    assertThrowsError(try client(m, attempts: 3).battery()) {
      assertEqual($0 as? RazerError, .timeout)
    }
  }
  func testDeviceFailureIsNotRetried() {
    let m = MockTransport()
    m.responses = [response(battery, status: 3), response(battery)]
    assertThrowsError(try client(m).battery()) { assertEqual($0 as? RazerError, .device(3)) }
    assertEqual(m.responses.count, 1)
  }
  func testRejectsShortChecksumAndInvalidLength() {
    var corrupt = response(battery)
    corrupt[88] ^= 1
    var badLength = response(battery)
    badLength[5] = 81
    badLength[88] = Command.checksum(badLength)
    var shortPayload = response(battery)
    shortPayload[5] = 1
    shortPayload[88] = Command.checksum(shortPayload)
    for bytes in [Array(response(battery).prefix(10)), corrupt, badLength, shortPayload] {
      let m = MockTransport()
      m.responses = [bytes]
      assertThrowsError(try client(m).battery())
    }
  }
  func testStaleCommandResponseCanRecover() throws {
    let m = MockTransport()
    m.responses = [response(Command(7, 0x84, 2)), response(battery, args: [0, 128])]
    assertEqual(try client(m).battery(), 50)
  }
  func testWrongTransactionRejected() {
    var b = response(battery)
    b[1] = 0xFF
    let m = MockTransport()
    m.responses = [b]
    assertThrowsError(try client(m, attempts: 1).battery()) {
      assertEqual($0 as? RazerError, .mismatch)
    }
  }
  func testTransportFailurePropagates() {
    let m = MockTransport()
    m.failure = RazerError.transport("denied")
    assertThrowsError(try client(m).battery()) {
      assertEqual($0 as? RazerError, .transport("denied"))
    }
  }
  func testChargingMalformedValueRejected() {
    let m = MockTransport()
    m.responses = [response(Command(7, 0x84, 2), args: [0, 42])]
    assertThrowsError(try client(m).charging())
  }
  func testDPIWriteRequiresReadbackAndPreservesXY() throws {
    let m = MockTransport()
    m.responses = [
      response(Command(4, 5, 7)), response(Command(4, 0x85, 7), args: [0, 6, 64, 3, 32, 0, 0]),
    ]
    try client(m).setDPI(DPI(x: 1600, y: 800))
    assertEqual(Array(m.sent[0][8..<15]), [1, 6, 64, 3, 32, 0, 0])
    assertEqual(m.sent[1][7], 0x85)
  }
  func testDPIReadbackMismatchFails() {
    let m = MockTransport()
    m.responses = [
      response(Command(4, 5, 7)), response(Command(4, 0x85, 7), args: [0, 3, 32, 3, 32, 0, 0]),
    ]
    assertThrowsError(try client(m).setDPI(DPI(x: 1600, y: 1600))) {
      assertEqual($0 as? RazerError, .verification("DPI"))
    }
  }
  func testPollingCodesAndReadback() throws {
    for (hz, code) in RazerClient.pollingCodes {
      let m = MockTransport()
      m.responses = [response(Command(0, 5, 1)), response(Command(0, 0x85, 1), args: [code])]
      try client(m).setPollingRate(hz)
      assertEqual(m.sent[0][8], code)
      assertEqual(m.sent[0][7], 5)
    }
  }
  func testPollingReadbackMismatchFails() {
    let m = MockTransport()
    m.responses = [response(Command(0, 5, 1)), response(Command(0, 0x85, 1), args: [2])]
    assertThrowsError(try client(m).setPollingRate(1000)) {
      assertEqual($0 as? RazerError, .verification("回报率"))
    }
  }
  func testUnsupportedSettingsNeverSent() {
    let m = MockTransport()
    assertThrowsError(try client(m).setPollingRate(8000))
    assertThrowsError(try client(m).setDPI(DPI(x: 0, y: 1600)))
    assertTrue(m.sent.isEmpty)
  }
  func testInvalidCommandCannotOverflowReport() {
    assertThrowsError(try Command(0, 0, 81).encoded())
    assertThrowsError(try Command(0, 0, 1, [1, 2]).encoded())
  }
}
final class StateTests {
  let device = DeviceDescriptor(id: "a", name: "Basilisk", productID: 0xAB)
  let reading = Reading(battery: 84, charging: false, dpi: nil, pollingRate: nil)
  func testFailureRetainsLastReadingAndTimestamp() {
    var s = DeviceState()
    s.select(device)
    s.success(reading)
    s.fail("timeout")
    assertEqual(s.reading, reading)
    assertEqual(s.status, .unreadable)
    s.disconnect()
    assertNil(s.reading)
    assertEqual(s.status, .disconnected)
  }
  func testSleepingPreservesLastReadingUntilPhysicalDisconnect() {
    var s = DeviceState()
    s.select(device)
    s.success(reading)
    s.sleep()
    assertEqual(s.reading, reading)
    assertEqual(s.status, .sleeping)
    assertNil(s.error)
    s.disconnect()
    assertNil(s.reading)
    assertEqual(s.status, .disconnected)
  }
  func testSwitchDeviceDoesNotLeakCachedBattery() {
    var s = DeviceState()
    s.select(device)
    s.success(reading)
    s.select(DeviceDescriptor(id: "b", name: "Other", productID: 0xAB))
    assertNil(s.reading)
  }
  func testRestoreCacheIsStaleUntilFreshResponse() {
    var s = DeviceState()
    s.select(device, cached: reading)
    assertEqual(s.status, .unreadable)
    assertEqual(s.reading, reading)
  }
  func test35KAndOtherReceiversNotEnabled() {
    for pid in [0xCC, 0xCD, 0xB3, 0xC1] {
      let d = DeviceDescriptor(id: "x", name: "Razer", productID: pid)
      var s = DeviceState()
      s.select(d)
      assertFalse(d.supported)
      assertEqual(s.status, .unsupported)
    }
  }
  func testLowBatteryOncePerCycle() {
    var gate = LowBatteryGate()
    assertTrue(gate.shouldNotify(battery: 20, charging: false))
    assertFalse(gate.shouldNotify(battery: 19, charging: false))
    assertFalse(gate.shouldNotify(battery: 19, charging: true))
    assertFalse(gate.shouldNotify(battery: 18, charging: false))
    assertFalse(gate.shouldNotify(battery: 21, charging: false))
    assertTrue(gate.shouldNotify(battery: 20, charging: false))
  }
  func testUnknownChargingAndFailedNotification() {
    var gate = LowBatteryGate()
    assertFalse(gate.shouldNotify(battery: 10, charging: nil))
    assertTrue(gate.shouldNotify(battery: 10, charging: false))
    gate.deliveryFailed()
    assertTrue(gate.shouldNotify(battery: 10, charging: false))
    var restored = LowBatteryGate(notified: gate.notified)
    assertFalse(restored.shouldNotify(battery: 10, charging: false))
  }
}
