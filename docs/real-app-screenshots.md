# 真机应用截图 / Real app screenshots

2026-10-14 已在本机安装的 MacFanPro 0.2.3.66 上验证。中英文菜单原图均为 520 × 766 像素；后续版本以实际尺寸为准。

## 原则

- 仓库和官网的应用截图使用实际运行窗口，保留系统背景、圆角、字体与控件状态，不用离屏渲染替代真机图，不修改温度、转速或选中模式。
- 仅展开菜单、临时切换界面语言；不退出应用，不运行 `auto --stop-app`，不重启服务、不改变风扇模式。截图不能作为温控性能测试证据。
- 操作前记录版本、原语言；截图后恢复原语言。不要为了抓图自动修改系统权限；缺少辅助功能或屏幕录制权限时由用户授权。
- 本次普通 AppleScript `click` / `AXPress` 未能打开 SwiftUI 菜单；以下方法通过 AX 获取图标位置，再用 CGEvent 发送鼠标点击。

## 1. 准备临时工具

需要 Swift 编译器，MacFanPro 已运行。关闭 MacFanPro 的设置及其他普通窗口，只保留菜单栏应用；下面的窗口定位器选择该进程最高的可见窗口，其他窗口会干扰判断。

```bash
shot_dir=$(mktemp -d /tmp/macfanpro-shots.XXXXXX)
```

将以下两段分别保存到 `$shot_dir/toggle.swift` 和 `$shot_dir/winid.swift`。

### toggle.swift：展开或收起菜单

```swift
// Click MacFanPro's menu bar item once (opens the panel, or closes it if open).
import AppKit
import ApplicationServices
guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "io.github.macfanpro.app").first else { exit(1) }
let ax = AXUIElementCreateApplication(app.processIdentifier)
func attr(_ e: AXUIElement, _ a: String) -> AnyObject? { var v: AnyObject?; AXUIElementCopyAttributeValue(e, a as CFString, &v); return v }
guard let bar = attr(ax, "AXExtrasMenuBar"), let item = (attr(bar as! AXUIElement, kAXChildrenAttribute) as? [AXUIElement])?.first else { exit(1) }
var p = CGPoint.zero, s = CGSize.zero
AXValueGetValue(attr(item, kAXPositionAttribute) as! AXValue, .cgPoint, &p)
AXValueGetValue(attr(item, kAXSizeAttribute) as! AXValue, .cgSize, &s)
let c = CGPoint(x: p.x + s.width / 2, y: p.y + s.height / 2)
for t in [CGEventType.leftMouseDown, .leftMouseUp] {
    CGEvent(mouseEventSource: nil, mouseType: t, mouseCursorPosition: c, mouseButton: .left)?.post(tap: .cghidEventTap)
}
```

### winid.swift：取得可见菜单窗口 ID

```swift
// Print the window number of MacFanPro's open menu panel (its tallest window).
import AppKit
guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "io.github.macfanpro.app").first,
      let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { exit(1) }
let mine = list.filter { ($0[kCGWindowOwnerPID as String] as? pid_t) == app.processIdentifier }
let panel = mine.max { a, b in
    let ha = (a[kCGWindowBounds as String] as? [String: CGFloat])?["Height"] ?? 0
    let hb = (b[kCGWindowBounds as String] as? [String: CGFloat])?["Height"] ?? 0
    return ha < hb
}
guard let panel, let number = panel[kCGWindowNumber as String] as? Int,
      let bounds = panel[kCGWindowBounds as String] as? [String: CGFloat], (bounds["Height"] ?? 0) > 200 else { print("no panel"); exit(1) }
print(number)
```

```bash
swiftc -O "$shot_dir/toggle.swift" -o "$shot_dir/toggle"
swiftc -O "$shot_dir/winid.swift" -o "$shot_dir/winid"
```

## 2. 抓取真实窗口

菜单关闭时执行一次 toggle；它是切换操作，重复执行会把已展开的菜单关闭。

```bash
"$shot_dir/toggle"
sleep 1
if panel_id=$("$shot_dir/winid"); then
  screencapture -o -x -l "$panel_id" "$shot_dir/menu-bar-zh-CN.png"
fi
```

`-l` 按窗口截取，`-o` 不带窗口阴影，`-x` 静音。截图保留窗口的透明圆角，不需要截整个桌面或手工抠图。

若出现 `no panel` / `could not create image from window`，检查菜单是否因焦点变化关闭。重新展开后重新获取窗口 ID，再截图；不要复用旧 ID，不要用渲染图冒充成功结果。

## 3. 中英文与语言恢复

1. 先记录“设置 → 语言”的当前选项，本次为“跟随系统”。
2. 抓取中文菜单后，进入设置将语言改为 English。
3. 关闭设置窗口，展开菜单，按上面的方式保存 `menu-bar-en.png`。
4. 返回设置，恢复原语言并关闭设置窗口。语言可在运行中切换，不需要退出或重启应用。
5. 查看两张原图，确认菜单完整、无其他窗口、文字清晰、版本正确。不同时间的温度、转速和状态可以不同，不要人为改成一致。

## 4. 替换与发布验证

确认原图后再复制：

```bash
cp "$shot_dir/menu-bar-en.png" docs/images/menu-bar-en.png
cp "$shot_dir/menu-bar-zh-CN.png" docs/images/menu-bar-zh-CN.png
swift Scripts/generate-social-preview.swift docs/images/icon.png docs/images/menu-bar-en.png docs/images/social-preview.png en
swift Scripts/generate-social-preview.swift docs/images/icon.png docs/images/menu-bar-zh-CN.png docs/images/social-preview-zh-CN.png
sips -g pixelWidth -g pixelHeight docs/images/menu-bar-*.png
python3 Scripts/build-website.py
git diff --check
```

- 同步 README 中英文图注、`website/locales/` 全部 18 个语言图注、`website/template.html` 图片宽高。
- 检查社交预览图，避免缩放后遮挡、裁切或文字不可读。
- 按仓库贡献要求完成检查，获得推送授权后推送主分支。
- 等待 Website 部署成功，再下载官网 `assets/` 下四张图片，对比 SHA-256 与本地文件，确认线上已替换；核对 Gitee 镜像结果。
- 全屏诊断截图可能包含私人内容，不要提交；只提交应用窗口及对应宣传图。

本次结果见 [0.2.3.66 验证记录](macfanpro-0.2.3.66-validation.md#发布后截图更正2026-10-14)。
