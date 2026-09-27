# MacFanPro 0.2.3.23 验证记录

## 修改范围

第四轮复核的 R1–R6 已修复：已有 hold 时部分写入失败的恢复、看门狗保护状态竞态、自动重试覆盖 CLI、短间隔升降速、watch 复位重试、逐风扇应用目标回报。控制逻辑和模拟测试细节见 [Fourth review](fan-state-fixes-20260927.md#fourth-review-recovery-and-acknowledgement-working-tree-2026-09-27)。

- 生产代码增加可注入时钟、SMC、日志和采样的测试入口，测试不连接已安装后台服务。
- GUI 与 watch 按实际执行结果确认状态，失败后保留恢复义务；配置切换使旧回调失效。
- `auto-if-app` 在后台服务的硬件锁内保护 CLI 所有权；旧服务会拒绝新指令，因此 App 与 daemon 必须一起更新。
- 逐风扇响应向后兼容旧 JSON；旧服务只有单个 RPM 时，新 CLI 不会将其冒充所有风扇的目标。
- Smart 曲线、持续触发时间、95°C / 90°C 保护策略保留。

## 本机源码验证

2026-09-27，M4 Max MacBook Pro、macOS 27.0。修复代码在升版本号前完成：

- `bash Scripts/test.sh`：145 tests / 23 suites，通过；108 次断连及后续请求检查通过。
- `bash Scripts/test.sh -c release`：145 tests / 23 suites，通过；断连进程测试再次通过。
- `swift build -c release`：App 与 CLI 构建通过。
- 语言资源、包身份、LICENSE、缺失资源拒绝覆盖检查通过。
- 编译无警告、无错误，`git diff --check` 通过。

本轮未运行高温压力、校准或实机睡眠唤醒故障注入。模拟验证不能替代这些硬件场景。

## 发行与下载产物

- 修复提交：`f3849d4`；发行源提交：`a9d5fe08688846ac554d3501082c186684cd313f`，不可变标签 `v0.2.3.23`。
- [源码 CI](https://github.com/macfanpro/macfanpro/actions/runs/36305899581) 与 [发行 CI](https://github.com/macfanpro/macfanpro/actions/runs/36305901254) 均通过。两条流水线的 Debug、Release 各 145 项测试、各 108 次断连检查通过；最终日志无编译警告或错误。
- 下载草稿附件后验收：CLI、App 版本均为 0.2.3.23，二者架构为 arm64；应用标识为 `io.github.macfanpro.app`，最低系统版本为 14.0。
- `codesign --verify --deep --strict` 通过；签名为 ad-hoc，未进行 Apple 公证。英文、简体中文、繁体中文资源及 LICENSE、NOTICE、ThirdPartyNotices 与发行源文件一致。
- 发行包 SHA-256 与 `SHA256SUMS`、GitHub asset digest 一致：

  ```text
  54470948804a893ede5579fbb2a6c134bc729efe014784d100c1c2f1ad889774  MacFanPro-0.2.3.23-macos-arm64.tar.gz
  ```

- 完成上述验收后，于 2026-09-27 08:28:16 UTC [公开发布](https://github.com/macfanpro/macfanpro/releases/tag/v0.2.3.23)。从公开下载 URL 重新获取的文件与草稿附件逐字节一致，GitHub latest 指向该非预发行版本。

## Homebrew 与本机安装

2026-09-27，M4 Max MacBook Pro（Mac16,5），macOS 27.0 / 26A428。

- [Homebrew tap 提交 `1eecfc9`](https://github.com/macfanpro/homebrew-tap/commit/1eecfc9) 将配方固定到 `v0.2.3.23` 及完整发行源提交。
- `brew upgrade macfanpro` 从 0.2.3.22 升级至 0.2.3.23，随后 `brew test macfanpro` 通过。没有运行全局 `brew update`；其他 tap 的信任提示不影响本次定向升级。
- 先执行 `macfanpro auto --stop-app`，再调用当时仍为 **0.2.3.22** 的 `/usr/local/bin/macfanpro install`。安装器明确输出从 Homebrew 0.2.3.23 重同步 CLI，并选择 0.2.3.23 应用包；这次实测补齐了上版 F9 的“旧安装器升级至新 keg”场景。
- 重新打开 `/Applications/MacFanPro.app`。CLI、App 元数据、运行中 daemon 的帧协议 `version` 响应均为 **0.2.3.23**。
- 新 daemon PID 为 40760，新 App PID 为 40766，均不同于升级前进程；launchd 为 `running`，启动参数仍限定当前用户 UID 501。
- `/usr/local/bin/macfanpro` 与 Homebrew CLI 逐字节一致；已安装 App 的全部 9 个文件与 Homebrew App 一致，严格代码签名验证通过。
- CLI 为 root:wheel、0755；launchd plist 为 root:wheel、0644；socket 归当前用户所有、0600。常规 `status` 读取成功，验收时双风扇均由系统控制，状态为无手动 hold、无高温保护挂起。
- 保留 Smart、跟随系统语言、摄氏度设置；`calibration.json` 归属当前用户，升级前后 SHA-256 均为 `ae3f21af50d214851e2fdf6cee86258870b081ce8f5d3ce09e7ef6f676aa6c91`。
- 启动日志记录新 daemon 开始监听和 App 无活动 hold 的正常启动。本轮未观察到启动或版本错误。

安装来源是 Homebrew 的本机源码构建；下载发行包单独完成了完整性、签名和资源验证。本轮未将下载发行包安装到 `/Applications`，因此不将两种构建的二进制视为相同。

### 证据与剩余范围

- 下载、安装日志、升级前后快照及 0.2.3.22 的运行文件备份保存在本次临时验收目录 `macfanpro-023-release-71tv33l4`；Homebrew 旧 keg 也保留。临时目录不是长期备份。
- 本轮完成源码测试、CI、下载产物与 Homebrew 实机升级验收；未运行高温压力、重新校准或实机睡眠唤醒故障注入。故障恢复和锁时序由上述模拟回归测试覆盖，不能据此声明所有硬件场景均已验证。
