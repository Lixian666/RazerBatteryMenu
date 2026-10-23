import Foundation
import RazerCore
import RazerHID

let worker = HIDWorker()
let result = worker.poll()
print(result.diagnostics)
if let r = result.reading {
  print(
    "battery=\(r.battery)% charging=\(String(describing: r.charging)) dpi=\(String(describing: r.dpi)) polling=\(String(describing: r.pollingRate))"
  )
} else {
  print("未取得有效硬件读数")
}
if let error = result.error { print(error) }
if CommandLine.arguments.contains("--verify-settings") {
  guard let id = result.device?.id, let dpi = result.reading?.dpi,
    let rate = result.reading?.pollingRate
  else {
    print("无法取得原始设置，取消写入测试")
    exit(2)
  }
  var failures: [String] = []
  let alternative = DPI(
    x: dpi.x == 800 && dpi.y == 800 ? 1600 : 800, y: dpi.x == 800 && dpi.y == 800 ? 1600 : 800)
  do {
    try worker.setDPI(alternative, expectedID: id)
    print("PASS DPI changed and read back: \(alternative)")
  } catch { failures.append("DPI write: \(error.localizedDescription)") }
  do {
    try worker.setDPI(dpi, expectedID: id)
    print("PASS original DPI restored and verified: \(dpi)")
  } catch {
    print("RESTORE FAILED: 原 DPI \(dpi)。\(error.localizedDescription)")
    exit(3)
  }
  do {
    try worker.setPollingRate(rate == 500 ? 1000 : 500, expectedID: id)
    print("PASS polling rate changed and read back")
  } catch { failures.append("Polling write: \(error.localizedDescription)") }
  do {
    try worker.setPollingRate(rate, expectedID: id)
    print("PASS original polling restored and verified: \(rate) Hz")
  } catch {
    print("RESTORE FAILED: 原回报率 \(rate) Hz。\(error.localizedDescription)")
    exit(3)
  }
  for failure in failures { print("FAIL \(failure)") }
  exit(failures.isEmpty ? 0 : 2)
}
exit(result.reading == nil ? 2 : 0)
