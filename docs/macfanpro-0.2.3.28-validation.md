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

- 发行源提交：`70d477f`，标签 `v0.2.3.28`。[源码 CI](https://github.com/macfanpro/macfanpro/actions/runs/36526608971)、[发行 CI](https://github.com/macfanpro/macfanpro/actions/runs/36526611024) 通过。
- 下载草稿附件，`SHA256SUMS` 校验通过，与 GitHub asset digest 一致：`MacFanPro-0.2.3.28-macos-arm64.tar.gz` 为 `ccdd90414366d978e03250316b7931ec3084506c181202a915db209b19de0d33`。CLI 版本为 0.2.3.28，严格代码签名校验通过。
- 安装下载产物后，二进制与发行包逐字节一致；检查后显示“已是最新版本”，关闭再打开菜单恢复为“更新”。
- Homebrew 从 0.2.3.27 升级到 0.2.3.28，`brew test` 通过；同步后三者版本均为 0.2.3.28，无版本不一致提示，Smart 模式与“跟随系统”语言保留。
- 菜单外观与 0.2.3.27 相同，README 截图沿用 0.2.3.27。
