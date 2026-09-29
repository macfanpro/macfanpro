# MacFanPro 0.2.3.25 验证记录

## 修改范围

- `AppState.swift`：新增 `checkForUpdatesNow()` 与 `manualUpdateCheck` 状态；复用原有的每日检查结果处理，手动检查发现的版本即使被“稍后”隐藏过也会显示。
- `MenuBarView.swift`：“版本”下方新增一行，左侧显示检查结果，右侧为“检查更新”按钮。菜单宽度 260 pt 放不下英文按钮和版本号同一行，因此单独成行。
- `UpdateChecker.swift`：改为对 `github.com/macfanpro/macfanpro/releases/latest` 发送 HEAD 请求并跟随跳转，从最终地址解析版本标签，不再调用 GitHub REST API。
- 三种语言新增 5 条文案（繁体由 `Scripts/update-traditional.swift` 生成）。
- 风扇控制未改变。开发计划的状态见 [检查更新计划](update-check-plan.md)。

## 本机候选版

环境：M4 Max MacBook Pro（Mac16,5），macOS 27.0，经系统代理（127.0.0.1:7897）访问 GitHub。

- Debug、Release 各 147 项测试通过，编译无警告，语言资源打包检查通过。新增发布页跳转解析测试；界面渲染测试覆盖按钮行的四种状态与三种语言，截图检查无挤压、无截断。
- 初版使用 GitHub API，在本机实际按下“检查更新”后显示“无法连接 GitHub”。排查：代理可用，API 返回 403、`x-ratelimit-remaining: 0`，是共用出口 IP 的每小时 60 次额度已耗尽。改为发布页跳转后，连续请求均返回 200，最终地址为 `.../releases/tag/v0.2.3.24`。
- 修改后重新安装候选版并以辅助功能接口按下真实按钮：先显示“正在检查…”，随后显示“已是最新版本”（本机 0.2.3.25，线上最新 0.2.3.24）。

## 公开发行

- 发行源提交：`bb95fd3`，标签 `v0.2.3.25`。[源码 CI](https://github.com/macfanpro/macfanpro/actions/runs/36523487944)、[发行 CI](https://github.com/macfanpro/macfanpro/actions/runs/36523490385) 通过。
- 下载草稿附件，`SHA256SUMS` 校验通过，与 GitHub asset digest 一致：`MacFanPro-0.2.3.25-macos-arm64.tar.gz` 为 `1882e2e6312cce40e93a9df6289b23a5eb72a49669ebe865c802f96614755500`。CLI 版本为 0.2.3.25，严格代码签名校验通过。
- 以先退出应用、同步后台、再打开的步骤安装下载产物；已安装的后台服务 CLI 与应用二进制与发行包逐字节一致；按下“检查更新”显示“已是最新版本”。
- Homebrew 从 0.2.3.24 升级到 0.2.3.25，`brew test` 通过；同步后后台服务 CLI、应用与 Homebrew 版逐字节一致，三者版本均为 0.2.3.25，无版本不一致提示，Smart 模式保留。公开发布后再次检查，线上最新为 0.2.3.25，结果为“已是最新版本”。
