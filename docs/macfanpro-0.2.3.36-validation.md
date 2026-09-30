# MacFanPro 0.2.3.36 验证记录

## 修改范围

- `Scripts/generate-icon.swift`：
  - 底板改为深海军蓝渐变；64 px 及以上加细青色边框，16–32 px 不画边框；
  - `fan.fill` 用青→蓝→紫渐变填充，加青色光晕；
  - 用它重新生成 `MacFanPro.icns` 与 `docs/images/icon.png`。
- `docs/images/social-preview.png`（英文）与 `social-preview-zh-CN.png`（中文）使用同一套科技配色、新图标和布局。
- 按维护者要求，菜单栏状态颜色与面板强调色不变；风扇控制未改变。

## 本机候选版

环境：M4 Max MacBook Pro（Mac16,5），macOS 27.0。

- 核对图标在 512、256、64、32、16 px 下的渲染：小尺寸无边框，风扇轮廓清晰。
- 发行包、Homebrew 和 `setup.sh` 都使用仓库中的 `MacFanPro.icns`，无需修改构建脚本。

## 公开发行

待发行包验收后填写。
