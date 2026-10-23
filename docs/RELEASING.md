# 发布与部署

本文件面向维护者。普通贡献者只需运行测试和本地构建。

## 1. 准备版本

1. 更新 `Resources/Info.plist` 的 `CFBundleShortVersionString` 和 `CFBundleVersion`；
2. 更新 `CHANGELOG.md`，将 Unreleased 内容归入新版本；
3. 检查 `README.md` 的设备支持和已知限制；
4. 运行全部自动检查并完成目标设备验收。

```bash
bash scripts/test.sh
bash scripts/build.sh
codesign --verify --strict --verbose=2 dist/RazerBatteryMenu.app
```

## 2. 本地测试包

没有 Developer ID 时：

```bash
bash scripts/build.sh
RAZER_DMG_PATH="$PWD/dist/RazerBatteryMenu-arm64.dmg" \
  bash scripts/package-dmg.sh
```

这是 ad-hoc 签名、未公证的测试包。Release 说明必须明确 Gatekeeper 限制，不能描述为 Apple 已验证。

## 3. Developer ID 签名

```bash
export CODESIGN_IDENTITY='Developer ID Application: Example (TEAMID)'
bash scripts/build.sh
codesign --display --verbose=4 dist/RazerBatteryMenu.app
codesign --verify --deep --strict --verbose=2 dist/RazerBatteryMenu.app
```

不要把证书、私钥、Apple ID 密码或 App Store Connect API 私钥提交到仓库。

## 4. 创建并公证 DMG

先在本机钥匙串保存 `notarytool` 配置：

```bash
xcrun notarytool store-credentials RazerBatteryMenu-notary
```

创建、提交和装订：

```bash
RAZER_DMG_PATH="$PWD/dist/RazerBatteryMenu-arm64.dmg" \
  bash scripts/package-dmg.sh

xcrun notarytool submit dist/RazerBatteryMenu-arm64.dmg \
  --keychain-profile RazerBatteryMenu-notary \
  --wait

xcrun stapler staple dist/RazerBatteryMenu-arm64.dmg
xcrun stapler validate dist/RazerBatteryMenu-arm64.dmg
spctl --assess --type open --context context:primary-signature \
  --verbose=4 dist/RazerBatteryMenu-arm64.dmg
```

## 5. GitHub Release

1. 创建带注释标签，例如 `v0.1.0`；
2. 用 `CHANGELOG.md` 对应章节撰写 Release Notes；
3. 上传 DMG 和 SHA-256 文件；
4. 标注支持的架构、macOS 版本、设备与待验证范围；
5. 从一台没有开发缓存的 Mac 下载 Release 资产，完成安装、授权和启动复核。

发布后不要移动标签或替换同名二进制。需要修复时发布新的补丁版本。
