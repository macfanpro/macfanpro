# MacFanPro 0.2.3.32 验证记录

## 修改范围

- `UpdateScript.swift`（新文件）：按安装方式生成更新脚本，写入用户临时目录的 `MacFanPro Update.command`，用“终端”打开执行。
  - 发行包：下载该版本的发行包与 `SHA256SUMS`，校验后解压，`auto --stop-app`，`sudo … install`，重新打开应用。
  - Homebrew：`brew trust`、`brew update`（失败不中断）、`brew upgrade macfanpro`，再用 keg 中的 CLI 执行 `auto --stop-app` 与 `sudo … install`，重新打开应用。
  - 两者都在终端未设置代理时读取系统 HTTPS 代理（`scutil --proxy`），并在失败时提示手动更新的链接。
- `MenuBarView.swift`：更新提示增加“在终端中更新”按钮；命令仍然显示，可自行复制。新增文案 18 种语言齐全。
- Homebrew tap：新增 [Update formula](https://github.com/macfanpro/homebrew-tap/blob/main/.github/workflows/update-formula.yml) 工作流，跟随主仓库最新的正式版本，自动更新配方、构建并上传预编译包、验证直接安装与 `brew test` 后提交；草稿不触发。
- 风扇控制未改变。

## 本机候选版

环境：M4 Max MacBook Pro（Mac16,5），macOS 27.0，经系统代理访问 GitHub。

- Debug、Release 各 150 项测试通过（新增 3 项：两种脚本的内容、`zsh -n` 语法检查、代理设置），编译无警告，语言资源打包检查通过。
- 界面渲染：18 种语言的两种更新提示均显示按钮，截图核对中、德、阿拉伯、俄、法文。
- 脚本实跑（以 0.2.3.31 生成，并清除终端代理环境变量以模拟普通终端）：
  - 发行包脚本：自动使用系统代理 `127.0.0.1:7897`，下载并校验 0.2.3.31 发行包，退出应用、安装、重新打开，完成；
  - Homebrew 脚本：同样使用系统代理；本机 Homebrew 的第三方镜像使 `brew update` 部分失败，脚本继续执行，完成升级检查与同步。
- tap 工作流手动触发一次：配方已是 v0.2.3.31，正确判断为无需更新并跳过后续步骤。完整的构建与发布路径在本版发布后实跑。

## 公开发行

- 发行源提交：`36bfe11`，标签 `v0.2.3.32`。[源码 CI](https://github.com/macfanpro/macfanpro/actions/runs/36613535045)、[发行 CI](https://github.com/macfanpro/macfanpro/actions/runs/36613538929) 通过。
- 下载草稿附件，`SHA256SUMS` 校验通过，与 GitHub asset digest 一致：`MacFanPro-0.2.3.32-macos-arm64.tar.gz` 为 `1f1464c2b5f71d06af04f4eb492b0677b0552e6b959811886cff7b6288eeba2c`。CLI 版本为 0.2.3.32，严格代码签名校验通过；安装后二进制与发行包逐字节一致。
- **Homebrew 自动化首次完整运行**：发布后手动触发 tap 的 Update formula 工作流（[运行记录](https://github.com/macfanpro/homebrew-tap/actions/runs/36614158983)），全部步骤成功——配方指向 v0.2.3.32，在 GitHub 的 macOS 15 机器上构建预编译包并确认两个二进制最低系统为 macOS 14，上传到 tap Release `macfanpro-0.2.3.32`，验证直接安装（Pouring）与 `brew test`，最后由 github-actions 提交配方（`0acd22b`）。未做任何手动 Homebrew 操作。
- **用“在终端中更新”按钮完成本机升级**：临时写入“最新版本 99.99.99”使提示出现，按下按钮后“终端”打开生成的 `MacFanPro Update.command`；脚本将 Homebrew 从 0.2.3.31 升级到 0.2.3.32（使用上述 CI 生成的预编译包），用户输入一次密码后同步后台服务并重新打开应用，约 4 分钟完成。结束后三者版本均为 0.2.3.32，与 Homebrew 版逐字节一致，无版本不一致提示；测试用的偏好值已删除，Smart 模式与“跟随系统”语言保留。
