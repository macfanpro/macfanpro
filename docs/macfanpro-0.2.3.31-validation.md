# MacFanPro 0.2.3.31 验证记录

## 背景

用户在另一台 Mac（macOS 15，发行包安装）上照着应用“有可用更新”提示执行 `brew upgrade macfanpro && sudo macfanpro install`，Homebrew 报 “Refusing to load formula … from untrusted tap”。提示不区分安装方式，一律给出 Homebrew 命令，且缺少 Homebrew 7 要求的 `brew trust`。

## 修改范围

- `AppState.installedWithHomebrew`：以 Homebrew keg（`/opt/homebrew/opt/macfanpro` 或 `/usr/local/opt/macfanpro`）是否存在判断安装方式。
- `UpdateAvailableBanner`：
  - 发行包安装显示“下载新版本，然后在它的文件夹中运行：”与 `sudo ./bin/macfanpro install`，链接文字为“下载”（指向该版本发布页）；
  - Homebrew 安装显示 `brew trust macfanpro/tap && brew upgrade macfanpro && sudo macfanpro install`（`brew trust` 已信任时无副作用；`sudo macfanpro install` 由已安装的 CLI 从更新的 keg 同步，0.2.3.23 已实测）。
- 新增 2 条文案，18 种语言齐全（繁体由脚本生成）。
- 风扇控制未改变。

## 本机候选版

环境：M4 Max MacBook Pro（Mac16,5），macOS 27.0。

- Debug、Release 各 147 项测试通过，编译无警告，语言资源打包检查通过。
- 界面渲染测试新增 “update-brew” 场景：18 种语言分别渲染发行包与 Homebrew 两种提示，截图核对简体中文、英文、德文、阿拉伯文，命令完整显示、长文本正常换行、阿拉伯文正确镜像。

## 公开发行

- 发行源提交：`6ddd1ed`，标签 `v0.2.3.31`。[源码 CI](https://github.com/macfanpro/macfanpro/actions/runs/36610462956)、[发行 CI](https://github.com/macfanpro/macfanpro/actions/runs/36610465996) 通过。
- 下载草稿附件，`SHA256SUMS` 校验通过，与 GitHub asset digest 一致：`MacFanPro-0.2.3.31-macos-arm64.tar.gz` 为 `48ac2ec437b509bb24eea2df441aba7fb40f38ea8c04871b8e7df734a4cd667b`。CLI 版本为 0.2.3.31，严格代码签名校验通过。
- 安装下载产物后，二进制与发行包逐字节一致。
- 实机横幅：临时写入“最新版本 99.99.99”后重启应用，横幅显示“更新命令：”与 `brew trust macfanpro/tap && brew upgrade macfanpro && sudo macfanpro install`；临时改名 `/opt/homebrew/opt/macfanpro` 后重启，横幅改为“下载新版本，然后在它的文件夹中运行：”与 `sudo ./bin/macfanpro install`。测试后已恢复链接并删除测试用的偏好值。
- Homebrew：配方指向 v0.2.3.31，生成并上传 `arm64_sonoma` 预编译包（tap Release `macfanpro-0.2.3.31`），重新安装输出 “Pouring”，`brew test` 通过。同步后三者版本均为 0.2.3.31，与 Homebrew 版逐字节一致，无版本不一致提示，Smart 模式与“跟随系统”语言保留。
