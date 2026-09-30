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

待发行包验收后填写。
