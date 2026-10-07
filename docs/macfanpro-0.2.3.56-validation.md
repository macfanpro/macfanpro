# MacFanPro 0.2.3.56 验证记录

## 范围

- 采用上游 `DaemonLog`（ThermalForge #31）：后台服务的 24 处诊断（`Daemon.swift`）和连接层 4 处（`ConnectionServer.swift`）由 `NSLog` 改为公开的统一日志，子系统 `io.github.macfanpro.daemon`；请求记录的措辞与上游逐行一致。
- 起因：0.2.3.55 本机升级后查询系统日志，`macfanpro` 进程的条目全部是 `<private>`。
- README 中、英文补充读取方式；运行日志文件、风扇控制不变。

## 发布前检查

- `bash Scripts/test.sh --all-configurations`：Debug、Release 各 166 项测试 / 31 个套件、断连回归、17 项安装脚本测试通过。

## 远端 CI 与发行附件

- 源码 `962bc7a`，注释标签 `v0.2.3.56`。[主分支 CI](https://github.com/macfanpro/macfanpro/actions/runs/37609795804)、[发行 CI](https://github.com/macfanpro/macfanpro/actions/runs/37609795646) 通过。
- 下载全部 6 个草稿附件，三个校验文件通过，与 GitHub asset digest 一致：
  - tar `b9f46a6c655bb4275ad0f95e8fee88d8625b2779b32c169b05a70eb301364eaa`
  - DMG `4ff584ad7bfa14e559ccc725d550c4042897f9d17d21750d4d5261ac9969e65a`
  - `install.sh` `b3893bcc1709f22fce0cc9e2e605c4de9815e827226fd1d3da63d1c57ad1230d`
- CLI 为 0.2.3.56，严格签名通过，最低 macOS 14；二进制包含 `io.github.macfanpro.daemon` 子系统；内嵌安装脚本与附件一致；DMG 与 tar 内应用逐文件一致。
- 公开发布后 release 事件自动启动 tap 更新（[运行记录](https://github.com/macfanpro/homebrew-tap/actions/runs/37610480319)），配方与预编译包提交为 `8bd293c`。

## 实机验证（2026-10-07，M4 Max，macOS 27.0.1）

用发行附件 `install.sh --version 0.2.3.56` 从 0.2.3.55 升级（Homebrew），之后在同一终端会话连续执行。风扇状态取自 `macfanpro status`，服务消息取自 `log show --predicate 'subsystem == "io.github.macfanpro.daemon"'`。

| 步骤 | 结果 |
| --- | --- |
| 安装 | 输出 “Fans released to Apple defaults for the daemon restart.”，最后确认 0.2.3.56 服务运行；无 y/n 确认 |
| 1. `macfanpro set 3000` 后 `kill -9` 服务 | 两个风扇 `manual@3000`；launchd 重启的新服务记录 “fans were under manual control with no hold at startup; reset to auto”，风扇恢复系统控制 |
| 2. `set 3000` 后 `launchctl kill SIGTERM` | 旧服务记录 “stopping: released fans to auto”，退出后风扇为系统控制 |
| 3. 未持有控制时 SIGTERM | 无释放记录；新服务未发现手动状态，无复位 |
| 4. `sudo macfanpro watch --profile performance` 20 秒后 Ctrl-C | 退出码 0；空闲温度约 50°C 未达曲线，没有接管风扇；结束后为系统控制 |
| 5. 快速校准 45 秒后 Ctrl-C | “Calibration interrupted. No calibration data was saved.”；`calibration.json` 哈希不变；运行中的应用被退出并自动重新打开（PID 51410 → 51772）；结束后为系统控制 |
| 7. 系统日志 | 服务消息以明文显示，请求记录（`verb=…`）可读 |

**观察**：第 2 步中，旧服务释放后约 46 毫秒，新服务启动时仍读到手动状态，又执行了一次交回系统。释放代码会写入模式 0 并清除 `Ftst`，期间没有其他写入，推测是 M4 固件在释放后极短时间内的回读尚未更新。第二次复位是幂等操作，结果都是系统控制，没有修改。

**未覆盖**：睡眠唤醒、长时间运行、高温保护在真实高温下的触发（仍由模拟 SMC 测试覆盖）、完整校准、DMG 图形化安装路径。
