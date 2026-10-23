# 更新日志

本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 的结构，并使用语义化版本号。

## [Unreleased]

### Added

- GitHub CI、Issue 表单、PR 模板和开源协作文档。
- 可复用的 DMG 打包脚本及 Developer ID / 公证发布说明。

### Changed

- 重写中英文项目介绍并拆分安装、构建、架构、设备和隐私文档。

## [0.1.0] - 2026-09-18

### Added

- 原生 macOS 菜单栏应用与无箭头完整悬浮面板。
- Basilisk V3 Pro 普通接收器 `1532:00AB` 电量、充电状态、DPI 和回报率读取。
- DPI 与回报率设置及写入后读回验证。
- 三种菜单栏图标、低电量通知和登录启动。
- 物理断联与静置休眠状态区分，以及 HID 活动唤醒刷新。
- 命令行诊断工具和 23 项无硬件协议/状态检查。

### Security

- 严格验证 HID 报告长度、校验和、事务、命令和返回状态。
- 未知产品 ID 仅枚举，不发送控制命令。
