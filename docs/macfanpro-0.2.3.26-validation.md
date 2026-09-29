# MacFanPro 0.2.3.26 验证记录

## 修改范围

- `MenuBarView.swift`：更新检查一行改为与“语言”一行相同的结构和字号。左侧为正文字号的标签，空闲时显示“更新”，检查后显示结果；右侧为常规尺寸的“检查”按钮。英文较长的按钮文字与结果并排超过 260 pt，因此按钮文字缩短为 “Check”。
- 文案：新增 “Updates” / “Check”，移除 “Check for Updates”（繁体由脚本生成）。
- 更新检查逻辑、风扇控制未改变。

## 本机候选版

环境：M4 Max MacBook Pro（Mac16,5），macOS 27.0。

- Debug、Release 各 147 项测试通过，编译无警告，语言资源打包检查通过。
- 界面渲染测试在三种语言下覆盖空闲、检查中、有新版本、无法连接四种状态；截图核对：英文最长的 “Couldn't reach GitHub” 与 “Check” 按钮同行完整显示，字号与“语言”“版本”一致。

## 公开发行

- 发行源提交：`4d98c67`，标签 `v0.2.3.26`。[源码 CI](https://github.com/macfanpro/macfanpro/actions/runs/36524309959)、[发行 CI](https://github.com/macfanpro/macfanpro/actions/runs/36524312580) 通过。
- 下载草稿附件，`SHA256SUMS` 校验通过，与 GitHub asset digest 一致：`MacFanPro-0.2.3.26-macos-arm64.tar.gz` 为 `adfe45b251c831202e37ee4cd1f86dc9b3314b01d01eaf450fe8626dd8afbc26`。CLI 版本为 0.2.3.26，严格代码签名校验通过。
- 安装下载产物后，二进制与发行包逐字节一致，实际按下“检查”显示“已是最新版本”。
- Homebrew 从 0.2.3.25 升级到 0.2.3.26，`brew test` 通过；同步后三者版本均为 0.2.3.26，无版本不一致提示。
- 发布后用户要求中文按钮使用“检查更新”，已在 0.2.3.27 调整，README 截图随 0.2.3.27 更新。
