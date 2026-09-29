# MacFanPro 0.2.3.28 验证记录

## 修改范围

- `AppState.swift`：新增 `clearManualUpdateResult()`，非检查中时把结果恢复为空闲。
- `MenuBarView.swift`：收到 `NSWindow.didResignKeyNotification`（菜单面板关闭或失去焦点）时调用它。先试用的 `onDisappear` 在本机实测不触发（菜单面板在两次打开之间保持存在），未采用。
- 更新检查方式、风扇控制未改变。

## 本机候选版

环境：M4 Max MacBook Pro（Mac16,5），macOS 27.0，用 `./setup.sh` 安装候选代码，以辅助功能接口操作真实菜单。

- Debug、Release 各 147 项测试通过，编译无警告。
- 按下“检查更新”后显示“已是最新版本”，菜单保持打开 3 秒后仍显示结果。
- 点菜单栏图标关闭再打开：这一行恢复为“更新”。
- 再次检查后切换到其他应用（菜单失去焦点）再打开：同样已恢复为“更新”。
- `onDisappear` 版本在同一操作下仍显示“已是最新版本”，确认了改用窗口通知的必要。

## 公开发行

待发行包验收后填写。
