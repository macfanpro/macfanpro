# MacFanPro 0.2.3.61 验证记录

## 范围

- 维护者要求“智能”“默认”按钮也按 0.2.3.60 底部按钮的方式处理图标。
- `MenuBarView`：两按钮由系统 `Label` 改为共用的 `IconLabel`（原 `FooterLabel` 改名）：图标 `imageScale(.small)`、与文字同高居中、间距 4 点。四个按钮样式统一。

## 发布前检查

- 渲染：放大 2 倍对比修改前后的“智能/默认”与底部一行（简体中文、德语），图标大小与间距一致。
- `bash Scripts/test.sh --all-configurations`：Debug、Release 各 167 项测试、断连回归、17 项安装脚本测试通过。

## 远端 CI 与发行附件

待填写。
