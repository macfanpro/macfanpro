# 测试精简记录（2026-10-03）

基线：`e091252`。本次调整测试组织、运行脚本和对应 CI 命令，产品源码与版本号未变。

## 合并内容

| 测试组 | 原入口数 | 现入口数 | 保留或替代的覆盖 |
| --- | ---: | ---: | --- |
| Profiles | 17 | 5 | 模式选择、完整预设参数、16 组模式输出与迟滞输入、5 组自定义曲线输入；JSON 往返合并到实际保存/加载测试；95°C 与 5°C 常量断言移入 Daemon invariants 的阈值测试 |
| UpdateChecker | 11 | 5 | 新旧/相同版本、三段与四段版本、进位、末尾零、非法标签、协议兼容和重定向来源检查 |
| Data Conversion / Fan Key | 8 | 4 | 原有字节编码、零值、硬件模式键名；补充“报告 4 字节但存储不足”的输入 |
| SMC sensor filter | 6 | 3 | 原有 17 组传感器输入集中为表格；位置解码和有机型限制的只读硬件查询仍独立运行 |
| Displayed CPU temperature | 6 | 4 | 三种 CPU 回退路径集中为表格；M4 实测样本、显示与保护温度区别、标题温度及空读数检查保留 |
| 其余测试 | 102 | 102 | 控制归属、热保护、连接协议、写入失败恢复、并发、日志、国际化、安装更新等独立回归保留 |
| **合计** | **150** | **123** | **24 个测试套件** |

这里统计的是测试函数入口。同类场景合并后仍逐行断言，并在失败信息中标明输入。入口减少不代表删除了 27 个故障场景，也不用于推算执行时间的降幅。

实际去重包括：预设值不再由多个函数反复断言；编码/解码通过完整磁盘往返覆盖；版本排序由全组合改为相邻边界、跨组件进位和反向比较，`UpdateChecker.evaluate` 调用从每轮 175 次降为 57 次。保存测试给内置模式使用不同名称，避免加载失败后返回默认模式而误通过。

## 一次执行两个编译配置

```bash
bash Scripts/test.sh --all-configurations
```

Swift 测试继续分别在 Debug、Release 下运行，确保优化构建也接受验证。独立编译的断连回归和 Python 安装器测试各运行一次，原先各运行两次。CI 与 Release 工作流共用此入口；`swift test` 已构建应用和 CLI，因此移除 CI 中重复的 `swift build`。

日常开发仍可用 `bash Scripts/test.sh` 运行 Debug，或用 `bash Scripts/test.sh -c release` 只运行 Release。`--all-configurations` 必须放在第一个参数，不能同时指定 `-c` / `--configuration`；其余 Swift 测试参数会原样传递。

## 验证

- `bash Scripts/test.sh --all-configurations`：Debug、Release 各 123 个测试、24 个套件通过；断连回归通过；安装器 17 个测试通过。日志确认独立集成检查各执行一次。
- `bash Scripts/check-localization-package.sh`：语言资源、安装器打包与缺失资源保护通过，同时确认移除独立 Build 步骤后，Swift 测试构建仍提供完整应用和 CLI。
- 临时命令替身检查 12 种脚本调用：默认配置、指定 Release、双配置、带空格参数传递、各阶段失败即停止、四种冲突配置写法；全部通过。
- 故障注入：预设触发时间错误、忽略保存的内置模式、按字典序比较版本、错误放行电池传感器，分别被 `builtInCurves`、`persistenceRoundTrip`、`numericOrder`、`sensorAcceptance` 拦截。每次注入后逐字节恢复源码，最终 `git diff -- Sources` 为空。
- `git diff --check` 与测试脚本 Bash 语法检查通过。

这次验证针对测试与构建流程，没有执行本机应用安装或真实风扇写入。
