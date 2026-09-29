# MacFanPro 0.2.3.30 验证记录

## 修改范围

- 新增第 18 种界面语言阿拉伯语（`ar`）：翻译文件 `ar.json`，`AppLanguage.arabic`（本名“العربية”），系统语言 `ar-*` 自动匹配。
- 从右往左排版：`AppLanguage.isRightToLeft`；`MenuBarView` 按当前语言设置 `layoutDirection`，由 SwiftUI 镜像整个面板。界面语言取自应用内设置而非系统区域，因此需要显式设置方向。
- 文档与仓库介绍中的语言数量更新为 18。
- 风扇控制、温控曲线与保护阈值未改变。

## 本机候选版

环境：M4 Max MacBook Pro（Mac16,5），macOS 27.0。

- Debug、Release 各 147 项测试通过，编译无警告；语言资源打包检查覆盖 18 个语言文件与 `CFBundleLocalizations`。
- 系统语言匹配测试新增 `ar-SA`、`ar-EG`。
- 排版：阿拉伯语 4 种面板状态截图与英文对照检查——标签在右、数值与按钮在左，单选圈与勾选框在右，“智能”“恢复”按钮左右互换，横幅从右往左排版；命令、RPM、温度保持从左往右；无截断。其他 17 种语言的翻译文件未改动。

## 公开发行

- 发行源提交：`9bf502e`，标签 `v0.2.3.30`。[源码 CI](https://github.com/macfanpro/macfanpro/actions/runs/36573751883)、[发行 CI](https://github.com/macfanpro/macfanpro/actions/runs/36573761804) 通过。
- 下载草稿附件，`SHA256SUMS` 校验通过，与 GitHub asset digest 一致：`MacFanPro-0.2.3.30-macos-arm64.tar.gz` 为 `ca936b463c6ec7db03d7b018916a0a3b8eac56bd34487c7947815a8019faf080`。CLI 版本为 0.2.3.30，严格代码签名校验通过；`CFBundleLocalizations` 18 项。
- 安装下载产物后，二进制与发行包逐字节一致。将已安装的应用切换为阿拉伯语：面板正确镜像，检查更新显示“محدَّث”（已是最新）；之后恢复为“跟随系统”。
- Homebrew：配方指向 v0.2.3.30 后按新流程生成并上传 `arm64_sonoma` 预编译包（tap Release `macfanpro-0.2.3.30`）；重新安装输出 “Pouring”，`brew test` 通过。同步后三者版本均为 0.2.3.30，与 Homebrew 版逐字节一致，无版本不一致提示，Smart 模式与“跟随系统”语言保留。
