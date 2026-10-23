# 来源与许可

## RazerBatteryTray

本项目是 RazerBatteryTray 的独立 macOS 实现，原项目作者 Zhaopf，MIT License。
保留其 MIT 许可全文于 LICENSE；macOS 新增实现也按 MIT 发布。

参考版本：Ferris-echo/RazerBatteryTray commit `47fd9b165b2932ccad167a0cc04d9fe2f647bb82`。
来源：https://github.com/Ferris-echo/RazerBatteryTray

Windows UI、Win32 API、注册表和可执行文件未包含在本项目中。

## OpenRazer

协议核对参考：openrazer/openrazer commit `6820f9da169d354bc7e6e93a0aa8683a6bb75792`。
OpenRazer 驱动及相应 Python 设备定义使用 GPL-2.0-or-later。
本项目没有包含、链接或翻译其驱动源码；使用其公开可核查的设备 ID、命令字段、DPI 范围与回报率映射等互操作协议事实，自行编写 Swift 实现。

核对文件：
- https://github.com/openrazer/openrazer/blob/6820f9da169d354bc7e6e93a0aa8683a6bb75792/driver/razerchromacommon.c
- https://github.com/openrazer/openrazer/blob/6820f9da169d354bc7e6e93a0aa8683a6bb75792/driver/razermouse_driver.c
- https://github.com/openrazer/openrazer/blob/6820f9da169d354bc7e6e93a0aa8683a6bb75792/daemon/openrazer_daemon/hardware/mouse.py

## web_driver_mouse

仅比较过该项目的架构与说明；未复制其代码或资源，也不依赖其网站或服务。
检查时仓库根目录没有明确的 LICENSE 文件，因此不将其代码纳入本项目。
来源：https://github.com/uk0/web_driver_mouse

## Apple 平台

使用 macOS 随系统提供的 AppKit、SwiftUI、IOKit、ServiceManagement、UserNotifications 与 SF Symbols。
无第三方包依赖，无网络请求、遥测、键鼠事件记录、系统内核扩展。
应用图标由 scripts/icon.swift 绘制，不使用雷蛇官方商标图形。
