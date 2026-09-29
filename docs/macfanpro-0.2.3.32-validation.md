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

待发行包验收后填写。
