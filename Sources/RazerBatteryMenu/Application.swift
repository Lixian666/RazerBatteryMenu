import AppKit
import Combine
import SwiftUI
import UserNotifications

private final class MenuBarPanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
  private var statusItem: NSStatusItem!
  private var panel: MenuBarPanel!
  private var model: AppModel!
  private var subscription: AnyCancellable?
  private var previewWindow: NSWindow?
  private var localEventMonitor: Any?
  private var globalEventMonitor: Any?
  private let panelWidth: CGFloat = 360
  private var panelHeight: CGFloat = 540
  func applicationDidFinishLaunching(_ notification: Notification) {
    let args = CommandLine.arguments
    if let i = args.firstIndex(of: "--render-previews"), args.count > i + 1 {
      renderPreviews(to: args[i + 1])
      NSApp.terminate(nil)
      return
    }
    // Prevent duplicate polling and duplicate login-launched instances.
    if let id = Bundle.main.bundleIdentifier,
      NSRunningApplication.runningApplications(withBundleIdentifier: id).contains(where: {
        $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
      })
    {
      NSApp.terminate(nil)
      return
    }
    NSApp.setActivationPolicy(.accessory)
    model = AppModel(demo: args.contains("--demo"))
    UNUserNotificationCenter.current().delegate = self
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    if let button = statusItem.button {
      button.target = self
      button.action = #selector(togglePanel)
    }
    configurePanel()
    subscription = model.objectWillChange.sink { [weak self] _ in
      DispatchQueue.main.async {
        self?.updateStatus()
        self?.refreshPanelLayout()
      }
    }
    updateStatus()
    if args.contains("--show") || !UserDefaults.standard.bool(forKey: "launchedBefore") {
      UserDefaults.standard.set(true, forKey: "launchedBefore")
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.togglePanel() }
    }
  }
  private func updateStatus() {
    guard let button = statusItem.button else { return }
    let image: NSImage?
    switch model.menuBarStyle {
    case .mouseAndPercentage:
      image = NSImage(systemSymbolName: "computermouse", accessibilityDescription: "鼠标")
    case .batteryAndPercentage:
      image = batteryPercentageImage
    case .percentageOnly:
      image = nil
    }
    image?.isTemplate = model.menuBarStyle != .batteryAndPercentage
    button.image = image
    if model.menuBarStyle == .batteryAndPercentage {
      button.imagePosition = .imageOnly
      button.title = ""
    } else {
      button.imagePosition = image == nil ? .noImage : .imageLeading
      button.title = image == nil ? model.title : " " + model.title
    }
    button.toolTip = "雷蛇电量管家 · " + model.statusText
    button.setAccessibilityLabel("雷蛇鼠标，\(model.title)，\(model.statusText)")
  }
  private var batteryPercentageImage: NSImage {
    let percentage = model.state.reading?.battery
    let value = min(100, max(0, percentage ?? 0))
    let sleeping = model.state.status == .sleeping
    let image = NSImage(size: NSSize(width: 28, height: 15), flipped: false) { _ in
      let body = NSRect(x: 0.5, y: 1.5, width: 24.5, height: 12)
      let inner = body.insetBy(dx: 1.5, dy: 1.5)
      let bodyPath = NSBezierPath(roundedRect: body, xRadius: 2.6, yRadius: 2.6)

      NSColor.labelColor.withAlphaComponent(0.72).setStroke()
      bodyPath.lineWidth = 1
      bodyPath.stroke()
      NSColor.labelColor.withAlphaComponent(0.72).setFill()
      NSBezierPath(
        roundedRect: NSRect(x: 25.7, y: 5, width: 1.6, height: 5), xRadius: 0.8, yRadius: 0.8
      ).fill()

      let fillWidth = inner.width * CGFloat(value) / 100
      let fillRect = NSRect(x: inner.minX, y: inner.minY, width: fillWidth, height: inner.height)
      NSGraphicsContext.saveGraphicsState()
      NSBezierPath(roundedRect: inner, xRadius: 1.7, yRadius: 1.7).addClip()
      let fillColor: NSColor
      if sleeping {
        fillColor = NSColor(calibratedRed: 0.78, green: 0.55, blue: 0.18, alpha: 1)
      } else {
        switch value {
        case 0...20: fillColor = .systemRed
        case 21...50: fillColor = .systemOrange
        default: fillColor = .systemGreen
        }
      }
      fillColor.setFill()
      fillRect.fill()
      NSGraphicsContext.restoreGraphicsState()

      let text = percentage.map(String.init) ?? "—"
      let paragraph = NSMutableParagraphStyle()
      paragraph.alignment = .center
      let textRect = NSRect(x: body.minX, y: body.minY + 2.1, width: body.width, height: 8)
      var attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 6.5, weight: .semibold),
        .foregroundColor: NSColor.labelColor,
        .paragraphStyle: paragraph,
      ]
      text.draw(in: textRect, withAttributes: attributes)
      if fillWidth > 0 {
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: fillRect).addClip()
        attributes[.foregroundColor] = NSColor.white
        text.draw(in: textRect, withAttributes: attributes)
        NSGraphicsContext.restoreGraphicsState()
      }
      return true
    }
    image.isTemplate = false
    return image
  }
  func applicationDidBecomeActive(_ notification: Notification) {
    model?.permissionMayHaveChanged()
  }
  @objc private func togglePanel() {
    if panel.isVisible {
      hidePanel()
      return
    }
    guard let button = statusItem.button else { return }
    model.updateLoginStatus()
    model.refresh()
    refreshPanelLayout()
    positionPanel(relativeTo: button)
    panel.orderFrontRegardless()
    installDismissMonitors()
    NSApp.activate(ignoringOtherApps: true)
  }

  private func configurePanel() {
    panel = MenuBarPanel(
      contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.level = .popUpMenu
    panel.isFloatingPanel = true
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [.transient, .moveToActiveSpace, .fullScreenAuxiliary]
    let host = NSHostingController(
      rootView: BatteryPanel(model: model) { [weak self] height in
        self?.setPanelHeight(height)
      })
    host.view.wantsLayer = true
    host.view.layer?.cornerRadius = 12
    host.view.layer?.masksToBounds = true
    panel.contentViewController = host
    refreshPanelLayout()
  }
  private func refreshPanelLayout() {
    guard let view = panel?.contentViewController?.view else { return }
    view.layoutSubtreeIfNeeded()
    let height = ceil(view.fittingSize.height)
    if height > 0 { setPanelHeight(height) }
  }
  private func setPanelHeight(_ height: CGFloat) {
    let newHeight = ceil(height)
    guard newHeight > 0, abs(newHeight - panelHeight) > 0.5 else { return }
    panelHeight = newHeight
    panel.setContentSize(NSSize(width: panelWidth, height: panelHeight))
    if panel.isVisible, let button = statusItem.button { positionPanel(relativeTo: button) }
  }
  private func positionPanel(relativeTo button: NSStatusBarButton) {
    guard let window = button.window else { return }
    let buttonRect = window.convertToScreen(button.convert(button.bounds, to: nil))
    let visible =
      (window.screen ?? NSScreen.main)?.visibleFrame
      ?? NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
    let x = min(
      max(buttonRect.midX - panelWidth / 2, visible.minX + 8), visible.maxX - panelWidth - 8)
    let preferredY = buttonRect.minY - panelHeight - 6
    let y = max(visible.minY + 8, min(preferredY, visible.maxY - panelHeight - 8))
    panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
  }
  private func hidePanel() {
    panel.orderOut(nil)
    removeDismissMonitors()
  }
  private func installDismissMonitors() {
    removeDismissMonitors()
    globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [
      .leftMouseDown, .rightMouseDown,
    ]) { [weak self] _ in
      DispatchQueue.main.async { self?.hidePanel() }
    }
    localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [
      .leftMouseDown, .rightMouseDown, .keyDown,
    ]) { [weak self] event in
      guard let self else { return event }
      if event.type == .keyDown, event.keyCode == 53 {
        self.hidePanel()
        return nil
      }
      let statusWindow = self.statusItem.button?.window
      if event.window !== self.panel, event.window !== statusWindow { self.hidePanel() }
      return event
    }
  }
  private func removeDismissMonitors() {
    if let localEventMonitor {
      NSEvent.removeMonitor(localEventMonitor)
      self.localEventMonitor = nil
    }
    if let globalEventMonitor {
      NSEvent.removeMonitor(globalEventMonitor)
      self.globalEventMonitor = nil
    }
  }
  func applicationWillTerminate(_ notification: Notification) {
    removeDismissMonitors()
  }
  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }
  private func renderPreviews(to path: String) {
    do {
      try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
      let previews: [(String, NSAppearance.Name)] = [
        ("light", .aqua),
        ("dark", .darkAqua),
      ]
      for (name, appearance) in previews {
        let model = AppModel(demo: true)
        let host = NSHostingView(rootView: BatteryPanel(model: model))
        let window = NSWindow(
          contentRect: NSRect(x: 0, y: 0, width: 360, height: 540), styleMask: [.borderless],
          backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        window.contentView = host
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        window.setContentSize(host.fittingSize)
        window.display()
        host.layoutSubtreeIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { continue }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        if let png = bitmap.representation(using: .png, properties: [:]) {
          try png.write(
            to: URL(fileURLWithPath: path).appendingPathComponent("preview-\(name).png"))
        }
      }
    } catch { fputs("Preview error: \(error)\n", stderr) }
  }
}
@main struct Entry {
  @MainActor static func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
  }
}
