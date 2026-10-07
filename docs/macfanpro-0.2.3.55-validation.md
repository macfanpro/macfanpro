# MacFanPro 0.2.3.55 验证记录

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

## 版本号说明

同样内容先以 0.2.3.54 打标签，CI 与发行草稿均通过（[发行 CI](https://github.com/macfanpro/macfanpro/actions/runs/37607491044)），未公开发布。按维护者要求改为 0.2.3.55：删除 0.2.3.54 草稿与标签，代码不变，仅改版本号与文档。

## 远端 CI 与发行附件

- 源码 `cbb1aa0`，注释标签 `v0.2.3.55`。[主分支 CI](https://github.com/macfanpro/macfanpro/actions/runs/37608303032)、[发行 CI](https://github.com/macfanpro/macfanpro/actions/runs/37608303914) 通过。
- 下载全部 6 个草稿附件，三个校验文件通过，与 GitHub asset digest 一致：
  - tar `c1d05b1d5106058dc4a7e27195e0c80c570d72da5c215fa8f1bdb30a641f7b81`
  - DMG `16ccb55b74fa41d3b9bc913e19580887ca25a80d0e2b99ca5958c047c49ae654`
  - `install.sh` `d0f7f64281c7e70134ed07c07b3ff4994ab7aabeb0082d1b7558717e1809ef53`
- CLI 为 0.2.3.55，严格签名通过，最低 macOS 14；内嵌安装脚本与附件一致；二进制包含启动时交回风扇的新代码；只读挂载 DMG，其中应用与 tar 内逐文件一致。
- 公开发布后，release 事件自动启动 tap 更新（[运行记录](https://github.com/macfanpro/homebrew-tap/actions/runs/37609045366)），配方与预编译包提交为 `301f9e1`。

## 本机升级

- 用发行附件 `install.sh --version 0.2.3.55` 从 0.2.3.53 升级（Homebrew 安装）：只刷新本 tap、无 y/n 确认、无全量 `brew update` 输出（0.2.3.34 的改进首次实机确认）。
- 第一次在无终端环境运行时卡在 `sudo -v`，此时尚未停止应用或服务，现有安装未受影响；随后在终端输入密码完成。输出新增 “Fans released to Apple defaults for the daemon restart.”，最后确认 “MacFanPro 0.2.3.55 installed and the background service is running.”。
- 应用、命令行、后台服务均为 0.2.3.55，命令行与 Homebrew keg 一致，严格签名通过。
- 实机检查发现：后台服务通过 `NSLog` 写入系统日志的内容全部显示为 `<private>`，无法用于诊断。0.2.3.56 改用上游 `DaemonLog` 修复，风扇启动/停止行为的实机测试在 0.2.3.56 上进行，见 [0.2.3.56 验证记录](macfanpro-0.2.3.56-validation.md)。
