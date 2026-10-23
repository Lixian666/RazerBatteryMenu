# 构建指南

## 环境

- macOS 13+；
- Xcode Command Line Tools；
- Swift 5.9 或更高版本；
- `iconutil`、`codesign` 和 `hdiutil`（macOS 自带）。

安装命令行工具：

```bash
xcode-select --install
swift --version
```

项目只依赖 Apple 系统框架，不会下载第三方 Swift 包。

## 测试

```bash
bash scripts/test.sh
```

测试使用模拟传输层，覆盖协议编码、校验和、长度、错误响应、重试、电量换算、DPI / 回报率读回验证、缓存、休眠和断连状态，不要求连接鼠标。

## 构建应用

```bash
bash scripts/build.sh
```

输出：

```text
dist/RazerBatteryMenu.app
dist/RazerDiagnostics
```

默认进行 ad-hoc 签名。指定 Developer ID：

```bash
CODESIGN_IDENTITY='Developer ID Application: Example (TEAMID)' bash scripts/build.sh
```

可以把缓存和产物放到其他目录：

```bash
RAZER_BUILD_DIR="$PWD/.cache/build" \
RAZER_OUTPUT_DIR="$PWD/artifacts" \
bash scripts/build.sh
```

## 创建 DMG

```bash
bash scripts/package-dmg.sh
```

默认读取 `dist/RazerBatteryMenu.app`，按当前架构生成 `dist/RazerBatteryMenu-<arch>.dmg`，并执行镜像校验和 SHA-256 输出。覆盖路径：

```bash
RAZER_APP_PATH="$PWD/dist/RazerBatteryMenu.app" \
RAZER_DMG_PATH="$PWD/artifacts/RazerBatteryMenu-arm64.dmg" \
bash scripts/package-dmg.sh
```

## 格式检查

```bash
swift format lint --recursive Sources Tests
swift format lint Package.swift scripts/icon.swift
```

## 界面预览

```bash
open dist/RazerBatteryMenu.app --args --demo --show

dist/RazerBatteryMenu.app/Contents/MacOS/RazerBatteryMenu \
  --render-previews /tmp/razer-previews
```

预览模式使用明确的模拟数据，不访问鼠标。
