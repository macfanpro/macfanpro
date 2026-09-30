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

待发行包验收后填写。
