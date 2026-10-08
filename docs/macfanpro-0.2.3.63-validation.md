# MacFanPro 0.2.3.63 验证记录

## 范围

- 维护者要求：更新窗口的内容并入设置窗口，只保留一个窗口；“更新”分组移到最下方；Homebrew 更新说明“可能需要管理员授权”改为“需要管理员授权”。
- 移除 `UpdateDetailsWindow` 与独立更新窗口；`UpdateDetailsView.swift` 改名为 `UpdateSection.swift`，保留 `UpdateDetailsModel`（打开发布页、终端交接与防重复启动逻辑不变），新增 `UpdateSection` / `AvailableUpdateRows` 作为设置窗口“更新”分组的内容。
- 设置窗口分组顺序：通用 → 服务 → 更新。有新版本时显示：版本、新版本（更新内容链接 + 版本号）、更新方式说明与主按钮、折叠的“其他更新方式”“下载遇到问题？”。终端交接状态在关闭设置窗口后重置。
- 面板“有新版本”一行改为打开设置窗口（并照常复查服务状态）。
- 设置窗口高度上限为屏幕可用高度减 120 pt（至少 420 pt），超出时在窗口内滚动。
- 本地化：新增 `New version`；`Opens Terminal to update. Administrator authorization may be required.` 改为 `… is required.`；删除不再使用的 `MacFanPro update`、`Current version: {version}`、`Close`。18 种语言同步，`zh-Hant` 由脚本生成。
- README、`docs/update-check-plan.md`、`docs/gui-localization.md` 同步。

## 发布前检查

- 新测试替换原更新窗口测试：设置窗口在有更新时渲染两种安装方式 × 明暗主题 × 18 种语言（宽 460，高 400–760）；高度上限生效（`maxHeight: 360` 时窗口高 360）；关闭再打开设置窗口沿用同一窗口、更新提示保留、手动检查结果复位。
- 人工核对渲染图：简体中文浅色 Homebrew、英文深色 DMG、德语浅色 Homebrew、阿拉伯语浅色 DMG（从右到左）。
- `bash Scripts/test.sh --all-configurations`：Debug、Release 各 168 项测试（原两项更新窗口测试换为三项设置窗口测试）、断连回归、17 项安装脚本测试通过；`check-localization-package.sh` 通过。
- 未在本机真机运行：按维护者要求，本机应用不更新。

## 远端 CI 与发行附件

待填写。
