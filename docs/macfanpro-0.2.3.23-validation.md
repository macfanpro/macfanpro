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

## 发行与本机安装

发行 CI、下载产物校验、Homebrew 升级及最终安装验收将在完成后逐项记录；此处尚不声明已发布或安装成功。
