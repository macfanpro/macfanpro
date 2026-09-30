# 在线安装器

## 入口与发布

```bash
curl -fsSL https://github.com/macfanpro/macfanpro/releases/latest/download/install.sh | bash
```

此入口自 0.2.3.33 起可用；更早的版本没有 `install.sh` 附件。

`Scripts/install.sh` 是唯一实现。源码中的 `@MACFANPRO_VERSION@` 在 `build-app` 组装时替换为当前版本，脚本进入 App 签名范围。`package-release.sh` 从 App 中复制完全相同的脚本作为发行附件。图形界面的“在终端更新”复制包内脚本到用户私有临时目录，通过 Terminal 传入目标版本，完成或失败后清理临时文件。

下载脚本后，发行包和 SHA256SUMS 均从固定 `v版本` 下载地址获取，不再访问 latest，避免发布切换期间混用文件。

附件：

- `MacFanPro-<版本>-macos-arm64.tar.gz`
- `SHA256SUMS`：仅包含上述压缩包，兼容旧更新器。
- `install.sh`
- `install.sh.sha256`：仅包含脚本的 SHA256。

## 行为

1. 检查 macOS 14+、arm64 和普通登录用户；Rosetta shell、root shell 拒绝执行。
2. 优先使用已有代理环境变量，否则读取系统 HTTPS 代理。
3. 已安装 Homebrew formula 时继续通过 brew 更新，从 keg 安装；tap 落后于请求版本则报错，绝不悄悄切换到手工发行包。
4. 其他安装从 GitHub HTTPS 下载发行包和校验文件。检查唯一匹配的 SHA256、归档成员路径与类型；禁止越界路径、符号链接、硬链接和特殊文件。检查 App 身份、两个版本字段、严格代码签名以及 CLI 版本。
5. 拒绝覆盖更新的已安装版本；下载完成后再次检查。先取得 sudo 凭据，再恢复自动风扇控制并停止应用，调用既有 CLI install。
6. 新 CLI 安装器通过只读 `version` 请求确认真实守护进程版本；在线脚本再检查已安装 App/CLI 版本、签名、launchd 运行状态和 socket，最后打开 App。
7. 任何步骤失败返回非零状态；下载临时目录总会清理。验证、下载或密码失败发生在停止应用之前。安装开始后的失败不承诺事务回滚，会显示失败并保留诊断输出，可解决问题后重新运行。

配置与校准数据沿用既有安装行为，不清理用户数据、不自动迁移 ThermalForge。迁移必须显式传入 `--migrate-thermalforge`。

SHA256 检查下载完整性；脚本与校验文件来自同一 GitHub Release，不能证明仓库未被入侵。当前 App 为 ad-hoc 签名，严格验签检查包完整性，不等同于 Developer ID 签名或 Apple 公证。

## 参数

| 参数 | 含义 |
| --- | --- |
| `--version X.Y.Z.N` | 指定发行包版本；Homebrew 路径中为最低目标版本 |
| `--check` | 只下载并验证发行包，不触碰现有安装或风扇；即使有 Homebrew 也检查发行包 |
| `--no-open` | 安装成功后不打开 App |
| `--homebrew` | 要求存在 Homebrew 管理的安装；供 GUI 保持原安装渠道 |
| `--migrate-thermalforge` | 显式授权既有 CLI 的 ThermalForge 迁移流程 |

从源码运行必须传入 `--version`；发行附件已写入默认版本，不需用户指定。

## 验证

```bash
python3 Scripts/test-installer.py
bash Scripts/test.sh
bash Scripts/test.sh -c release
bash Scripts/check-localization-package.sh .build/release
bash Scripts/package-release.sh
```

Python 集成测试使用真实 bash、tar、SHA256 和 plist 解析，隔离替代网络、权限提升、Homebrew、签名检查及安装系统边界。覆盖首次安装/升级/重复运行、降级拒绝、代理、恶意归档、损坏校验、包身份和版本错误、权限拒绝、安装与服务失败、Homebrew 保持渠道、管道运行入口。Swift 测试实际执行终端启动脚本，用无副作用的假安装器验证参数引用、退出码传递和临时目录清理。

发行前另需验证真实打包产物的签名、版本、两个校验文件及脚本一致性。公开的旧版包可用下列命令做联网只读验证：

```bash
bash Scripts/install.sh --version 0.2.3.32 --check
```

首次发布新安装器时，下载草稿附件后核对校验文件；真实安装/升级验收在目标 Mac 上执行，记录 App、CLI、守护进程版本和运行状态。首次安装应在无既有安装的独立测试环境验收；不要卸载用户的运行实例来模拟。自动化隔离测试与 `--check` 不能替代实际特权安装或温控/睡眠唤醒硬件验收。
