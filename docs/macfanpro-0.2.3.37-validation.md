# MacFanPro 0.2.3.37 验证记录

## 范围

- 自 0.2.3.36 起的变更：代理安装与更新提示、移除图标的柔光效果。
- 风扇控制、温控曲线和保护阈值没有在本次修改。
- 用户自行更新本机应用；本次不把本机安装状态或实机温控测试算作发行验收结果。

## 源码与图标

- 图标变更 PR #2 的 macOS CI 已通过 Debug、Release、安装器集成测试和资源检查：<https://github.com/macfanpro/macfanpro/actions/runs/36754973065>。
- 目视检查去光晕后的 512×512 图标与 1280×640 中文社交预览图；`iconutil` 成功生成 `MacFanPro.icns`，`file` 与 `sips` 确认资源格式和尺寸。
- GitHub 组织头像已换为项目图标，仓库社交预览图已更新；GitHub 提示头像在站内完全刷新可能需要几分钟。

## 本机发行包预检查

在独立源码工作树中以 `RELEASE_TAG=v0.2.3.37 bash Scripts/package-release.sh` 构建，不安装应用或后台服务。

- Release 构建与打包成功；`Scripts/check-localization-package.sh .build/release` 通过。
- 本机生成的压缩包与 `install.sh` 均通过各自 SHA-256 校验文件。
- 解包后，App 内 `AppIcon.icns` 与仓库图标逐字节一致；App 内 `install.sh` 与发行目录中的脚本逐字节一致。
- `codesign --verify --deep --strict` 通过；App 与 CLI 均报告 0.2.3.37。

## 限制

- 上述检查不代表已下载并验收 GitHub 发行草稿附件；草稿附件需单独核对。
- 未更新本机 `/Applications/MacFanPro.app` 或后台服务，未运行负载、温控及睡眠唤醒实机测试，也未验证真实代理服务的连通性。
- 发行包使用 ad-hoc 签名，未经 Apple 公证。
