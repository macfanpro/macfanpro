# MacFanControl 改名与旧版升级

MacFanControl 原名 MacFanPro。0.2.3.64 起，新版应用文件为 **MacFanControl.app**，命令为 **macfancontrol**，安装包和源码模块也采用新名称。

## 老用户怎么升级

- **Homebrew 用户**：继续点击旧版应用的更新按钮。Homebrew 将旧配方迁移到新配方，旧命令兼容别名负责完成已有更新脚本；安装完成后打开的是 MacFanControl。
- **在线安装用户**：继续运行原有安装命令。旧版安装器能下载旧名称兼容包，其中安装程序会安装真正的 `MacFanControl.app`。
- **DMG 用户**：使用应用原有的下载入口，退出旧应用，把新版 `MacFanControl.app` 拖入“应用程序”并打开，按提示同步服务。原 MacFanPro 应用会被隐藏兼容链接替换，无需手动卸载后台服务。
- **源码用户**：拉取最新代码，运行 `./setup.sh`。

语言、选定模式、校准、日志与登录启动使用原有身份和数据，不会因展示名称或文件名改变而重置。更新需要的管理员授权与原先一样。

## Homebrew 配套名称

正式 Tap 为 [`macfancontrol/homebrew-tap`](https://github.com/macfancontrol/homebrew-tap)，安装使用 `brew tap macfancontrol/tap`、`brew trust macfancontrol/tap` 和 `brew install macfancontrol`。

原 `macfanpro/homebrew-tap` 仓库地址由 GitHub 重定向至新仓库，已有 `macfanpro/tap` 用户无需先卸载或重新安装。旧配方名 `macfanpro` 和旧命令保留兼容别名。更新器兼容新旧 Tap；两者同时存在时都会刷新。历史 bottle 下载地址继续通过重定向工作。

## 兼容范围

新版所有正常使用入口均为 MacFanControl。以下旧名只用于已安装版本的兼容，不是第二套产品：

| 兼容项 | 原因 |
| --- | --- |
| `MacFanPro-<版本>-macos-arm64.tar.gz` 与旧 `SHA256SUMS` | 已安装脚本写死了下载名和目录；新版主包有独立校验文件 |
| 隐藏的 `/Applications/MacFanPro.app` 链接 | 旧脚本安装完成后会验证并打开此路径；指向真正的 MacFanControl.app |
| `macfanpro` 命令和 Homebrew 旧配方别名 | 旧更新脚本继续调用旧命令 |
| Bundle ID、服务标签、套接字及原用户数据目录 | 保持旧客户端、偏好和登录项的连续身份，避免同时运行两套风扇服务 |

历史发行说明、标签和上游贡献记录按当时名称保留，不改写历史事实。

## 仓库与旧版兼容入口

主仓库为 https://github.com/macfancontrol/macfancontrol ，官网为 https://macfancontrol.github.io/macfancontrol/ 。Gitee https://gitee.com/macfancontrol/macfancontrol 仅接收主仓库镜像。

旧仓库 https://github.com/macfanpro/macfanpro 作为兼容仓库长期保留。旧更新器要求最终 URL 仍属于旧仓库，所以兼容仓库复制已发布版本及附件，并验证 SHA256 后发布；不能把旧更新入口简单重定向到新仓库。每 15 分钟检查一次新版本，GitHub 调度可能延迟；发布维护者应主动触发同步并确认成功。失败可从 Actions 重试，旧的有效版本仍可下载。

旧官网保留跳转，并传递语言路径、查询参数和页面锚点。旧仓库地址已由兼容仓库占用，GitHub 的自动仓库重定向不再适用。已有源码克隆需要更新远程地址：

```bash
git remote set-url origin https://github.com/macfancontrol/macfancontrol.git
git pull --ff-only
```

正常安装用户继续使用应用原来的更新入口。历史版本中的旧命令、包名和运行身份仍需保留。不要删除兼容仓库、旧网站或旧名发行附件。

## English

GitHub is authoritative at `macfancontrol/macfancontrol`. The old `macfanpro/macfanpro` repository retains verified release copies for legacy update clients. It is a compatibility endpoint, not a development fork. The old Pages site redirects with language and fragment preserved. Source checkouts must update their origin URL. Compatibility sync runs every 15 minutes (subject to GitHub scheduling delays); maintainers should trigger and verify it after publication.
