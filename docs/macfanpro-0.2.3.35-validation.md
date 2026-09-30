# MacFanPro 0.2.3.35 验证记录

## 修改范围

- `build-app` 新增 `--source-dir`，只有 `setup.sh` 传入当前源码目录，写入 Info.plist 的 `MacFanProSourceDirectory`（XML 转义）。发行包和 Homebrew 在临时目录构建，不写入。
- `UpdateScript.sourceCommand`：
  - 有源码目录时显示 `cd <目录> && git pull --ff-only && ./setup.sh`，目录含特殊字符时加单引号；
  - 没有时显示 `git clone https://github.com/macfanpro/macfanpro.git ~/macfanpro 2>/dev/null; cd ~/macfanpro && git pull --ff-only && ./setup.sh`。
- 更新提示“从源码构建？”下方显示上述完整命令；README 中、英文说明同步。
- 更新提示分为“方式一（推荐）”和“方式二：从源码构建”。
  - 方式一按安装渠道显示 Homebrew 或发行包的命令和“在终端中更新”按钮，是普通用户最简单的方式。
  - 18 种语言新增 3 条文案，删除“Update with:”和“Built from source? Run:”两条；繁体中文由脚本生成。
  - 命令块固定从左到右显示，修正阿拉伯语中多行命令逐行右对齐的问题。
- 首次打标签后，发行 CI 在创建草稿时遇到 GitHub HTTP 502，留下一个没有附件的空草稿。删除空草稿并重跑时，又要求加入上述“方式一/方式二”的修改，于是取消重跑，删除未发布的 `v0.2.3.35` 标签，合入修改后重新打标签。
- 风扇控制未改变。

## 本机候选版

环境：M4 Max MacBook Pro（Mac16,5），macOS 27.0，经系统代理访问 GitHub。

- Swift 测试 150 项（新增：源码命令的完整路径、特殊字符引用、无目录时的克隆命令）、安装器集成测试 16 项、打包检查通过。
- `build-app` 实测：
  - 传入含 `&`、`<>`、单引号和空格的目录，生成的 Info.plist 通过 `plutil -lint`，读回的路径与原文一致；
  - 不传入时 Info.plist 无该键。
- 界面渲染：核对简体中文、俄文、阿拉伯文在 Homebrew 和发行包两种更新提示下的截图，两种方式的标题、命令换行和按钮显示正常；阿拉伯文中的命令从左到右显示。

## 公开发行

- 发行源提交：`a49ad07`，标签 `v0.2.3.35`。[源码 CI](https://github.com/macfanpro/macfanpro/actions/runs/36667988931)、[发行 CI](https://github.com/macfanpro/macfanpro/actions/runs/36667989067) 通过。
- 草稿附件 4 个，两个校验文件通过，与 GitHub asset digest 一致：
  - 发行包 `dc11552c4ec22290fd348a07d616cd4d55fd01342bcfca45e504e8861d8eece7`
  - `install.sh` `93a85a7c818315e7996e03228229a27ba5bea8c1ea586a043b7d4795343f86a8`
- CLI 为 0.2.3.35，严格签名通过，最低系统 macOS 14；`install.sh` 与 App 内脚本逐字节一致；发行包的 Info.plist 没有 `MacFanProSourceDirectory`。
- 公开发布后，release 事件自动启动 tap 更新（[运行记录](https://github.com/macfanpro/homebrew-tap/actions/runs/36668371693)），配方与预编译包提交为 `e11a6de`。
- **从 0.2.3.34 点“在终端中更新”升级（首次实跑 0.2.3.34 的无确认 Homebrew 路径）**：
  - 版本检测显示 0.2.3.35，按下按钮；
  - 进程检查显示 Homebrew 已升级到 0.2.3.35（预编译包安装），脚本停在 `sudo -v` 等待密码，此前无人操作，说明升级没有停在 y/n 确认；
  - 本机 tap 已是 `e11a6de`；
  - 输入密码后完成：后台服务 pid 47411，二进制与 keg 一致；`/Applications` 应用与 keg 一致，严格签名通过；无版本不一致；私有临时目录已清理；Smart 模式保留；
  - 终端输出未留存，“只刷新本 tap、不再显示全量 `brew update` 输出”只经集成测试与上述状态间接确认。
