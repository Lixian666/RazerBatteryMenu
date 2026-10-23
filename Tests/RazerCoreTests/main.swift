import Foundation

private var failures = 0
private var checks = 0
func fail(_ message: String, file: StaticString, line: UInt) {
  failures += 1
  fputs("FAIL \(file):\(line): \(message)\n", stderr)
}
func assertEqual<T: Equatable>(
  _ actual: T, _ expected: T, file: StaticString = #filePath, line: UInt = #line
) {
  if actual != expected { fail("\(actual) != \(expected)", file: file, line: line) }
}
func assertTrue(_ actual: Bool, file: StaticString = #filePath, line: UInt = #line) {
  if !actual { fail("expected true", file: file, line: line) }
}
func assertFalse(_ actual: Bool, file: StaticString = #filePath, line: UInt = #line) {
  if actual { fail("expected false", file: file, line: line) }
}
func assertNil<T>(_ actual: T?, file: StaticString = #filePath, line: UInt = #line) {
  if actual != nil { fail("expected nil", file: file, line: line) }
}
func assertThrowsError<T>(
  _ expression: @autoclosure () throws -> T, file: StaticString = #filePath, line: UInt = #line,
  _ handler: (Error) -> Void = { _ in }
) {
  do {
    _ = try expression()
    fail("expected error", file: file, line: line)
  } catch { handler(error) }
}
func check(_ name: String, _ body: () throws -> Void) {
  checks += 1
  let before = failures
  do { try body() } catch { fail("unexpected \(error)", file: #filePath, line: #line) }
  print("\(failures == before ? "PASS" : "FAIL") \(name)")
}
check("ProtocolTests.testBatteryQueryMatchesWireFixture") {
  try ProtocolTests().testBatteryQueryMatchesWireFixture()
}
check("ProtocolTests.testBatteryRoundingAndGenuineZero") {
  try ProtocolTests().testBatteryRoundingAndGenuineZero()
}
check("ProtocolTests.testBusyAndNewRetryWithoutResending") {
  try ProtocolTests().testBusyAndNewRetryWithoutResending()
}
check("ProtocolTests.testEchoNeverTreatedAsZeroBattery") {
  ProtocolTests().testEchoNeverTreatedAsZeroBattery()
}
check("ProtocolTests.testDeviceFailureIsNotRetried") {
  ProtocolTests().testDeviceFailureIsNotRetried()
}
check("ProtocolTests.testRejectsShortChecksumAndInvalidLength") {
  ProtocolTests().testRejectsShortChecksumAndInvalidLength()
}
check("ProtocolTests.testStaleCommandResponseCanRecover") {
  try ProtocolTests().testStaleCommandResponseCanRecover()
}
check("ProtocolTests.testWrongTransactionRejected") {
  ProtocolTests().testWrongTransactionRejected()
}
check("ProtocolTests.testTransportFailurePropagates") {
  ProtocolTests().testTransportFailurePropagates()
}
check("ProtocolTests.testChargingMalformedValueRejected") {
  ProtocolTests().testChargingMalformedValueRejected()
}
check("ProtocolTests.testDPIWriteRequiresReadbackAndPreservesXY") {
  try ProtocolTests().testDPIWriteRequiresReadbackAndPreservesXY()
}
check("ProtocolTests.testDPIReadbackMismatchFails") {
  ProtocolTests().testDPIReadbackMismatchFails()
}
check("ProtocolTests.testPollingCodesAndReadback") {
  try ProtocolTests().testPollingCodesAndReadback()
}
check("ProtocolTests.testPollingReadbackMismatchFails") {
  ProtocolTests().testPollingReadbackMismatchFails()
}
check("ProtocolTests.testUnsupportedSettingsNeverSent") {
  ProtocolTests().testUnsupportedSettingsNeverSent()
}
check("ProtocolTests.testInvalidCommandCannotOverflowReport") {
  ProtocolTests().testInvalidCommandCannotOverflowReport()
}
check("StateTests.testFailureRetainsLastReadingAndTimestamp") {
  StateTests().testFailureRetainsLastReadingAndTimestamp()
}
check("StateTests.testSleepingPreservesLastReadingUntilPhysicalDisconnect") {
  StateTests().testSleepingPreservesLastReadingUntilPhysicalDisconnect()
}
check("StateTests.testSwitchDeviceDoesNotLeakCachedBattery") {
  StateTests().testSwitchDeviceDoesNotLeakCachedBattery()
}
check("StateTests.testRestoreCacheIsStaleUntilFreshResponse") {
  StateTests().testRestoreCacheIsStaleUntilFreshResponse()
}
check("StateTests.test35KAndOtherReceiversNotEnabled") {
  StateTests().test35KAndOtherReceiversNotEnabled()
}
check("StateTests.testLowBatteryOncePerCycle") { StateTests().testLowBatteryOncePerCycle() }
check("StateTests.testUnknownChargingAndFailedNotification") {
  StateTests().testUnknownChargingAndFailedNotification()
}
print("\(checks) tests, \(failures) failures")
exit(failures == 0 ? 0 : 1)
