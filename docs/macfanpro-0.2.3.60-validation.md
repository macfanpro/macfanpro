# MacFanPro 0.2.3.60 验证记录

## 范围

- 维护者反馈：底部“退出”“设置”按钮中的图标与文字看起来不协调，问是否垂直居中。
- 原因：按钮内容是 `HStack { Image; Text }`，按两者的外框居中，图标沿用文字字号，竖长的退出图标显得偏大。
- 修改：新增 `FooterLabel`，图标使用 `imageScale(.small)`，与文字间距 4 点、按中线对齐。曾试过系统 `Label`，可以对齐，但图标与文字间距偏大，退出图标仍显得大，未采用。

- 维护者追加：设置窗口首次打开应在屏幕中央。原因：窗口按内容自动调整尺寸（`preferredContentSize`），但调用 `center()` 时还没有布局，居中的是初始小窗口，内容撑开后窗口偏向一侧。修改：居中前先布局，并把窗口设为内容尺寸。同一次运行中窗口对象保留，再次打开保持用户移动后的位置。
- 新增测试：打开设置窗口后，尺寸为内容尺寸（宽 ≥ 460 点），且在屏幕可见区域内水平居中。去掉修复后该测试失败，恢复后通过。
- 0.2.3.60 第一次打标签（`345972c`）后收到此反馈，取消 CI，删除未发布的标签（未生成草稿），合入后重新打标签。

## 发布前检查

- 渲染：放大 2 倍对比修改前、`Label` 方案与最终方案的底部一行（简体中文、英文，含更新蓝点），最终方案图标与文字同高、居中。
- `bash Scripts/test.sh --all-configurations`：Debug、Release 各 167 项测试、断连回归、17 项安装脚本测试通过。

## 远端 CI 与发行附件

- 源码 `b2aee92`，注释标签 `v0.2.3.60`。[主分支 CI](https://github.com/macfanpro/macfanpro/actions/runs/37650063558)、[发行 CI](https://github.com/macfanpro/macfanpro/actions/runs/37650063862) 通过，CI 中的窗口居中测试也通过。
- 下载全部 6 个草稿附件，三个校验文件通过：
  - tar `f70c81c457b09270e32984837cec748e0b596a1ac54fe00bd86347a91c065071`
  - DMG `681394db5d9d394d0d670787dbb4afab6065ba9a7d34941a5069fe8a2ede6c34`
  - `install.sh` `837972e5df7e14808f934f3ba40d30c32aa0a5a79d3ea4bdad949aa5be8e1a56`
- CLI 为 0.2.3.60，严格签名通过，最低 macOS 14；内嵌安装脚本与附件一致；DMG 与 tar 内应用逐文件一致。
- 公开发布后 tap 自动更新（[运行记录](https://github.com/macfanpro/homebrew-tap/actions/runs/37650674161)），提交 `3c9c9e9`。
- 按维护者要求，不更新本机应用。
