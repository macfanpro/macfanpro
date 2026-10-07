# MacFanPro 0.2.3.59 验证记录

## 范围

- 维护者反馈：“退出”也做成按钮样式；退出与设置这一行上方太紧凑；设置按钮不应带“…”；电源图标不符合“退出”的意思。
- `MenuBarView` 底部：“退出”为默认按钮样式，图标 `rectangle.portrait.and.arrow.right`（离开/退出），快捷键 ⌘Q；该行上方增加 4 点，上下分别为 8 点和 10 点。
- 文案键 `Settings…` 改为 `Settings`，18 种语言去掉末尾省略号；README 中、英文同步。

## 发布前检查

- `bash Scripts/test.sh --all-configurations`：Debug、Release 各 166 项测试 / 31 个套件、断连回归、17 项安装脚本测试通过。
- 渲染：面板 7 种场景 × 18 种语言通过；人工核对简体中文、德语（文字最长）、阿拉伯语（从右到左）及带更新提示与终端接管提示的面板。

## 远端 CI 与发行附件

- 源码 `015ea96`，注释标签 `v0.2.3.59`。[主分支 CI](https://github.com/macfanpro/macfanpro/actions/runs/37644928673)、[发行 CI](https://github.com/macfanpro/macfanpro/actions/runs/37644929024) 通过。
- 下载全部 6 个草稿附件，三个校验文件通过：
  - tar `194b51446ab5a48daf1439b107e2dc05f3662757fe9189088ac97c45ce55ebb6`
  - DMG `3829eda31579d1682c58f3942a2401610194c8123bc804b2c8eb44c726a5c2cb`
  - `install.sh` `4e2f4b0e7adff3d5ee7b0b34ab97adc0f9d7b30331d4f3737ad32ffa727d9ef0`
- CLI 为 0.2.3.59，严格签名通过，最低 macOS 14；内嵌安装脚本与附件一致；DMG 与 tar 内应用逐文件一致；包内简体中文为“设置”，已无 `Settings…` 键。
- 公开发布后 tap 自动更新（[运行记录](https://github.com/macfanpro/homebrew-tap/actions/runs/37645816093)），提交 `0ecc7a4`。
- 按维护者要求，本版不更新本机应用；本机仍为 0.2.3.58。
