# MacFanPro 0.2.3.36 验证记录

## 修改范围

- `Scripts/generate-icon.swift`：
  - 底板改为深海军蓝渐变；64 px 及以上加细青色边框，16–32 px 不画边框；
  - `fan.fill` 用青→蓝→紫渐变填充，加青色光晕；
  - 用它重新生成 `MacFanPro.icns` 与 `docs/images/icon.png`。
- `docs/images/social-preview.png`（英文）与 `social-preview-zh-CN.png`（中文）使用同一套科技配色、新图标和布局。
- 按维护者要求，菜单栏状态颜色与面板强调色不变；风扇控制未改变。

## 本机候选版

环境：M4 Max MacBook Pro（Mac16,5），macOS 27.0。

- 核对图标在 512、256、64、32、16 px 下的渲染：小尺寸无边框，风扇轮廓清晰。
- 发行包、Homebrew 和 `setup.sh` 都使用仓库中的 `MacFanPro.icns`，无需修改构建脚本。

## 公开发行

- 发行源提交：`a6e5996`，标签 `v0.2.3.36`。[源码 CI](https://github.com/macfanpro/macfanpro/actions/runs/36691755550)、[发行 CI](https://github.com/macfanpro/macfanpro/actions/runs/36691755514) 通过。
- 草稿附件 4 个，两个校验文件通过，与 GitHub asset digest 一致：
  - 发行包 `c0c2a8b0b181b3d6a1372f3f5178a4e6cb59bbe839b3d710e13034cc4594120c`
  - `install.sh` `0b34cb1e5cfd21fdeef813e5e2c2081c66b83f8d110d0e778c074c2c5e74a289`
- CLI 为 0.2.3.36，严格签名通过，最低系统 macOS 14；App 内 `AppIcon.icns` 与仓库新图标一致。
- 公开发行后，release 事件自动启动 tap 更新（[运行记录](https://github.com/macfanpro/homebrew-tap/actions/runs/36692315545)），配方与预编译包提交为 `719b563`。
- 从 0.2.3.35 点“在终端中更新”升级：点击后约 24 秒完成（含输入密码）。
  - Homebrew 为 0.2.3.36；后台服务、`/Applications` 应用与 keg 逐字节一致；严格签名通过；无版本不一致；已安装应用的图标为新图标；Smart 模式与“跟随系统”语言保留。
- 截图更新：
  - 从这个版本的真实界面截取中、英文菜单截图（`docs/images/menu-bar-en.png`、`menu-bar-zh-CN.png`），英文截图时临时把界面语言设为 English，截完恢复“跟随系统”。
  - 用新截图重新生成两张社交预览图，并放到中、英文 README 顶部。生成脚本为 `Scripts/generate-social-preview.swift`，输出可复现。
