# MacFanPro 0.2.3.38 验证记录

## 问题来源

2026-10-02 检查本机日志：

- 应用日志无 ERROR/WARN，无崩溃报告；9 月 28 日的多次 95°C 保护在本地模型压力测试期间均把风扇拉到最大。
- `/Library/Logs/DiagnosticReports` 中有 4 份 `macfanpro`（后台服务，父进程 launchd）的磁盘写入报告：9/25、9/27、9/28、10/1。
  - 每份都在 6–17 小时内达到 2 GB“file backed memory dirtied”。10/1 那份 6 小时 2 GB，平均 101.53 KB/s，系统限制为 24.86 KB/s。
  - 最重调用栈全部在 `TFLogger.write` → `RuntimeLogStore.write` → `NSFileHandle.write`。
- 后台服务日志 `/var/root/Library/Logs/MacFanPro`：`macfanpro-2026-10-01.1.log` 约 5 小时 102,797 行，其中 102,693 行是 `[FAN] Set fan N to N RPM`。
  - 智能模式的平滑调速约每秒 10 步、每步约 14 RPM，两个风扇各记一行；99% 的行目标值都不同，是设计行为而非重复调用。
  - 日志每天达到 5 MB 上限 1–2 次。
- 上游 ThermalForge 同样每次写入记录一行（`FanControl.swift` 的 `log("Set fan …")`），属于继承行为。

## 修改范围

- `FanControl.swift`：新增 `FanSetLogThrottle`，`setSpeed` 与 `setAllFans` 的日志每个风扇最多每 5 秒一行，并注明“N ramp steps since the last line”；`resetAuto` 清空限流状态，使复位后的第一次设定立即记录；`setMax` 与复位日志不限流。
- 没有日志记录器时（测试注入的 SMC）不做任何处理。风扇写入、曲线与保护逻辑不变。

## 本机候选版

环境：M4 Max MacBook Pro（Mac16,5），macOS 27.0.1。

- Swift 测试 152 项（新增 2 项：12 秒、两个风扇的 240 次写入只记 6 行且计数正确；间隔超过 5 秒的写入全部记录，复位后立即记录）、安装器集成测试 17 项、打包检查通过。

## 公开发行

待发行包验收后填写。
