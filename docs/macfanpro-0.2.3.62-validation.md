# MacFanPro 0.2.3.62 验证记录

## 范围

- 维护者要求：设置页的图标也按面板按钮处理；“移除后台服务…”不应带省略号。
- `IconLabel` 移到独立文件 `IconLabel.swift`，设置窗口的服务状态（运行中 ✓、需要处理 !）改用它。设置中的按钮按 macOS 设置窗口惯例不带图标。
- 按钮文案去掉末尾省略号：`Remove background service`、`View Update`、`Open download page`（更新窗口），18 种语言同步；表示进行中的提示（如“正在检查…”“正在打开终端…”）保留。README 中、英文同步。
- 设置窗口渲染测试增加“运行中”状态（显示移除按钮），与“需要安装”状态各渲染 18 种语言 × 明暗主题。

## 发布前检查

- 人工核对：简体中文浅色两种状态、法语深色“运行中”。
- `bash Scripts/test.sh --all-configurations`：Debug、Release 各 167 项测试、断连回归、17 项安装脚本测试通过。

## 远端 CI 与发行附件

- 源码 `4ad0dc4`，注释标签 `v0.2.3.62`。[主分支 CI](https://github.com/macfanpro/macfanpro/actions/runs/37654271549)、[发行 CI](https://github.com/macfanpro/macfanpro/actions/runs/37654271454) 通过。
- 下载全部 6 个草稿附件，三个校验文件通过：
  - tar `81e70d858ea5d104a9a240dbd1711181ca2e0f66960934b44673be18c9a32717`
  - DMG `25bb36dc1b73062e5d9c8b88db15346444f8d6e6cac2306b70295162da73bc13`
  - `install.sh` `4a9caa7209be749bb1e03b0ef9fa82d904e64262d720b50b99199b37227cf561`
- CLI 为 0.2.3.62，严格签名通过，最低 macOS 14；内嵌安装脚本与附件一致；DMG 与 tar 内应用逐文件一致。
- 公开发布后 tap 自动更新（[运行记录](https://github.com/macfanpro/homebrew-tap/actions/runs/37655010993)），提交 `3cefb17`。
- 按维护者要求，不更新本机应用。
