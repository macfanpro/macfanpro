# MacFanPro 0.2.3.53 验证记录

## 范围

- 包含 [2026-10-07 审计](code-audit-20261007.md)确认的 7 类修复。
- 先将修复提交并推送 `main`，再创建版本标签；CI 创建草稿后，下载检查实际发行包，通过后公开发布。
- 本机应用由用户自行更新，本次发布不替换已安装应用或后台服务。

## 发布前检查

2026-10-07，包含附加组权限修复和最终版本号的完整源码重新通过：

- `bash Scripts/test.sh --all-configurations`：Debug、Release 各 160 项测试 / 30 个套件，分别耗时约 25.63 秒和 24.55 秒。
- 108 次客户端提前断连、300 次服务端提前断连及 17 项安装脚本测试通过。
- `bash Scripts/check-localization-package.sh .build/release`：18 种语言、内嵌 CLI 与安装脚本、许可文件、应用替换、失败保留旧包和严格签名验证通过。
- Release CLI 报告版本 `0.2.3.53`，`git diff --check` 通过。
- 日志：`/tmp/macfanpro-0.2.3.53-tests.log`、`/tmp/macfanpro-0.2.3.53-package.log`。

审计阶段的实机读取、进程中断和完整用户组权限验证见审计报告。

## 远端 CI 和发行附件

- 修复源码 `e6162c587345a83e73dfd707fd866baf508c0e3f` 已先推送 `main`，随后创建注释标签 `v0.2.3.53`。
- [主分支 CI](https://github.com/macfanpro/macfanpro/actions/runs/37589670168) 与 [发行 CI](https://github.com/macfanpro/macfanpro/actions/runs/37589705909) 均成功；两条工作流各自完成 Debug、Release 各 160 项测试、108 / 300 次断连回归、17 项安装器及打包检查。
- 下载全部 6 个草稿附件，验证 tar、DMG 和在线脚本 SHA-256；`SHA256SUMS` 保持只含 tar 包，兼容已部署更新器。
- 调用实际下载脚本的 `verify_archive` / `verify_package`，通过路径、文件类型、签名及版本检查，没有运行安装入口。
- 独立 CLI、内嵌 CLI、应用包版本均为 0.2.3.53；三个二进制都是 arm64，最低系统为 macOS 14.0，严格签名校验通过。
- 18 种语言资源与源码一致，内嵌安装脚本与下载附件一致，许可和第三方声明一致。
- 只读挂载 DMG，核对 Applications 链接和安装说明；DMG 与 tar 内应用逐文件哈希一致。
- 用实际下载的 CI 二进制在隔离目录运行打包回归：成功替换及缺失资源、复制失败时保留旧包全部通过。
- 下载目录：`/tmp/macfanpro-0.2.3.53-assets.QT2fgfYD/`；结果：目录内 `verification.json`，以及 `/tmp/macfanpro-0.2.3.53-artifact-check.log`。

| 附件 | SHA-256 |
| --- | --- |
| `MacFanPro-0.2.3.53-macos-arm64.dmg` | `31922ef0eb928721ef7509c8e80597b9b318448000003b80441525128ae8db96` |
| `MacFanPro-0.2.3.53-macos-arm64.tar.gz` | `185a135da8ca083bbb9b57ab6671b5c7ae00317379e6b22d3b52969c1149eadd` |
| `install.sh` | `c06c27164af56707e98e55047e3c684a77eb3303faa51a685fc7ae6dc20019c9` |

## 公开后的渠道检查

- 2026-10-07 15:55（北京时间）公开发布；GitHub `/releases/latest` 返回 `v0.2.3.53`，非草稿、非预发布，6 个附件的 API 摘要与已验收下载文件一致。
- 对发行附件执行 `bash install.sh --check`，通过公开地址重新下载并校验 tar，输出 `MacFanPro 0.2.3.53 package verification passed; no installation performed.`。日志：`/tmp/macfanpro-0.2.3.53-public-installer.log`。
- 线上官网脚本从 `/releases/latest` 获取 DMG，在线与代理命令也使用 latest 入口，本次发布无需修改版本链接。
- [Homebrew 通知](https://github.com/macfanpro/macfanpro/actions/runs/37590398809)与 [Homebrew 更新任务](https://github.com/macfanpro/homebrew-tap/actions/runs/37590413368)均成功。预编译包已经公开，GitHub runner 实际下载安装 bottle，通过 `brew test`、版本与严格签名校验后提交配方。
- tap 提交为 `bdf17bf217e660ba4406552a88286b4a90bee4c3`，配方标签为 `v0.2.3.53`，源码指向 `e6162c587345a83e73dfd707fd866baf508c0e3f`。
- `arm64_sonoma` bottle SHA-256 为 `9a2f8b72847f0427654feed43a981dac836cfaa6704851457d41f54be21beed0`，配方与公开附件 API 摘要一致；日志为 `/tmp/macfanpro-0.2.3.53-homebrew-ci.log`。
- 发布结束再次核对本机：应用与 CLI 仍为 0.2.3.37，应用 PID 89041、后台 PID 89036，保存的模式仍为 Smart。Homebrew 安装验收在 GitHub runner 执行。

## 验证边界

- 实机审计使用真实 SMC 读取、真实进程信号和文件权限；危险温度、控制权冲突与写入失败使用隔离模拟硬件。
- 未将本机已安装服务升级为本版，未进行新版服务长时间运行、完整负载校准、睡眠唤醒或干净 Mac 首次安装验收。
- 保持 ad-hoc 签名，未经 Apple 公证。测试通过不等于不存在未知缺陷。
