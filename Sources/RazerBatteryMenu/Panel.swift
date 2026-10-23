import RazerCore
import SwiftUI

struct BatteryPanel: View {
  @ObservedObject var model: AppModel
  let onHeightChange: ((CGFloat) -> Void)?
  @State private var showingDiagnostics = false
  private let accent = Color(red: 0.18, green: 0.68, blue: 0.39)
  private let standby = Color(red: 0.78, green: 0.55, blue: 0.18)

  init(model: AppModel, onHeightChange: ((CGFloat) -> Void)? = nil) {
    self.model = model
    self.onHeightChange = onHeightChange
  }

  var body: some View {
    panelContent
      .frame(width: 360)
      .fixedSize(horizontal: false, vertical: true)
      .background(Color(nsColor: .windowBackgroundColor))
      .background {
        GeometryReader { geometry in
          Color.clear.preference(key: PanelHeightPreferenceKey.self, value: geometry.size.height)
        }
      }
      .onPreferenceChange(PanelHeightPreferenceKey.self) { onHeightChange?($0) }
  }

  private var panelContent: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 10) {
        Image(systemName: "computermouse.fill").font(.title2).foregroundStyle(accent)
        VStack(alignment: .leading, spacing: 2) {
          Text("雷蛇电量管家").font(.headline)
          Text("Razer Battery Tray · macOS").font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        if model.busy { ProgressView().controlSize(.small) }
        Button {
          model.refresh()
        } label: {
          Image(systemName: "arrow.clockwise")
        }
        .buttonStyle(.borderless).disabled(model.busy).help("立即刷新")
      }
      if model.demo { Text("界面预览 · 模拟数据").font(.caption).foregroundStyle(.orange) }
      VStack(alignment: .leading, spacing: 9) {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
          Text(model.state.reading.map { String($0.battery) } ?? "—")
            .font(.system(size: 44, weight: .light, design: .rounded)).monospacedDigit()
          Text("%").font(.title2).foregroundStyle(.secondary)
          Spacer()
          Label(model.statusText, systemImage: statusIcon).font(.callout)
            .foregroundStyle(statusColor)
        }
        GeometryReader { geometry in
          Capsule().fill(Color.primary.opacity(0.08))
          Capsule().fill(statusColor).frame(
            width: geometry.size.width * CGFloat(model.state.reading?.battery ?? 0) / 100)
        }.frame(height: 6).accessibilityLabel("电量 \(model.state.reading?.battery ?? 0)%")
        Text(model.state.device?.name ?? "连接你的巴塞利斯蛇 V3 Pro").font(.subheadline).fontWeight(.medium)
        HStack {
          Text(
            model.state.device.map { String(format: "1532:%04X", $0.productID) } ?? "USB 接收器 / 有线")
          Spacer()
          if let r = model.state.reading {
            Text(readingDatePrefix + r.date.formatted(date: .omitted, time: .shortened))
          }
        }.font(.caption).foregroundStyle(.secondary)
      }.padding(14).background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
      if model.devices.count > 1 {
        Picker("设备", selection: Binding(get: { model.state.device?.id ?? "" }, set: model.choose)) {
          ForEach(model.devices) {
            Text($0.name + String(format: " (%04X)", $0.productID)).tag($0.id)
          }
        }.disabled(model.busy)
      }
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("灵敏度").fontWeight(.medium)
          Spacer()
          Text(dpiText).foregroundStyle(.secondary)
        }.font(.subheadline)
        HStack(spacing: 6) {
          ForEach([400, 800, 1600, 3000, 6400], id: \.self) { dpi in
            Button {
              model.setDPI(dpi)
            } label: {
              Text(String(dpi)).font(.system(size: 12, weight: .medium)).frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                  model.state.reading?.dpi == DPI(x: dpi, y: dpi)
                    ? accent.opacity(0.22) : Color.primary.opacity(0.06),
                  in: RoundedRectangle(cornerRadius: 6))
            }.buttonStyle(.plain)
          }
        }.disabled(!canSetDPI)
        HStack {
          Text("回报率").font(.subheadline).fontWeight(.medium)
          Spacer()
          Picker(
            "回报率",
            selection: Binding(get: { model.state.reading?.pollingRate ?? 0 }, set: model.setRate)
          ) {
            if model.state.reading?.pollingRate == nil { Text("未知").tag(0) }
            ForEach([125, 500, 1000], id: \.self) { Text("\($0) Hz").tag($0) }
          }.labelsHidden().frame(width: 140).disabled(!canSetRate)
        }
        Text("普通接收器支持 125 / 500 / 1000 Hz").font(.caption).foregroundStyle(.secondary)
      }
      Divider()
      VStack(alignment: .leading, spacing: 9) {
        Text("菜单栏样式").font(.subheadline).fontWeight(.medium)
        HStack(spacing: 7) {
          ForEach(MenuBarStyle.allCases) { style in
            Button {
              model.setMenuBarStyle(style)
            } label: {
              VStack(spacing: 5) {
                Group {
                  if style == .batteryAndPercentage {
                    BatteryPercentageBadge(
                      percentage: model.state.reading?.battery,
                      sleeping: model.state.status == .sleeping)
                  } else {
                    HStack(spacing: 4) {
                      if let symbol = style.previewSymbol {
                        Image(systemName: symbol)
                      }
                      Text(menuBarPreviewText).monospacedDigit()
                    }
                    .font(.system(size: 12, weight: .medium))
                  }
                }
                .frame(height: 18)
                Text(style.title).font(.caption2).foregroundStyle(.secondary)
              }
              .frame(maxWidth: .infinity)
              .padding(.vertical, 6)
              .background(
                model.menuBarStyle == style ? accent.opacity(0.18) : Color.primary.opacity(0.05),
                in: RoundedRectangle(cornerRadius: 8)
              )
              .overlay {
                RoundedRectangle(cornerRadius: 8)
                  .stroke(model.menuBarStyle == style ? accent.opacity(0.8) : .clear, lineWidth: 1)
              }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("菜单栏样式：\(style.title)")
          }
        }
      }
      VStack(spacing: 8) {
        HStack {
          Text("低电量通知（≤20%）")
          Spacer()
          Toggle(
            "低电量通知", isOn: Binding(get: { model.notificationsEnabled }, set: model.setNotifications)
          ).labelsHidden()
        }
        HStack {
          Text("登录时启动")
          Spacer()
          Toggle("登录时启动", isOn: Binding(get: { model.loginEnabled }, set: model.setLogin))
            .labelsHidden()
        }
        if model.loginNeedsApproval { Button("在系统设置中允许登录启动", action: model.showLoginSettings) }
      }.toggleStyle(.switch).controlSize(.small).font(.subheadline)
      if let error = model.state.error ?? model.message {
        Text(error).font(.caption).foregroundStyle(.secondary).fixedSize(
          horizontal: false, vertical: true)
      }
      if model.needsHIDPermission {
        Button(model.hidPermissionActionTitle, action: model.requestHIDAccess).font(.caption)
      }
      HStack {
        Button("设备诊断") { showingDiagnostics.toggle() }
        Spacer()
        Text("v0.1 · Basilisk V3 Pro").foregroundStyle(.tertiary)
        Button("退出") { NSApp.terminate(nil) }
      }.buttonStyle(.borderless).font(.caption)
      if showingDiagnostics {
        ScrollView {
          Text(model.diagnostics).font(.system(size: 10, design: .monospaced)).textSelection(
            .enabled
          ).frame(maxWidth: .infinity, alignment: .leading)
        }.frame(height: 110)
        Button("复制诊断信息") {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(model.diagnostics, forType: .string)
        }.font(.caption)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
  private var statusIcon: String {
    if model.state.status == .sleeping { return "moon.zzz.fill" }
    if model.state.status != .ready { return "exclamationmark.circle" }
    return model.state.reading?.charging == true ? "bolt.fill" : "battery.100percent"
  }
  private var statusColor: Color {
    switch model.state.status {
    case .ready: return accent
    case .sleeping: return standby
    default: return .orange
    }
  }
  private var readingDatePrefix: String {
    switch model.state.status {
    case .sleeping: return "休眠前 "
    case .unreadable: return "上次读数 "
    default: return "更新于 "
    }
  }
  private var dpiText: String {
    guard let d = model.state.reading?.dpi, model.state.status == .ready else { return "— DPI" }
    return d.x == d.y ? "\(d.x) DPI" : "X \(d.x) / Y \(d.y)"
  }
  private var menuBarPreviewText: String {
    model.state.reading.map { "\($0.battery)%" } ?? "—"
  }
  private var canSetDPI: Bool {
    model.state.status == .ready && model.state.reading?.dpi != nil && !model.busy
  }
  private var canSetRate: Bool {
    model.state.status == .ready && model.state.reading?.pollingRate != nil && !model.busy
  }
}

private struct PanelHeightPreferenceKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

private struct BatteryPercentageBadge: View {
  let percentage: Int?
  let sleeping: Bool

  private var value: Int { min(100, max(0, percentage ?? 0)) }
  private var fillColor: Color {
    if sleeping { return Color(red: 0.78, green: 0.55, blue: 0.18) }
    switch value {
    case 0...20: return .red
    case 21...50: return .orange
    default: return .green
    }
  }

  var body: some View {
    HStack(spacing: 1) {
      ZStack {
        RoundedRectangle(cornerRadius: 2.6)
          .stroke(.primary.opacity(0.72), lineWidth: 1)
        GeometryReader { geometry in
          RoundedRectangle(cornerRadius: 1.7)
            .fill(fillColor)
            .frame(width: max(0, (geometry.size.width - 3) * CGFloat(value) / 100))
            .padding(1.5)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        Text(percentage.map(String.init) ?? "—")
          .font(.system(size: 6.5, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(value > 50 ? .white : .primary)
      }
      .frame(width: 27, height: 13)
      Capsule().fill(.primary.opacity(0.72)).frame(width: 1.4, height: 5.5)
    }
    .accessibilityLabel("电池图标，\(percentage.map { "\($0)%" } ?? "电量未知")")
  }
}
