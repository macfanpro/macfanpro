# MacFanPro 0.2.3.35 验证记录

## 修改范围

- `build-app` 新增 `--source-dir`，只有 `setup.sh` 传入当前源码目录，写入 Info.plist 的 `MacFanProSourceDirectory`（XML 转义）。发行包和 Homebrew 在临时目录构建，不写入。
- `UpdateScript.sourceCommand`：
  - 有源码目录时显示 `cd <目录> && git pull --ff-only && ./setup.sh`，目录含特殊字符时加单引号；
  - 没有时显示 `git clone https://github.com/macfanpro/macfanpro.git ~/macfanpro 2>/dev/null; cd ~/macfanpro && git pull --ff-only && ./setup.sh`。
- 更新提示“从源码构建？”下方显示上述完整命令；README 中、英文说明同步。
- 风扇控制未改变。

## 本机候选版

环境：M4 Max MacBook Pro（Mac16,5），macOS 27.0，经系统代理访问 GitHub。

- Swift 测试 150 项（新增：源码命令的完整路径、特殊字符引用、无目录时的克隆命令）、安装器集成测试 16 项、打包检查通过。
- `build-app` 实测：
  - 传入含 `&`、`<>`、单引号和空格的目录，生成的 Info.plist 通过 `plutil -lint`，读回的路径与原文一致；
  - 不传入时 Info.plist 无该键。
- 界面渲染：简体中文更新提示中完整命令自动换行，其余布局不变。

## 公开发行

待发行包验收后填写。
