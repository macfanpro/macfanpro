# MacFanPro 0.2.3.34 验证记录

## 修改范围

- 起因：在 0.2.3.32 上点“在终端中更新”，把 Homebrew 从 0.2.3.32 升到 0.2.3.33。升级成功，但暴露出三个问题：Homebrew 7 的 `y/n` 确认夹在输出中难以发现；`brew update` 刷新所有 tap，输出无关镜像的错误和未受信任 tap 的警告；`auto --stop-app` 在同步前显示版本不一致警告。
- `Scripts/install.sh`（Homebrew 路径）：
  - 先 `git pull --ff-only` 只拉取 `macfanpro/tap`，失败时退回 `brew update`；
  - 升级时设置 `HOMEBREW_NO_ASK=1`、`HOMEBREW_NO_AUTO_UPDATE=1`、`HOMEBREW_NO_ENV_HINTS=1`；
  - 之后的版本检查不变。
- `macfanpro auto --stop-app`：路由到后台服务且仅是版本不同时，不再输出版本不一致提示；其他情况照常报告。
- 主仓库新增 `notify-tap.yml`：正式发布后用 `TAP_DISPATCH_TOKEN` 立即启动 tap 的 Update formula 工作流。
- 风扇控制未改变。

## 本机候选版

环境：M4 Max MacBook Pro（Mac16,5），macOS 27.0，经系统代理访问 GitHub。

- Swift 测试 149 项、安装器集成测试 16 项（新增断言：只拉取本 tap、不执行 `brew update`、升级时不询问且不自动更新；拉取失败时退回 `brew update`）、打包检查、`shellcheck` 通过。
- 本机实际执行 `git -C "$(brew --repository macfanpro/tap)" pull --ff-only --quiet` 成功。
- `notify-tap.yml` 手动运行一次，成功启动 tap 工作流；配方已是最新，跳过构建。

## 公开发行

- 发行源提交：`85f65c1`，标签 `v0.2.3.34`。[源码 CI](https://github.com/macfanpro/macfanpro/actions/runs/36666082243)、[发行 CI](https://github.com/macfanpro/macfanpro/actions/runs/36666082231) 通过。
- 草稿附件 4 个，两个校验文件通过，与 GitHub asset digest 一致：
  - 发行包 `7ac6a22d7f533393341f3455d91fc578ba43053ef259919a83700ae1de4f373f`
  - `install.sh` `15b452a861ce191886a70d4b5ad2f443fadd47a5e7b91faa7b8cda81296c4263`
- CLI 为 0.2.3.34，严格签名通过，最低系统 macOS 14；`install.sh` 附件与 App 内脚本逐字节一致，包含 `HOMEBREW_NO_ASK=1`。
- **发布即触发 Homebrew（首次实跑）**：公开发布后，主仓库的 [Update Homebrew tap](https://github.com/macfanpro/macfanpro/actions/runs/36666433634) 由 release 事件自动运行，启动 tap 的 [Update formula](https://github.com/macfanpro/homebrew-tap/actions/runs/36666440197)。约 2 分钟后，配方与预编译包提交为 `474f942`（sha256 `06152c92…`）。
- **从 0.2.3.33 点“在终端中更新”升级（首次实跑新安装脚本的 Homebrew 路径）**：
  - 版本检测显示 0.2.3.34，按下按钮，终端执行 0.2.3.33 附带的 `install.sh`，点击后约 45 秒完成。
  - 旧脚本仍执行 `brew update`：graalvm 镜像失败后显示“brew update failed; continuing with the current tap.”并继续（`f4ab4ff` 的修复生效）。
  - 升级前的 `y/n` 确认按了一次 y（本版已去除，下次更新起生效）。
  - 预编译包直接安装；`sudo -v` 先要求密码，再停止应用。
  - 0.2.3.34 的 `auto --stop-app` 面对 0.2.3.33 后台服务**未显示**版本不一致警告，本版修复实机生效。
  - 安装后脚本核对 App、CLI、签名、launchd 与 socket，输出“MacFanPro 0.2.3.34 installed and the background service is running.”，重新打开应用。
  - 核对结果：Homebrew 0.2.3.34（预编译包安装）；后台服务 pid 1302，二进制与 keg 一致；`/Applications` 应用与 keg 一致，严格签名通过；无版本不一致；私有临时目录已清理；Smart 模式保留。
- 未实机验证：本版脚本“只拉取本 tap、升级无确认”的效果，需下个版本更新时实测。
