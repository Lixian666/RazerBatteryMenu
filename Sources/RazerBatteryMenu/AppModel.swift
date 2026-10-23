import AppKit
import Combine
import RazerCore
import RazerHID
import ServiceManagement
import UserNotifications

enum MenuBarStyle: String, CaseIterable, Identifiable {
  case mouseAndPercentage
  case batteryAndPercentage
  case percentageOnly

  var id: String { rawValue }
  var title: String {
    switch self {
    case .mouseAndPercentage: return "鼠标"
    case .batteryAndPercentage: return "电池"
    case .percentageOnly: return "极简"
    }
  }
  var previewSymbol: String? {
    switch self {
    case .mouseAndPercentage: return "computermouse"
    case .batteryAndPercentage: return nil
    case .percentageOnly: return nil
    }
  }
}

@MainActor final class AppModel: ObservableObject {
  @Published var state = DeviceState()
  @Published var busy = false
  @Published var message: String?
  @Published var diagnostics = "正在检查设备…"
  @Published var devices: [DeviceDescriptor] = []
  @Published var notificationsEnabled = UserDefaults.standard.bool(
    forKey: "lowBatteryNotifications")
  @Published var loginEnabled = SMAppService.mainApp.status == .enabled
  @Published var loginNeedsApproval = SMAppService.mainApp.status == .requiresApproval
  @Published private(set) var menuBarStyle =
    MenuBarStyle(
      rawValue: UserDefaults.standard.string(forKey: "menuBarStyle") ?? ""
    ) ?? .mouseAndPercentage
  @Published private(set) var hidAccessStatus = HIDDiscovery.accessStatus()
  private nonisolated let worker = HIDWorker()
  private nonisolated let queue = DispatchQueue(label: "app.razerbatterymenu.hid", qos: .utility)
  private var timer: Timer?
  private var lastPoll = Date.distantPast
  private var observers: [NSObjectProtocol] = []
  private var sleeping = false
  private var generation = 0
  let demo: Bool
  private var preferredID: String? = UserDefaults.standard.string(forKey: "preferredDevice")
  private var notificationPending = Set<String>()
  private var lastWakeRefresh = Date.distantPast

