# MacFanPro 0.2.3.52 验证记录

## 范围

- 包含上游安装改进、安装失败恢复、独立更新窗口和 18 种语言。
- 在首次远端检查中发现 C 暂存缓冲区生命周期错误，已修复并加强目录保护；失败候选 [0.2.3.51](macfanpro-0.2.3.51-validation.md) 未公开发布，不覆盖原标签。
- 用户自行更新本机应用。本次验收不替换已安装应用，不重启真实后台服务或切换风扇状态。

## 本地检查

2026-10-07，修复后的完整源码在候选版本号 0.2.3.51 下重新完成：

- `bash Scripts/test.sh --all-configurations`：Debug、Release 各 155 项测试 / 30 个套件通过。
- 108 次服务端异常断连、300 次客户端断连和 17 项安装脚本测试通过。
- `bash Scripts/check-localization-package.sh .build/release`：18 种语言、内嵌 CLI 与脚本、许可文件、应用交换、失败保留旧包及严格签名验证通过。
- 更新窗口覆盖两种安装渠道、明暗主题、18 种语言、关闭重开、失败重试与重复启动保护。
- 安装覆盖首次安装/升级各阶段故障、恢复失败、无效路径及卸载失败；测试只操作临时目录和模拟服务。

测试日志：`/tmp/macfanpro-0.2.3.51-fixed-tests.log`、`/tmp/macfanpro-0.2.3.51-fixed-package.log`。版本递增到 0.2.3.52 后，Release 构建、CLI 版本和打包检查再次通过；对应日志为 `/tmp/macfanpro-0.2.3.52-build.log` 和 `/tmp/macfanpro-0.2.3.52-package.log`。

再次逐文件确认：`DaemonServer`、风扇/温控、校准、配置、断连与日志实现同合并前 `7163414` 一致。

## 远端与发行附件

- 发行源码 `1c1153a7796284c3d6e94fdeb50c43659f0ce91e` 已先推送 `main`，随后创建注释标签 `v0.2.3.52`。
- [主分支 CI](https://github.com/macfanpro/macfanpro/actions/runs/37583164162) 与 [发行 CI](https://github.com/macfanpro/macfanpro/actions/runs/37583175333) 均成功。Xcode 16.4 的 Debug、Release 各 155 项测试通过；108 次服务端异常断连、300 次客户端断连、17 项安装器及打包检查通过。
- 下载全部 6 个草稿附件，验证 tar、DMG、在线脚本的 SHA-256；`SHA256SUMS` 保持仅含 tar 包。
- 调用实际发行脚本的 `verify_archive` / `verify_package` 完成路径、文件类型、签名与版本验证，没有运行安装入口。
- 只读挂载 DMG，核对应用签名、应用程序链接和安装说明；DMG 与 tar 内应用逐文件哈希一致。
- 主 App、独立 CLI 和内嵌 CLI 版本均为 0.2.3.52，三个二进制均以 macOS 14.0 为最低版本。
- 18 种语言资源与源码一致；内置安装脚本与下载附件一致，许可证及声明齐全。
- 将下载的 CI 二进制放入隔离目录，再运行 `Scripts/check-localization-package.sh`：成功替换、缺失资源和复制中途失败保留原包、严格签名验证全部通过。这一检查直接覆盖将要公开的优化二进制，日志为 `/tmp/macfanpro-0.2.3.52-downloaded-binary-package.log`。

| 附件 | SHA-256 |
| --- | --- |
| `MacFanPro-0.2.3.52-macos-arm64.dmg` | `753cc9a62d8b8c45cd7d8ef80bd8235fdc57e5936465741846e801c2b732ca98` |
| `MacFanPro-0.2.3.52-macos-arm64.tar.gz` | `0e6bc652a05ef2b9f248c23f28ede7c65b15e3321fd4f04ab1a18d423fd83097` |
| `install.sh` | `10b2ed42443076eec633d3d19c97e7892677e6206fcc875be9038a7c28db411d` |

## 公开后的渠道检查

- 2026-10-07 14:51（北京时间）公开发布，GitHub `/releases/latest` 返回 `v0.2.3.52`，非草稿、非预发布，共 6 个公开附件；API 的附件摘要与本地校验一致。
- 对发行附件执行 `bash install.sh --check`，通过公开地址重新下载、校验 tar，输出 `MacFanPro 0.2.3.52 package verification passed; no installation performed.`。日志：`/tmp/macfanpro-0.2.3.52-public-installer-check.log`。
- [Homebrew 更新工作流](https://github.com/macfanpro/homebrew-tap/actions/runs/37583839533) 成功：构建并发布 `arm64_sonoma` bottle，实际从网络下载并安装预编译包，运行 `brew test`、版本与严格签名验证，然后提交配方。
- tap 提交 `0525e4582e1480ead868fdfd7cdf7a8c486ab708`，配方版本为 `v0.2.3.52`，源码指向 `1c1153a7796284c3d6e94fdeb50c43659f0ce91e`。
- bottle SHA-256 为 `60427ea04a84f19a734e4b629014fd79e6124ffa5007a99866cf4ef34eec1f04`，与 GitHub 附件摘要一致。日志：`/tmp/macfanpro-0.2.3.52-homebrew-ci.log`。
- Homebrew 安装检查在 GitHub runner 上执行；未在用户本机运行升级或特权安装。

## 验证边界

- 未执行真实管理员授权、干净 Mac 首次安装、特权服务升级/卸载及温控、睡眠唤醒验收。
- 发行包继续采用 ad-hoc 签名，未经 Apple 公证。
- 安装恢复覆盖可捕获错误，不保证断电、强制终止或磁盘故障后的自动恢复；测试通过不等于不存在任何未知缺陷。
