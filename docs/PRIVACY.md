# 隐私说明

RazerBatteryMenu 在本机直接与鼠标 HID 接口通信。

## 应用访问的内容

- Razer USB 设备的产品名称、供应商 ID、产品 ID、location ID、usage 和报告长度；
- 鼠标返回的电量、充电状态、DPI 和回报率；
- 用户在应用中选择的设置；
- HID 输入报告到达事件，仅用于判断休眠鼠标已经活动。

## 应用不会执行的行为

- 不保存输入报告内容、鼠标轨迹、按键或键盘输入；
- 不读取 HID 序列号用于日志或设备身份；
- 不发送网络请求；
- 不包含遥测、广告、崩溃上传或用户账号；
- 不运行服务器、内核扩展或特权帮助程序。

## 本地存储

应用使用 UserDefaults 域 `app.razerbatterymenu.macos` 保存偏好和每个设备最后一次有效读数。低电量通知由 macOS UserNotifications 发送。登录启动由 ServiceManagement 管理。

清除本地数据：

```bash
defaults delete app.razerbatterymenu.macos
```

## 输入监控权限

macOS 将 HID 监听权限统一显示为“输入监控”。本应用注册输入报告回调只为在鼠标从休眠恢复时立即刷新设备状态；回调不解析或持久化鼠标移动数据。协议查询本身通过 Feature Report 完成。
