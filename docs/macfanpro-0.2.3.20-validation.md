# MacFanPro 0.2.3.20 验证记录

## 修改范围

- 修复外部代码审计报告的 6 个问题，均继承自上游 ThermalForge，只在原位置增加检查。逐项分析、改法与合并上游时的注意事项见 [风扇状态与校准修复](fan-state-fixes-20260927.md)。
  - `AppState.swift`：按“默认”或选择 Silent 后，丢弃旧模式的变速指令，满速与恢复自动不受影响。
  - `Daemon.swift`：唤醒重放、看门狗复位、高温保护恢复三处在持锁后重新核对状态。
  - `Calibration.swift`：`sudo` 下按 `SUDO_UID` 保存到调用者的主目录并归还文件所有权；过热判断改用 CPU/GPU 安全峰值。
- 温控曲线、传感器读取和 95°C 安全阈值未改变。

## 本机候选版

环境：M4 Max MacBook Pro（Mac16,5），macOS 27.0，以 `./setup.sh` 安装候选代码（当时版本号仍为 0.2.3.19）。

- Debug、Release 各 119 项测试通过（新增 3 项）；各配置 108 次断连检查通过；编译无警告。
- 默认按钮：负载下 Smart 手动控制风扇（约 2800–3100 RPM）时按“默认”，约 3 秒内转为系统控制，此后约 70 秒负载（峰值 77.8°C）内保持系统控制，保存的模式为 Silent。
- 校准：`sudo macfanpro calibrate --mode quick --stress gpu` 的结果与 CSV 保存在用户目录、所有者为用户；记录温度等于同一时刻的 CPU/GPU 峰值；60% 档位达到 84°C 上限后正常跳过更低档位；切换到 Smart 后未出现校准被拒绝的日志。
- 睡眠唤醒：Smart 手动控制风扇时执行 `pmset sleepnow`，睡眠 31 秒后唤醒，风扇保持系统控制，没有回到睡前的手动转速；完全唤醒后 Smart 按实时温度重新接管。后台服务的“重放/跳过”日志被系统日志隐藏，未能直接确认走了哪个分支，也未专门制造“2 秒内执行 auto”的竞争。
- 看门狗与高温保护恢复失败两项无法人为触发，由代码审查覆盖。

详细数据见 [风扇状态与校准修复](fan-state-fixes-20260927.md) 的验证一节。

## 公开发行

- 发行源提交：`85d1c6b`，标签 `v0.2.3.20`。[源码 CI](https://github.com/macfanpro/macfanpro/actions/runs/36297396635)、[发行 CI](https://github.com/macfanpro/macfanpro/actions/runs/36297398060) 通过。
- 下载草稿附件，`SHA256SUMS` 校验通过，与 GitHub asset digest 一致：`MacFanPro-0.2.3.20-macos-arm64.tar.gz` 为 `e16d49f04c12bdda0a11c1d408d1aacfa7dc067da5e11c06ab62dc75c57294cd`。CLI 与应用版本为 0.2.3.20，严格代码签名校验通过。
- 以先退出应用、同步后台、再打开的步骤安装下载产物；已安装的后台服务 CLI 与应用二进制与发行包逐字节一致。
- Homebrew 从 0.2.3.19 升级到 0.2.3.20，`brew test` 通过；同步后后台服务 CLI、应用与 Homebrew 版逐字节一致，三者版本均为 0.2.3.20，无版本不一致提示。
