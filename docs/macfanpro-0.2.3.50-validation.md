# MacFanPro 0.2.3.50 验证记录

## 范围

- 相对 0.2.3.37：DMG 与图形服务向导、上游通信/安装加固、18 种语言官网及文档整合。
- 版本沿用上游基础 0.2.3，修订号按用户要求跳到 50。
- 本机应用由用户自行更新。本次不以替换本机应用或重启真实服务来模拟全新安装。

## 已完成检查

2026-10-05，在版本常量为 `0.2.3.50` 的源码上执行：

- `bash Scripts/test.sh --all-configurations`：Debug、Release 各 143 项测试 / 29 个套件通过。
- 默认 SIGPIPE 行为下，108 次服务端断连、300 次客户端断连检查通过；17 项在线安装器集成测试通过。
- `bash Scripts/check-localization-package.sh .build/release`：内置 CLI、安装脚本、18 种语言、许可文件及资源缺失保护检查通过。
- Release CLI `--version` 输出 `0.2.3.50`。
- `python3 Scripts/build-website.py`：18 种语言页面构建与完整性检查通过。
- `git diff --check` 通过。

## 标签、CI 与草稿附件

- 发布源码：`4063506a0db131a6fa8d6ada381817fd73f67b47`；先推送 `main`，再创建并推送注释标签 `v0.2.3.50`。
- [主分支 CI](https://github.com/macfanpro/macfanpro/actions/runs/37226133615)、[发行工作流](https://github.com/macfanpro/macfanpro/actions/runs/37226140808)与[官网部署](https://github.com/macfanpro/macfanpro/actions/runs/37226133516)均成功。
- 从 GitHub 发行草稿下载全部 6 个附件，并校验 DMG、tar、安装脚本各自的 SHA-256；`SHA256SUMS` 仍只包含 tar 包。
- 使用实际安装器的 `verify_archive` / `verify_package` 校验并解包 tar，未调用安装入口。
- 只读挂载 DMG；应用通过 `codesign --verify --deep --strict`，确认 ad-hoc 签名。DMG 与 tar 内应用逐文件 SHA-256 一致。
- App、内置 CLI 与独立 CLI 版本均为 0.2.3.50；三个二进制均以 macOS 14.0 为最低版本。
- 18 种语言资源与标签源码一致，内嵌安装脚本与发行附件一致；“应用程序”链接、安装说明与许可文件齐全。
- 内置 CLI 的非 root 安装调用被拒绝；没有触发管理员授权或服务安装。

| GitHub 草稿附件 | SHA-256 |
| --- | --- |
| `MacFanPro-0.2.3.50-macos-arm64.dmg` | `6f430ed033ba49cb565b483bf6391f6f8bfcf11e88b05322261e204555570c9c` |
| `MacFanPro-0.2.3.50-macos-arm64.tar.gz` | `fd71134a57f070ab3f794702c203e642fdf6fb2c7a0d254dc350c60b641f1db6` |
| `install.sh` | `24a6c4a046873147ecb6c2bc11b6c8a531136f6bbf26b5984a4e8649b4692be2` |

## 公开发布后的检查

- GitHub 最新正式发行确认为 `v0.2.3.50`，非草稿、非预发布，共 6 个公开附件。北京时区发布时间：2026-10-05 02:59。
- 执行本发行附件 `install.sh --check`，从公开下载地址重新下载 tar 并完成校验，输出 `MacFanPro 0.2.3.50 package verification passed; no installation performed.`。
- 使用独立无头浏览器访问线上中文官网，确认 DMG 下载按钮可见，并实际指向本版 DMG；没有模拟发行 API 响应。
- [Homebrew 自动更新](https://github.com/macfanpro/homebrew-tap/actions/runs/37226551880)成功：构建并公开 `arm64_sonoma` bottle、重新从网络安装预编译包、通过 `brew test` 和 CLI 版本检查，再提交配方。
- tap 提交 `9d18745`；配方指向 `v0.2.3.50` 与源码 `4063506a0db131a6fa8d6ada381817fd73f67b47`。bottle SHA-256：`8d68d2abda79057e79f3f2b7e5a539a45dec092b850dc77cf28818daaea54126`。
- Homebrew 验证在 GitHub runner 上完成；没有在用户本机执行 `brew upgrade` 或特权安装。

## 验证限制

- 真实系统授权、干净 macOS 首次安装、特权服务升级/卸载、温控负载和睡眠唤醒实机验收未执行。
- 向导状态测试注入隔离的授权和服务探测结果；截图只验证界面与布局，不作为真实授权结果。
- 只读挂载、签名校验和 `install.sh --check` 不安装服务或更改风扇状态。
- 发行包沿用 ad-hoc 签名，未经过 Apple 公证。
