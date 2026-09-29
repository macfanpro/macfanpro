# MacFanPro 0.2.3.24 验证记录

## 修改范围

- `Daemon.swift` 的 `releaseAfterFailedWrite`：高温保护期间，除主动“恢复自动”以外的指令失败时，重新设为满转速并保持保护；满转速也写不进去时，才沿用原有的交还自动控制并重试。分析见 [风扇状态与校准修复](fan-state-fixes-20260927.md) 最后一节。
- 测试夹具 `SimulatedSMC` 增加读取失败注入，新增 `failureDuringSuspension` 回归测试。
- 文档：0.2.3.23 实机验收记录中的第三方软件名改为通用描述。
- 智能模式曲线、95°C 触发与 90°C 解除阈值未改变。

## 本机候选版

环境：M4 Max MacBook Pro（Mac16,5），macOS 27.0。

- Debug、Release 各 146 项测试通过；各配置 108 次断连检查通过；编译无警告。
- 新测试在 0.2.3.23 的后台服务代码上失败（风扇被交还自动控制、保护被清除），在修复后通过。
- 该路径需要高温保护期间出现 SMC 读取失败，无法在实机安全地人为触发，由模拟 SMC 测试覆盖。

## 公开发行

- 发行源提交：`a399370`，标签 `v0.2.3.24`。[源码 CI](https://github.com/macfanpro/macfanpro/actions/runs/36521804842)、[发行 CI](https://github.com/macfanpro/macfanpro/actions/runs/36521806551) 通过。
- 下载草稿附件，`SHA256SUMS` 校验通过，与 GitHub asset digest 一致：`MacFanPro-0.2.3.24-macos-arm64.tar.gz` 为 `04c7b00b766b99bfd3eb62214d7b89aa93efe912d6e4f2918fb836539d717653`。CLI 版本为 0.2.3.24，严格代码签名校验通过。
- 以先退出应用、同步后台、再打开的步骤安装下载产物；已安装的后台服务 CLI 与应用二进制与发行包逐字节一致。
- Homebrew 从 0.2.3.23 升级到 0.2.3.24，`brew test` 通过；同步后后台服务 CLI、应用与 Homebrew 版逐字节一致，三者版本均为 0.2.3.24，无版本不一致提示，Smart 模式保留。
