# 参与贡献

感谢你帮助改进 RazerBatteryMenu。这个项目直接与 HID 设备通信，因此协议正确性、保守的设备匹配和可复现证据比扩大设备列表更重要。

## 开始之前

- 错误和功能建议请先搜索现有 Issue。
- 安全漏洞不要公开提交，按 [SECURITY.md](SECURITY.md) 报告。
- 新设备支持请提供产品 ID、连接方式、macOS 版本、固件版本和已脱敏的“设备诊断”输出。
- 不要提交设备序列号、用户名、个人目录、崩溃报告中的设备标识或其他隐私信息。

## 本地开发

```bash
git clone https://github.com/YOUR_USERNAME/RazerBatteryMenu.git
cd RazerBatteryMenu
bash scripts/test.sh
bash scripts/build.sh
```

运行源码格式检查：

```bash
swift format lint --recursive Sources Tests
swift format lint Package.swift scripts/icon.swift
```

## 变更要求

- 协议编码、解析、重试或状态缓存变更需要对应测试。
- 新产品 ID 默认只能识别。只有取得明确协议证据并完成读写验证后，才能加入控制白名单。
- 写入功能必须读回验证；启动、重连和升级不能静默覆盖设备配置。
- 超时不能直接转换为 0% 电量，也不能在没有历史有效读数时宣称设备休眠。
- UI 变更需要同时检查浅色和深色外观。
- 不要加入网络请求、遥测或第三方二进制依赖，除非 Issue 中已经说明必要性和隐私影响。

## Pull Request

PR 描述应包含：

1. 具体问题和用户可见变化。
2. 受影响的设备、产品 ID 和连接方式。
3. 执行过的自动测试和实机验证。
4. 未验证的边界与风险。
5. UI 变更的截图。

请保持 PR 聚焦。协议支持、界面重构和无关格式化应分别提交，方便审查和回退。

## 提交信息

使用简短的祈使句描述结果，例如：

```text
Fix HID callback cleanup after open failure
Add wired 00AA battery validation
Document notarized release workflow
```

提交贡献即表示你有权提交这些内容，并同意其按照项目的 MIT License 发布。
