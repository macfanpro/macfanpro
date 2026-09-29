# MacFanPro 0.2.3.27 验证记录

## 修改范围

- 文案：按钮键由 `Check` 改为 `Check for Updates`（简体“检查更新”，繁体由脚本生成为“檢查更新”）；结果文案保持 0.2.3.26 的 `{version} available`、`Couldn't reach GitHub`。
- `MenuBarView.swift`：结果文字改为 `.fixedSize(horizontal: false, vertical: true)`，一行放不下时换行，这一行随之增高；按钮加 `.fixedSize()`，宽度始终完整。

## 本机候选版

环境：M4 Max MacBook Pro（Mac16,5），macOS 27.0。

- Debug、Release 各 147 项测试通过，编译无警告，语言资源打包检查通过。
- 界面渲染截图核对：英文 “Couldn't reach GitHub” 与 “99.99.99 available” 在 “Check for Updates” 旁换为两行，行高自动增加，文字完整、按钮居中完整；中文“有新版本 99.99.99”“无法连接 GitHub”与“检查更新”单行显示；字号与“语言”“版本”一致。曾试用缩短英文文案（“Can't connect”等），改为自动换行后未采用。

## 公开发行

- 首次为 `v0.2.3.27` 打的标签（`293165a`，按钮在英文下配短文案）在发布前被替换：其草稿未公开、Homebrew 未指向，删除草稿与标签后改为自动换行方案，重新打标签。
- 发行源提交：`fe87102`，标签 `v0.2.3.27`。[源码 CI](https://github.com/macfanpro/macfanpro/actions/runs/36525683667)、[发行 CI](https://github.com/macfanpro/macfanpro/actions/runs/36525687079) 通过。
- 下载草稿附件，`SHA256SUMS` 校验通过，与 GitHub asset digest 一致：`MacFanPro-0.2.3.27-macos-arm64.tar.gz` 为 `fdbc3fe7de35781b2df97a9de65927d65098511c482521833e8f0cc9008ee7a5`。CLI 版本为 0.2.3.27，严格代码签名校验通过，包内英文资源为完整文案。
- 安装下载产物后，二进制与发行包逐字节一致，实际按下“检查更新”显示“已是最新版本”。
- Homebrew 从 0.2.3.26 升级到 0.2.3.27，`brew test` 通过；同步后三者版本均为 0.2.3.27，无版本不一致提示，Smart 模式保留。

## README 截图

README 的英文与简体中文截图来自本机经 Homebrew 安装的 0.2.3.27 菜单面板，按窗口截取（520×1022 像素），两张都在按下“检查更新”后截取。英文截图临时将语言设为 English，截取后已恢复为“跟随系统”。
