<!-- 复制为 docs/releases/版本号.md。英文在前、中文在后，两部分内容一致。替换所有占位符，删除无内容的分类；验证完成前保留草稿状态。 -->

[English](#english) · [简体中文](#chinese) · **[直接下载 MacFanPro（DMG）](https://github.com/macfanpro/macfanpro/releases/download/vVERSION/MacFanPro-VERSION-macos-arm64.dmg)**

<a name="english"></a>

What this release fixes or adds, and the result. Based on ThermalForge (upstream base version).

## What's changed

### New

- New capabilities in this release; link PRs or commits where useful.

### Fixed

- The trigger and the behavior after the fix.

### Improved

- Real changes to install, interface, docs or maintenance.

## Download and install

**[Download MacFanPro VERSION (DMG, recommended)](https://github.com/macfanpro/macfanpro/releases/download/vVERSION/MacFanPro-VERSION-macos-arm64.dmg)**

Requires **an Apple Silicon Mac with physical fans and macOS 14 or later**. Open the DMG, drag `MacFanPro.app` into Applications, open it and authorize background-service setup when prompted. Check the system requirements and signing details for every release.

<details>
<summary>Other installation methods and checksums</summary>

| File | Purpose |
| --- | --- |
| [DMG SHA-256](https://github.com/macfanpro/macfanpro/releases/download/vVERSION/MacFanPro-VERSION-macos-arm64.dmg.sha256) | Optional DMG integrity check, not an installer |
| [MacFanPro-VERSION-macos-arm64.tar.gz](https://github.com/macfanpro/macfanpro/releases/download/vVERSION/MacFanPro-VERSION-macos-arm64.tar.gz) | Complete app and CLI; extract and install, no Xcode needed |
| [install.sh](https://github.com/macfanpro/macfanpro/releases/download/vVERSION/install.sh) | One-command installer |
| [install.sh.sha256](https://github.com/macfanpro/macfanpro/releases/download/vVERSION/install.sh.sha256) | Installer integrity check |
| [SHA256SUMS](https://github.com/macfanpro/macfanpro/releases/download/vVERSION/SHA256SUMS) | Download integrity check |

Choose one install method: [Homebrew](https://github.com/macfanpro/macfanpro#option-1-homebrew) · [Release download](https://github.com/macfanpro/macfanpro#option-2-release-download) · [From source](https://github.com/macfanpro/macfanpro#option-3-from-source). Homebrew 7 needs `brew trust macfanpro/tap` once.

GitHub's **Source code (zip / tar.gz)** attachments are source code for developers, not ready-to-install applications. For connection problems and proxy instructions, see the [online installer guide](https://github.com/macfanpro/macfanpro#online-installer).

</details>

## Upgrading

What users need to do for this release. Quit the menu bar app before updating; after a Homebrew update, sync the background service and the app too. See [Updating](https://github.com/macfanpro/macfanpro#updating).

## Verification and limits

- Automated: the actual configurations, results and CI links; say so when not run.
- On hardware: the actual model, macOS, install channel and what was covered; say what wasn't.
- Signing and notarization: the real state of this package.
- Validation record (in Chinese): a link to this version's existing record.

**Full changelog:** [vPREVIOUS…vVERSION](https://github.com/macfanpro/macfanpro/compare/vPREVIOUS...vVERSION)

---

<a name="chinese"></a>

## 中文说明

本次更新：填写具体问题与结果。基于 ThermalForge 上游基础版本。

### 下载与安装

**[⬇ 下载 MacFanPro VERSION（DMG 安装包，推荐）](https://github.com/macfanpro/macfanpro/releases/download/vVERSION/MacFanPro-VERSION-macos-arm64.dmg)**

适用于 **配备实体风扇的 Apple Silicon Mac（M 系列芯片）、macOS 14 或更高版本**。

**首次安装**：点击上面的下载链接 → 打开 DMG → 将 `MacFanPro.app` 拖入“应用程序” → 打开应用，按提示授权安装后台服务。

<details>
<summary>其他安装方式与文件校验</summary>

| 文件或方式 | 用途 |
| --- | --- |
| [完整压缩包（.tar.gz）](https://github.com/macfanpro/macfanpro/releases/download/vVERSION/MacFanPro-VERSION-macos-arm64.tar.gz) | 包含应用与命令行工具，适合手动安装；[安装步骤](https://github.com/macfanpro/macfanpro/blob/main/README.zh-CN.md#方式二下载发行包安装) |
| [在线安装教程](https://github.com/macfanpro/macfanpro/blob/main/README.zh-CN.md#在线安装脚本) | 使用一条命令安装，包含 GitHub 无法访问时的代理说明 |
| [DMG 校验文件（.sha256）](https://github.com/macfanpro/macfanpro/releases/download/vVERSION/MacFanPro-VERSION-macos-arm64.dmg.sha256) | 可选，用于核对 DMG 下载完整性，不是安装包 |
| [压缩包校验文件（SHA256SUMS）](https://github.com/macfanpro/macfanpro/releases/download/vVERSION/SHA256SUMS) | 可选，用于核对 .tar.gz 下载完整性，不是安装包 |

页面底部的 **Source code (zip / tar.gz)** 是开发者使用的源代码，不是可直接安装的应用。

选择一种安装方式：[Homebrew](https://github.com/macfanpro/macfanpro/blob/main/README.zh-CN.md#方式一通过-homebrew-安装) · [下载发行包](https://github.com/macfanpro/macfanpro/blob/main/README.zh-CN.md#方式二下载发行包安装) · [源码构建](https://github.com/macfanpro/macfanpro/blob/main/README.zh-CN.md#方式三从源码构建安装)。Homebrew 7 需要先执行一次 `brew trust macfanpro/tap`。

</details>

下载失败或被 macOS 拦截时，请查看[中文安装教程](https://github.com/macfanpro/macfanpro/blob/main/README.zh-CN.md#安装)。

### 更新内容

- **新增 / 修复 / 改进**：与英文部分一一对应，删除没有内容的分类。

### 升级说明

填写本版本需要用户采取的动作。更新前先退出应用；Homebrew 更新后还需同步后台服务和应用，详见 [更新步骤](https://github.com/macfanpro/macfanpro/blob/main/README.zh-CN.md#更新)。

### 验证与限制

- 自动化验证、本机验证、签名与公证、验证记录：与英文部分一致。