  init(demo: Bool = false) {
    self.demo = demo
    if demo {
      let device = DeviceDescriptor(id: "preview", name: "Razer Basilisk V3 Pro", productID: 0xAB)
      devices = [device]
      state.select(device)
      state.success(
        Reading(battery: 84, charging: false, dpi: DPI(x: 1600, y: 1600), pollingRate: 1000))
      diagnostics = "界面预览 · 模拟数据，不代表硬件读数"
      return
    }
    worker.setActivityHandler { [weak self] in
      DispatchQueue.main.async { self?.handleDeviceActivity() }
    }
    refresh()
    timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
      Task { @MainActor in self?.tick() }
    }
    let center = NSWorkspace.shared.notificationCenter
    observers.append(
      center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) {
        [weak self] _ in
        Task { @MainActor in
          guard let self else { return }
          self.sleeping = true
          self.generation += 1
          self.queue.async { self.worker.reset() }
        }
      })
    observers.append(
      center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) {
        [weak self] _ in
        Task { @MainActor in
          guard let self else { return }
          self.sleeping = false
          self.lastPoll = .distantPast
          self.refresh()
        }
      })
  }
  private func handleDeviceActivity() {
    guard state.status == .sleeping, !busy, !sleeping else { return }
    let now = Date()
    guard now.timeIntervalSince(lastWakeRefresh) >= 0.1 else { return }
    lastWakeRefresh = now
    lastPoll = .distantPast
    refresh()
  }
  func choose(_ id: String) {
    preferredID = id
    UserDefaults.standard.set(id, forKey: "preferredDevice")
    refresh()
  }
  func setMenuBarStyle(_ style: MenuBarStyle) {
    menuBarStyle = style
    guard !demo else { return }
    UserDefaults.standard.set(style.rawValue, forKey: "menuBarStyle")
  }
  private func tick() {
    guard !busy, !sleeping else { return }
    if Date().timeIntervalSince(lastPoll) >= 60 {
      refresh()
      return
    }
    busy = true
    let token = generation
    queue.async {
      let inventory = self.worker.inventory()
      DispatchQueue.main.async {
        self.busy = false
        guard token == self.generation, !self.sleeping else { return }
        if inventory != self.devices {
          self.devices = inventory
          self.refresh()
        }
      }
    }
  }
  func refresh() {
    guard !demo, !busy, !sleeping else { return }
    busy = true
    message = nil
    let preferred = preferredID
    let token = generation
    queue.async {
      let result = self.worker.poll(preferredID: preferred)
      let inventory = self.worker.inventory()
      DispatchQueue.main.async {
        self.busy = false
        guard token == self.generation, !self.sleeping else { return }
        self.devices = inventory
        self.apply(result)
      }
    }
  }
  private func apply(_ result: PollResult) {
    hidAccessStatus = HIDDiscovery.accessStatus()
    lastPoll = Date()
    diagnostics = result.diagnostics
    if let error = result.error { diagnostics += "\n\n" + error }
    guard let device = result.device else {
      state.disconnect()
      return
    }
    if state.device?.id != device.id { state.select(device, cached: cachedReading(device.id)) }
    guard device.supported else {
      state.select(device)
      message = result.error
      return
    }
    if let reading = result.reading {
      state.success(reading)
      if let data = try? JSONEncoder().encode(reading) {
        UserDefaults.standard.set(data, forKey: "reading.\(device.id)")
      }
      message = result.error
      notifyIfNeeded(reading, device: device)
    } else if result.failure == .sleeping, state.reading != nil {
      state.sleep()
    } else {
      state.fail(result.error ?? "暂不可读")
    }
  }
  private func cachedReading(_ id: String) -> Reading? {
    guard let data = UserDefaults.standard.data(forKey: "reading.\(id)"),
      let r = try? JSONDecoder().decode(Reading.self, from: data), (0...100).contains(r.battery)
    else { return nil }
    return r
  }
  func setDPI(_ dpi: Int) { write { try $0.setDPI(DPI(x: dpi, y: dpi), expectedID: $1) } }
  func setRate(_ rate: Int) { write { try $0.setPollingRate(rate, expectedID: $1) } }
  private func write(_ action: @escaping @Sendable (HIDWorker, String) throws -> Void) {
    guard !demo, !busy, state.status == .ready, let id = state.device?.id else { return }
    busy = true
    message = nil
    let token = generation
    queue.async {
      var errorMessage: String?
      do { try action(self.worker, id) } catch { errorMessage = error.localizedDescription }
      let result = self.worker.poll(preferredID: id)
      let outcome = errorMessage
      DispatchQueue.main.async {
        self.busy = false
        guard token == self.generation, !self.sleeping else { return }
        self.apply(result)
        self.message = outcome ?? (result.reading == nil ? "写入已读回确认，但刷新失败，请重试。" : "设置已读回确认")
      }
    }
  }
  func setNotifications(_ enabled: Bool) {
    guard !demo else {
      notificationsEnabled = enabled
      return
    }
    if !enabled {
      notificationsEnabled = false
      UserDefaults.standard.set(false, forKey: "lowBatteryNotifications")
      return
    }
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) {
      allowed, error in
      Task { @MainActor in
        self.notificationsEnabled = allowed
        UserDefaults.standard.set(allowed, forKey: "lowBatteryNotifications")
        if !allowed { self.message = error?.localizedDescription ?? "通知未获允许，可在系统设置 → 通知中开启。" }
        if allowed, self.state.status == .ready, let r = self.state.reading,
          let d = self.state.device
        {
          self.notifyIfNeeded(r, device: d)
        }
      }
    }
  }
  private func notifyIfNeeded(_ reading: Reading, device: DeviceDescriptor) {
    let key = "notified.\(device.id)"
    var gate = LowBatteryGate(notified: UserDefaults.standard.bool(forKey: key))
    let notify = gate.shouldNotify(battery: reading.battery, charging: reading.charging)
    if reading.battery > 20 { UserDefaults.standard.set(false, forKey: key) }
    guard notificationsEnabled, notify, !notificationPending.contains(device.id) else { return }
    notificationPending.insert(device.id)
    let content = UNMutableNotificationContent()
    content.title = "鼠标电量偏低"
    content.body = "\(device.name) 剩余 \(reading.battery)%，请及时充电。"
    content.sound = .default
    let request = UNNotificationRequest(
      identifier: "lowBattery.\(device.id)", content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request) { error in
      Task { @MainActor in
        self.notificationPending.remove(device.id)
        if error == nil {
          UserDefaults.standard.set(true, forKey: key)
        } else {
          self.message = "低电量通知发送失败：\(error!.localizedDescription)"
        }
      }
    }
  }
  func setLogin(_ enabled: Bool) {
    guard !demo else {
      loginEnabled = enabled
      return
    }
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
    } catch { message = "登录启动设置失败：\(error.localizedDescription)" }
    updateLoginStatus()
  }
  func updateLoginStatus() {
    guard !demo else { return }
    loginEnabled = SMAppService.mainApp.status == .enabled
    loginNeedsApproval = SMAppService.mainApp.status == .requiresApproval
  }
  func showLoginSettings() { SMAppService.openSystemSettingsLoginItems() }
  func requestHIDAccess() {
    let granted = HIDDiscovery.requestAccess()
    hidAccessStatus = HIDDiscovery.accessStatus()
    if granted || hidAccessStatus == .granted {
      permissionMayHaveChanged()
      message = "输入监控已允许，正在重新连接鼠标。"
      return
    }
    openHIDPrivacySettings()
    message = "请在输入监控中允许「RazerBatteryMenu」，返回应用后会自动重新检测。"
  }
  func permissionMayHaveChanged() {
    let current = HIDDiscovery.accessStatus()
    guard current != hidAccessStatus || (current == .granted && state.status == .unreadable) else {
      return
    }
    hidAccessStatus = current
    guard current == .granted else { return }
    generation += 1
    queue.async { self.worker.reset() }
    lastPoll = .distantPast
    busy = false
    refresh()
  }
  private func openHIDPrivacySettings() {
    if let url = URL(
      string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    {
      NSWorkspace.shared.open(url)
    }
  }
  var needsHIDPermission: Bool {
    state.status == .unreadable && hidAccessStatus != .granted
  }
  var hidPermissionActionTitle: String {
    hidAccessStatus == .denied ? "打开输入监控设置…" : "允许输入监控…"
  }
  var statusText: String {
    switch state.status {
    case .disconnected: return "未连接"
    case .unsupported: return "型号暂未支持"
    case .unreadable: return needsHIDPermission ? "需要输入监控权限" : "暂不可读"
    case .sleeping: return "休眠待机"
    case .ready:
      switch state.reading?.charging {
      case true: return "正在充电"
      case false: return "电池供电"
      default: return "充电状态未知"
      }
    }
  }
  var title: String {
    guard state.device != nil, let r = state.reading else { return "—" }
    return "\(r.battery)%" + (state.status == .unreadable ? " ·" : "")
  }
}
