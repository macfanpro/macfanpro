<!-- 复制为 docs/releases/版本号.md。英文在前、中文在后，两部分内容一致。替换所有占位符，删除无内容的分类；验证完成前保留草稿状态。 -->

What this release fixes or adds, and the result. Based on ThermalForge (upstream base version).

## What's changed

### New

- New capabilities in this release; link PRs or commits where useful.

### Fixed

- The trigger and the behavior after the fix.

### Improved

- Real changes to install, interface, docs or maintenance.

## Download and install

Requires **an Apple Silicon Mac with macOS 14 or later**. Check the system requirements and signing details for every release.

| File | Purpose |
| --- | --- |
| [MacFanPro-VERSION-macos-arm64.tar.gz](https://github.com/macfanpro/macfanpro/releases/download/vVERSION/MacFanPro-VERSION-macos-arm64.tar.gz) | Complete app and CLI; extract and install, no Xcode needed |
| [SHA256SUMS](https://github.com/macfanpro/macfanpro/releases/download/vVERSION/SHA256SUMS) | Download integrity check |

Choose one install method: [Homebrew](https://github.com/macfanpro/macfanpro#option-1-homebrew) · [Release download](https://github.com/macfanpro/macfanpro#option-2-release-download) · [From source](https://github.com/macfanpro/macfanpro#option-3-from-source). Homebrew 7 needs `brew trust macfanpro/tap` once.

## Upgrading

What users need to do for this release. Quit the menu bar app before updating; after a Homebrew update, sync the background service and the app too. See [Updating](https://github.com/macfanpro/macfanpro#updating).

## Verification and limits

- Automated: the actual configurations, results and CI links; say so when not run.
- On hardware: the actual model, macOS, install channel and what was covered; say what wasn't.
- Signing and notarization: the real state of this package.
- Validation record (in Chinese): a link to this version's existing record.

**Full changelog:** [vPREVIOUS…vVERSION](https://github.com/macfanpro/macfanpro/compare/vPREVIOUS...vVERSION)

---

## 中文说明

本次更新：填写具体问题与结果。基于 ThermalForge 上游基础版本。

### 更新内容

- **新增 / 修复 / 改进**：与英文部分一一对应，删除没有内容的分类。

### 下载与安装

要求 **Apple Silicon Mac、macOS 14 或更高版本**。下载文件见上方表格。

选择一种安装方式：[Homebrew](https://github.com/macfanpro/macfanpro/blob/main/README.zh-CN.md#方式一通过-homebrew-安装) · [下载发行包](https://github.com/macfanpro/macfanpro/blob/main/README.zh-CN.md#方式二下载发行包安装) · [源码构建](https://github.com/macfanpro/macfanpro/blob/main/README.zh-CN.md#方式三从源码构建安装)。Homebrew 7 需要先执行一次 `brew trust macfanpro/tap`。

### 升级说明

填写本版本需要用户采取的动作。更新前先退出应用；Homebrew 更新后还需同步后台服务和应用，详见 [更新步骤](https://github.com/macfanpro/macfanpro/blob/main/README.zh-CN.md#更新)。

### 验证与限制

- 自动化验证、本机验证、签名与公证、验证记录：与英文部分一致。
