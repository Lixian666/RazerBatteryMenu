<p align="center">
  <img src="screenshots/app-icon.png" width="96" alt="RazerBatteryMenu macOS app icon">
</p>

<h1 align="center">RazerBatteryMenu</h1>

<p align="center">
  为 Razer Basilisk V3 Pro 打造的原生 macOS 菜单栏电量与设置工具。
</p>

<p align="center">
  <img alt="macOS 13+" src="https://img.shields.io/badge/macOS-13%2B-000000?logo=apple">
  <img alt="Swift 5.9+" src="https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white">
  <img alt="Apple Silicon" src="https://img.shields.io/badge/release-Apple%20Silicon-555555">
  <img alt="MIT License" src="https://img.shields.io/badge/license-MIT-green">
</p>

<p align="center">
  简体中文 · <a href="README_EN.md">English</a>
</p>

> [!IMPORTANT]
> 这是社区维护的非官方项目，与 Razer Inc. 没有关联。当前版本主要适配普通版 Basilisk V3 Pro 的 2.4G 接收器 `1532:00AB`；其他型号不会自动套用协议。

![RazerBatteryMenu 浅色界面](screenshots/preview-light.png)

## 功能

- 在菜单栏显示电量，提供鼠标＋百分比、电池数字、纯百分比三种样式。
- 显示充电状态、最后更新时间、DPI 和 USB 回报率。
- 提供 400 / 800 / 1600 / 3000 / 6400 DPI 预设。
- 支持普通接收器的 125 / 500 / 1000Hz 回报率。
- 写入后读取设备状态进行验证；启动和重连不会覆盖鼠标设置。
- 区分接收器物理断联和鼠标静置休眠；休眠时保留最后电量并显示琥珀金待机状态。
- 监听 HID 活动，在鼠标唤醒后立即发起刷新，不等待 60 秒定时查询。
- 支持低电量通知、登录启动、插拔重连和 Mac 睡眠唤醒。
- 完全本地运行，没有账号、服务器、遥测或网络请求。

## 设备支持

| 设备与连接 | 产品 ID | 状态 |
|---|---:|---|
| Basilisk V3 Pro 普通接收器 | `1532:00AB` | 电量、充电状态、DPI 与回报率已实机读写验证 |
| Basilisk V3 Pro 有线连接 | `1532:00AA` | 已实现协议，等待更多实机验证 |
| Basilisk V3 Pro 35K / HyperPolling / 其他 Razer 设备 | 其他 | 仅识别，不发送控制命令 |
| 蓝牙连接 | — | 暂不支持 |

具体范围和新增设备所需信息见 [设备支持文档](docs/DEVICE_SUPPORT.md)。

## 安装

1. 从 [GitHub Releases](../../releases/latest) 下载 Apple Silicon DMG。
2. 打开 DMG，将 `RazerBatteryMenu.app` 拖入“应用程序”。
3. 首次启动时，在“系统设置 → 隐私与安全性 → 输入监控”中允许 RazerBatteryMenu。
4. 返回应用后会自动重新连接；若 macOS 明确要求退出，请按系统提示重新打开。

公开测试版使用本地 ad-hoc 签名时，Gatekeeper 可能要求在“隐私与安全性”中选择“仍要打开”。不要关闭 Gatekeeper 或系统完整性保护。完整安装与故障排查步骤见 [安装指南](docs/INSTALLATION.md)。

## 从源码构建

要求：macOS 13+、Xcode Command Line Tools、Swift 5.9+。项目没有第三方包依赖。

```bash
git clone https://github.com/Lixian666/RazerBatteryMenu.git
cd RazerBatteryMenu
bash scripts/test.sh
bash scripts/build.sh
open dist/RazerBatteryMenu.app
```

构建脚本默认生成当前 Mac 架构的应用并进行 ad-hoc 签名。详细的开发、签名、DMG 和公证流程见：

- [构建指南](docs/BUILDING.md)
- [发布与部署](docs/RELEASING.md)
- [架构说明](docs/ARCHITECTURE.md)
- [隐私说明](docs/PRIVACY.md)

## 诊断工具

构建产物包含只读诊断程序：

```bash
# 枚举设备并读取状态，不修改鼠标配置
./dist/RazerDiagnostics

# 显式测试 DPI 与回报率写入、读回并恢复原值
./dist/RazerDiagnostics --verify-settings
```

执行 `--verify-settings` 前请退出菜单栏应用，避免两个进程同时查询控制接口。无参数诊断和应用正常启动不会修改鼠标配置。

## 安全设计

- 以非独占方式打开 HID 接口，不替代系统鼠标驱动。
- 串行处理协议请求，验证报告长度、校验和、事务、命令和设备状态。
- 超时不会显示假 0%；首次通信失败不会被误判为休眠。
- 诊断输出不包含 HID 序列号。
- “输入监控”权限用于访问 HID 控制接口；应用不会存储键盘或鼠标事件。

安全问题请按 [SECURITY.md](SECURITY.md) 私下报告。

## 项目结构

```text
Sources/
├── RazerCore/          # 协议、状态模型和校验
├── RazerHID/           # IOKit 发现、传输和串行工作器
├── RazerBatteryMenu/   # AppKit 菜单栏与 SwiftUI 面板
└── RazerDiagnostics/   # 命令行诊断工具
Tests/RazerCoreTests/   # 无硬件协议与状态测试
scripts/                # 构建、测试、图标和 DMG 脚本
docs/                   # 安装、架构、设备和发布文档
```

## 参与贡献

欢迎提交错误修复、协议证据、文档和设备验证结果。开始前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。协议变更应附带可复现的报告结构或测试夹具，提交日志前请移除序列号和个人路径。

## 项目状态

当前版本为 `0.1.0`。协议核心拥有 23 项无硬件自动检查，普通 `00AB` 接收器已完成电量、DPI 和回报率实机读写验证。仍需更多固件、macOS 版本以及有线 `00AA` 设备的社区验证，详见 [VALIDATION.md](VALIDATION.md) 和 [CHANGELOG.md](CHANGELOG.md)。

## 致谢与许可

本项目是 [Ferris-echo/RazerBatteryTray](https://github.com/Ferris-echo/RazerBatteryTray) 的独立 macOS 实现，并参考 OpenRazer 中可公开核查的互操作协议事实。没有复制或链接 OpenRazer 的 GPL 驱动代码。完整来源与许可说明见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

项目按 [MIT License](LICENSE) 发布。
