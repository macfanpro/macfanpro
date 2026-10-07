# MacFanPro 0.2.3.57 验证记录

## 范围

- 维护者反馈：菜单底部“退出”旁的 caption 小字“后台服务…”与面板不协调；设置窗口内的语言选择与菜单重复。
- `MenuBarView`：后台服务入口改为“更新”下方的标签行，按钮“管理…”，样式与“检查更新”一致；底部只保留“退出”。
- `ServiceSetupView`：移除语言选择器，加载指示移到底部按钮行。
- 文案：`Background service…` 替换为 `Background service`（行标签）与 `Manage…`（按钮），18 种语言齐全；中文标签按维护者要求改为两个字“服务”（繁体“服務”，由脚本生成）。

## 发布前检查

- `bash Scripts/test.sh --all-configurations`：Debug、Release 各 166 项测试 / 31 个套件、断连回归、17 项安装脚本测试通过。
- 渲染：面板与设置窗口的全部语言及明暗主题截图测试通过；人工核对简体、繁体、法语（较长文案）、阿拉伯语（从右到左）的面板，以及简体中文的设置窗口。

## 远端 CI、发行附件与本机安装

- 第一次以 `e055393` 打标签时，CI 在设置窗口渲染测试失败：去掉语言选择那一行后窗口约 351 点高，CI 的字体渲染略低于测试下限 350。窗口本身正常，下限只用于确认已渲染出内容，改为 300（`255c702`）。当时未生成草稿；删除未发布的标签后在 `255c702` 重新打 `v0.2.3.57`。
- [主分支 CI](https://github.com/macfanpro/macfanpro/actions/runs/37632853982)、[发行 CI](https://github.com/macfanpro/macfanpro/actions/runs/37632853968) 通过。
- 下载全部 6 个草稿附件，三个校验文件通过：
  - tar `d9574478b170f759a243aabf9406fc38e0d9fdd45caaabde1196f4d024b6e8bf`
  - DMG `228f1b3d2e880fc3761f2f782ea48207be4e8752fe9a4a8206a2dc9221734f59`
  - `install.sh` `7f4523fbf4826773284dd54c5fcde47900182deb09b9cd1142845ee165690a13`
- CLI 为 0.2.3.57，严格签名通过，最低 macOS 14；内嵌安装脚本与附件一致；DMG 与 tar 内应用逐文件一致；包内简体中文资源为“服务”“管理…”。
- 公开发布后 tap 自动更新（[运行记录](https://github.com/macfanpro/homebrew-tap/actions/runs/37633677943)），提交 `61ad09d`。
- 本机用 `install.sh --version 0.2.3.57` 从 0.2.3.56 升级（Homebrew）：安装前释放风扇，最后确认服务运行；CLI 与 keg 一致，严格签名通过，Smart 模式保留。
