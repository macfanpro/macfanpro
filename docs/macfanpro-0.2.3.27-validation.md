# MacFanPro 0.2.3.27 验证记录

## 修改范围

- 文案：按钮键由 `Check` 改为 `Check for Updates`（简体“检查更新”，繁体由脚本生成为“檢查更新”）。英文结果键改短以便与按钮同行：`{version} available` → `New: {version}`，`Couldn't reach GitHub` → `Can't connect`，中文译文不变。项目约定英文值与键相同，因此同时修改 `MenuBarView.swift` 中的键。
- `MenuBarView.swift`：按钮加 `.fixedSize()`，空间不足时只截断左侧结果文字。

## 本机候选版

环境：M4 Max MacBook Pro（Mac16,5），macOS 27.0。

- Debug、Release 各 147 项测试通过，编译无警告，语言资源打包检查通过。
- 界面渲染截图核对：英文 “New: 99.99.99” / “Can't connect” 与 “Check for Updates” 同行完整显示（试用的 “Can't reach GitHub” 会被截断，未采用）；简体中文最长的“有新版本 99.99.99”“无法连接 GitHub”与“检查更新”同行完整显示；字号与“语言”“版本”一致。

## 公开发行

待发行包验收后填写。
