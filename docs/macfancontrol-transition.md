# MacFanControl 改名与旧版升级

MacFanControl 原名 MacFanPro。0.2.3.64 起，新版应用文件为 **MacFanControl.app**，命令为 **macfancontrol**，安装包和源码模块也采用新名称。

## 老用户怎么升级

- **Homebrew 用户**：继续点击旧版应用的更新按钮。Homebrew 将旧配方迁移到新配方，旧命令兼容别名负责完成已有更新脚本；安装完成后打开的是 MacFanControl。
- **在线安装用户**：继续运行原有安装命令。旧版安装器能下载旧名称兼容包，其中安装程序会安装真正的 `MacFanControl.app`。
- **DMG 用户**：使用应用原有的下载入口，退出旧应用，把新版 `MacFanControl.app` 拖入“应用程序”并打开，按提示同步服务。原 MacFanPro 应用会被隐藏兼容链接替换，无需手动卸载后台服务。
- **源码用户**：拉取最新代码，运行 `./setup.sh`。

语言、选定模式、校准、日志与登录启动使用原有身份和数据，不会因展示名称或文件名改变而重置。更新需要的管理员授权与原先一样。

## 兼容范围

新版所有正常使用入口均为 MacFanControl。以下旧名只用于已安装版本的兼容，不是第二套产品：

| 兼容项 | 原因 |
| --- | --- |
| `MacFanPro-<版本>-macos-arm64.tar.gz` 与旧 `SHA256SUMS` | 已安装脚本写死了下载名和目录；新版主包有独立校验文件 |
| 隐藏的 `/Applications/MacFanPro.app` 链接 | 旧脚本安装完成后会验证并打开此路径；指向真正的 MacFanControl.app |
| `macfanpro` 命令和 Homebrew 旧配方别名 | 旧更新脚本继续调用旧命令 |
| Bundle ID、服务标签、套接字及原用户数据目录 | 保持旧客户端、偏好和登录项的连续身份，避免同时运行两套风扇服务 |

历史发行说明、标签和上游贡献记录按当时名称保留，不改写历史事实。

## 仓库迁移分两步

当前 GitHub 主仓库仍是 https://github.com/macfanpro/macfanpro ，官网仍是 https://macfanpro.github.io/macfanpro/ 。Gitee https://gitee.com/macfanpro/macfanpro 只接收来自 GitHub 的镜像。

旧版更新器拒绝跳转到新仓库后的最终 URL，无法通过服务端重定向修补。所以先发布本过渡版，让用户正常收到更新。本版识别旧仓库与未来的 `macfancontrol/macfancontrol`，之后另行迁移仓库并处理旧官网跳转。未升级过渡版的历史版本届时可能需要手动下载；不能承诺所有历史版本在迁移后仍能发现更新。

## English

MacFanControl was formerly MacFanPro. New app files, CLI, packages and source modules use the new name. Existing users keep their usual update entry point. Homebrew formula renaming, an old-command alias, a legacy archive and a hidden old-app link support already-installed updater scripts. Stable runtime and preference identifiers preserve settings and login items; no second fan-control service is introduced.

The GitHub repository has not moved. This release accepts both old and future repository URLs so a later move can preserve update discovery for users who install it. GitHub remains authoritative; Gitee is a one-way mirror. Users who skip this transition may need a manual download after the later move.
