# MacFanPro 0.2.3.33 验证记录

## 修改范围

- `Scripts/install.sh`（新文件）：在线安装脚本，也是“在终端中更新”执行的脚本，只有这一份实现。
  - 构建时写入当前版本号，放进 App，并进入签名范围。
  - 打包时从 App 中原样复制，作为 `install.sh` 附件，另附 `install.sh.sha256`。
  - `SHA256SUMS` 仍只列发行包，兼容 0.2.3.32 的更新脚本。
  - 行为与参数见[在线安装器](online-installer.md)。
- `UpdateScript.swift`：“在终端中更新”把 App 内的 `install.sh` 复制到私有临时目录，用“终端”执行，结束后清理临时目录。版本号先做格式校验，不能借此注入命令。
- `macfanpro install`：守护进程启动后，请求它的版本号，与刚安装的版本不一致即报错。
- 更新提示：“从源码构建？”下方单独显示 `git pull && ./setup.sh`，可选中复制；18 种语言的文案随之调整。
- 代码检查中修复（`f4ab4ff`）：安装脚本的 Homebrew 路径漏了 `brew trust macfanpro/tap`，Homebrew 7 会因 tap 未受信任拒绝升级，已补上；`brew update` 失败改为提示后继续，与 0.2.3.32 一致。之后的版本检查仍会拒绝比请求版本旧的配方。
- 风扇控制未改变。

## 本机候选版

环境：M4 Max MacBook Pro（Mac16,5），macOS 27.0，经系统代理访问 GitHub。

- Swift 测试 149 项、安装器集成测试 16 项（新增：Homebrew 路径先 `trust` 再升级；`trust` 或 `update` 失败时仍完成升级）、断连客户端脚本、语言资源与安装脚本打包检查均通过；`shellcheck` 通过。
- 联网只读检查：`bash Scripts/install.sh --version 0.2.3.32 --check` 下载公开的 0.2.3.32 发行包，校验和、压缩包路径与文件类型、App 身份与版本、严格签名、CLI 版本全部通过；不安装，不改变风扇控制。
- 更早的实现验证见[在线安装器实现验证](online-installer-validation.md)。
- 按维护者要求，本版不更新本机应用；本机仍为 0.2.3.32。

## 公开发行

- 发行源提交：`bb27555`，标签 `v0.2.3.33`。[源码 CI](https://github.com/macfanpro/macfanpro/actions/runs/36661900614)、[发行 CI](https://github.com/macfanpro/macfanpro/actions/runs/36661900699) 通过。
- 草稿附件共 4 个，两个校验文件均通过，与 GitHub asset digest 一致：
  - `MacFanPro-0.2.3.33-macos-arm64.tar.gz`：`2d3b77f35980c7ade3fc40029c901577cd5210ae90e1e2942a747285c8098bdd`
  - `install.sh`：`7a85f1f01cd8a89fc2599542ccbdc8a17a995d431256ba4df1825c375d836df2`
- 解压后 CLI 为 0.2.3.33，App 严格签名校验通过，二进制最低系统为 macOS 14。`install.sh` 附件与 App 内的脚本逐字节一致，默认版本为 0.2.3.33，包含 `brew trust` 修复。`SHA256SUMS` 只列发行包，0.2.3.32 的更新脚本可以校验。
- 发布后运行 `curl -fsSL …/releases/latest/download/install.sh | bash -s -- --check`：一行命令入口可访问，下载 0.2.3.33 发行包并通过全部校验，未安装。
- Homebrew：发布后手动触发 tap 的 Update formula 工作流（[运行记录](https://github.com/macfanpro/homebrew-tap/actions/runs/36662367222)），全部步骤成功，由 github-actions 提交配方 `e1284fa`，预编译包 sha256 为 `25c8688a…`。
- 按维护者要求，本机应用未更新，仍为 0.2.3.32。以下尚未实机验证：用新脚本真实安装（需要管理员权限）；在 0.2.3.32 上点“在终端中更新”升级到本版。
