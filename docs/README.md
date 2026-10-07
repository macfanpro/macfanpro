# Documentation / 文档索引

Start with [English README](../README.md) or [中文 README](../README.zh-CN.md) for installation, daily use and the fan-control principles. This index groups deeper material by task. Historical test records apply to the version and machine named in each record.

安装、日常使用与风扇控制原理请先阅读 README。下面按任务整理深入资料；历史验证记录只代表其中注明的版本和机器。

## Install and use / 安装与使用

| Topic / 主题 | Guide / 文档 |
| --- | --- |
| Drag-and-drop installation / 拖拽安装 | [DMG and service setup / DMG 与服务向导](dmg-installation.md) |
| Installation and proxy access / 安装与代理 | [Online installer / 在线安装器](online-installer.md) |
| Fan curves, Smart and calibration / 曲线、智能与校准 | [English](../README.md#fan-curves-and-smart-mode) · [中文](../README.zh-CN.md#风扇曲线与智能模式原理) |
| Sensor readings and comparison with Stats / 传感器读数对照 | [Sensor calibration / 传感器校准记录](thermal-sensor-calibration-20260924.md) |
| Runtime logs and CSV recording / 运行日志与采样 | [English](../README.md#logs-and-data) · [中文](../README.zh-CN.md#日志与数据) |
| Release changes / 已发行变化 | [Changelog](../CHANGELOG.md) · [GitHub Releases](https://github.com/macfanpro/macfanpro/releases) |

## Develop and maintain / 开发与维护

| Topic / 主题 | Guide / 文档 |
| --- | --- |
| Contribution workflow / 贡献流程 | [CONTRIBUTING.md](../CONTRIBUTING.md) |
| Rules for AI agents and parallel work / 多代理协作规则 | [AGENTS.md](../AGENTS.md) |
| Test consolidation / 测试精简与覆盖对应 | [2026-10-03 consolidation](test-consolidation-20261003.md) |
| Fan ownership, failure recovery, calibration / 控制归属、失败恢复与校准 | [Fan-state fixes](fan-state-fixes-20260927.md) |
| M4 firmware handoff and transport / M4 固件接管与通信 | [M4 handoff repair](m4-handoff-repair.md) |
| Fork differences / 上游差异 | [Upstream divergence](upstream-divergence.md) |
| Latest upstream merge / 最近上游合并 | [2026-10-07 installation hardening (#31)](upstream-sync-20261007.md) |
| Full code audit / 全面代码复查 | [2026-10-07 audit](code-audit-20261007.md) |
| Previous upstream merges / 前次上游合并 | [2026-10-04](upstream-sync-20261004.md) · [2026-10-03](upstream-sync-20261003.md) |
| Earlier upstream decisions / 早期上游取舍 | [2026-09-21 audit](upstream-followups-20260921.md) |
| Translation and packaging / 翻译与打包 | [GUI localization](gui-localization.md) |
| Native menu layout / 原生菜单排版 | [Label validation](menu-bar-label-validation.md) |
| Release preparation / 发布准备 | [Release guide and template](releases/README.md) |
| Installer checks / 安装器验证 | [Installer validation](online-installer-validation.md) |
| Idle CPU measurements / 空闲 CPU 测量 | [Experiments](idle-cpu-experiments.md) |

## Validation history / 验证历史

| Versions / 版本 | Records / 记录 |
| --- | --- |
| 0.2.3.15–17 | [Packaging and install](macfanpro-0.2.3.15-validation.md) · [Sensors](macfanpro-0.2.3.16-validation.md) · [Log writer](macfanpro-0.2.3.17-validation.md) |
| 0.2.3.18–19 | [Menu blocks](macfanpro-0.2.3.18-validation.md) · [Language selector](macfanpro-0.2.3.19-validation.md) |
| 0.2.3.20–24 | [Control and calibration](macfanpro-0.2.3.20-validation.md) · [Calibration saving](macfanpro-0.2.3.21-validation.md) · [Recovery](macfanpro-0.2.3.22-validation.md) · [Audit](macfanpro-0.2.3.23-validation.md) · [Thermal protection](macfanpro-0.2.3.24-validation.md) |
| 0.2.3.23 hardware | [Thermal and sleep/wake acceptance](macfanpro-0.2.3.23-hardware-validation.md) · [Raw evidence](evidence/0.2.3.23/) |
| 0.2.3.25–28 | [Update checks](macfanpro-0.2.3.25-validation.md) · [Update row](macfanpro-0.2.3.26-validation.md) · [Button label](macfanpro-0.2.3.27-validation.md) · [Result state](macfanpro-0.2.3.28-validation.md) |
| 0.2.3.29–30 | [Languages](macfanpro-0.2.3.29-validation.md) · [Arabic](macfanpro-0.2.3.30-validation.md) |
| 0.2.3.31–35 | [Install-aware updates](macfanpro-0.2.3.31-validation.md) · [Terminal update](macfanpro-0.2.3.32-validation.md) · [Online installer](macfanpro-0.2.3.33-validation.md) · [Homebrew update](macfanpro-0.2.3.34-validation.md) · [Source commands](macfanpro-0.2.3.35-validation.md) |
| 0.2.3.50 | [DMG, upstream integration and website / DMG、上游合并与官网](macfanpro-0.2.3.50-validation.md) |
| 0.2.3.36–37 | [Icon](macfanpro-0.2.3.36-validation.md) · [Proxy and icon cleanup](macfanpro-0.2.3.37-validation.md) |
| 0.2.3.51–54 | [Update window and install recovery](macfanpro-0.2.3.52-validation.md) · [Foreground control and user data](macfanpro-0.2.3.53-validation.md) · [Fan release on daemon start and stop](macfanpro-0.2.3.55-validation.md) · [Readable service diagnostics and hardware checks](macfanpro-0.2.3.56-validation.md) · [Service row and setup window](macfanpro-0.2.3.57-validation.md) · [Settings window](macfanpro-0.2.3.58-validation.md) · [Panel footer](macfanpro-0.2.3.59-validation.md) |

Automated tests, package checks, installed-app checks and real hardware acceptance answer different questions. A passing build does not establish thermal or sleep/wake behavior on every Mac.

自动化测试、发行包检查、本机安装检查和实机验收分别对应不同证据；构建通过不能代表所有 Mac 的温控和睡眠唤醒都已验证。

`upstream/PLAN.md` and `upstream/ROADMAP.md` are historical upstream plans, not a list of implemented MacFanPro features.

`upstream/PLAN.md` 与 `upstream/ROADMAP.md` 保存上游早期规划，不是 MacFanPro 已实现功能清单。
