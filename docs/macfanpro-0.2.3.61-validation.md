# MacFanPro 0.2.3.61 验证记录

## 范围

- 维护者要求“智能”“默认”按钮也按 0.2.3.60 底部按钮的方式处理图标。
- `MenuBarView`：两按钮由系统 `Label` 改为共用的 `IconLabel`（原 `FooterLabel` 改名）：图标 `imageScale(.small)`、与文字同高居中、间距 4 点。四个按钮样式统一。

## 发布前检查

- 渲染：放大 2 倍对比修改前后的“智能/默认”与底部一行（简体中文、德语），图标大小与间距一致。
- `bash Scripts/test.sh --all-configurations`：Debug、Release 各 167 项测试、断连回归、17 项安装脚本测试通过。

## 远端 CI 与发行附件

- 源码 `9b99e8a`，注释标签 `v0.2.3.61`。[主分支 CI](https://github.com/macfanpro/macfanpro/actions/runs/37652097613)、[发行 CI](https://github.com/macfanpro/macfanpro/actions/runs/37652097726) 通过。
- 下载全部 6 个草稿附件，三个校验文件通过：
  - tar `9e22613873696d11f46d493f0dee018f681f13cedfdfd7934f8c8356b37b8266`
  - DMG `613ff5e0c125121509ede8e03e6edf2333bcd55d202993049a9f6e1e906d5399`
  - `install.sh` `f80bac752476f112181a5823dfbd48dfd95822a3437622ab527272fe95de762e`
- CLI 为 0.2.3.61，严格签名通过，最低 macOS 14；内嵌安装脚本与附件一致；DMG 与 tar 内应用逐文件一致。
- 公开发布后 tap 自动更新（[运行记录](https://github.com/macfanpro/homebrew-tap/actions/runs/37652852349)），提交 `30f1d92`。
- 按维护者要求，不更新本机应用。
