# MacFanPro 0.2.3.54 验证记录

## 范围

- 采用 ThermalForge #31（`42bb534`）中此前未合入的风扇生命周期处理，代码与上游保持一致：
  - `FanControl.manualControlEngaged`：任一风扇处于手动模式，或 M1–M4 的 `Ftst` 仍置位，即视为手动控制；读取失败抛出错误。
  - `StartupFanReconcile`：服务启动时发现手动控制就交回 Apple；读取失败也交回；交回失败记为待释放，由看门狗重试（本项目补充）。
  - `DaemonShutdown` 与 SIGTERM 处理：只在持有控制、高温覆盖或有待释放时复位；复位后保持 SMC 锁直到退出。本项目把待释放也计入。
  - 安装：停止旧服务前先通过服务（不可用时直接）把风扇交回 Apple，失败只警告，新服务启动时的检查兜底。
- 有意不采用：上游看门狗在高温覆盖期间也立即交回系统。本项目保持最大转速直到降温。日志、sudo 用户数据也保留本项目实现。取舍见 [upstream-sync-20261007.md](upstream-sync-20261007.md) 与 [upstream-divergence.md](upstream-divergence.md)。
- 新增 `AGENTS.md`（`CLAUDE.md` 引用它）：多代理各用分支和 PR、同一时间只发一个版本、上游合并的记录方式。
- 整理：更新 `docs/README.md` 索引；删除已确认内容在 `main` 中的 7 个 `codex/*` 远程与本地分支，及两个已合并的遗留 worktree。

## 发布前检查

- 新增 `DaemonStartStopTests` 6 项：上游的启动与停止判定；用模拟 SMC 驱动真实 `DaemonServer` 验证手动状态检测、启动时交回、失败后看门狗重试、SIGTERM 只在持有控制时写入。
- `bash Scripts/test.sh --all-configurations`：Debug、Release 各 166 项测试 / 31 个套件通过；断连回归与 17 项安装脚本测试通过。

## 远端 CI、发行附件与实机验证

待填写。
