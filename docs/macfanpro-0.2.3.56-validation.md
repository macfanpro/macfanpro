# MacFanPro 0.2.3.56 验证记录

## 范围

- 采用上游 `DaemonLog`（ThermalForge #31）：后台服务的 24 处诊断（`Daemon.swift`）和连接层 4 处（`ConnectionServer.swift`）由 `NSLog` 改为公开的统一日志，子系统 `io.github.macfanpro.daemon`；请求记录的措辞与上游逐行一致。
- 起因：0.2.3.55 本机升级后查询系统日志，`macfanpro` 进程的条目全部是 `<private>`。
- README 中、英文补充读取方式；运行日志文件、风扇控制不变。

## 发布前检查

- `bash Scripts/test.sh --all-configurations`：Debug、Release 各 166 项测试 / 31 个套件、断连回归、17 项安装脚本测试通过。

## 远端 CI、发行附件与实机验证

待填写。
