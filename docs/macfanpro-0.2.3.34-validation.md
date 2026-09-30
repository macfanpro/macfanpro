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

待发行包验收后填写。
