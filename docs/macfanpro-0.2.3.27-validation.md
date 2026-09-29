# MacFanPro 0.2.3.27 验证记录

## 修改范围

- 文案：按钮键由 `Check` 改为 `Check for Updates`（简体“检查更新”，繁体由脚本生成为“檢查更新”）；结果文案保持 0.2.3.26 的 `{version} available`、`Couldn't reach GitHub`。
- `MenuBarView.swift`：结果文字改为 `.fixedSize(horizontal: false, vertical: true)`，一行放不下时换行，这一行随之增高；按钮加 `.fixedSize()`，宽度始终完整。

## 本机候选版

环境：M4 Max MacBook Pro（Mac16,5），macOS 27.0。

- Debug、Release 各 147 项测试通过，编译无警告，语言资源打包检查通过。
- 界面渲染截图核对：英文 “Couldn't reach GitHub” 与 “99.99.99 available” 在 “Check for Updates” 旁换为两行，行高自动增加，文字完整、按钮居中完整；中文“有新版本 99.99.99”“无法连接 GitHub”与“检查更新”单行显示；字号与“语言”“版本”一致。曾试用缩短英文文案（“Can't connect”等），改为自动换行后未采用。

## 公开发行

待发行包验收后填写。
