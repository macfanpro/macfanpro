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

待填写。
