# 发布说明维护

README 面向安装和使用，CHANGELOG 汇总版本历史，GitHub Release 描述当前这一版的变化。三者不应互相整篇复制。

## 文件与流程

- 每个版本使用独立文件，例如 `0.2.3.15.md` 对应标签 `v0.2.3.15`。
- 从 [TEMPLATE.md](TEMPLATE.md) 复制新文件，填写实际变化并删除没有内容的可选分类；不要发布占位符或未经验证的结论。
- 发布标题统一为 `MacFanPro 版本号`，正文无需重复一级标题。
- Homebrew 配方与预编译包（bottle）已自动化：在网页上公开发布后，tap 仓库的 [Update formula](https://github.com/macfanpro/homebrew-tap/blob/main/.github/workflows/update-formula.yml) 工作流会在一小时内（或执行 `gh workflow run update-formula.yml -R macfanpro/homebrew-tap` 立即）把配方指向新标签、构建并上传 `arm64_sonoma` 预编译包、确认 Homebrew 直接安装预编译包且 `brew test` 通过，然后才提交配方。草稿不会触发。工作流失败时查看其运行日志，必要时按工作流中的步骤手动处理。
- 自 0.2.3.29 起，发布说明中英双语：英文在前，`## 中文说明` 之后为中文，两部分内容一致；安装链接分别指向 `README.md`（英文）与 `README.zh-CN.md`（中文）的对应章节。已发布的旧版本不回改。
- 发布工作流先检查对应说明文件，再执行既有测试和打包，最后以该文件创建草稿；不再把整个 CHANGELOG 放入单个发行页。
- 下载草稿附件、完成相应验证后，再填写准确的验证结果并更新草稿正文，最后公开发布。不要提前把预计完成的测试写成“已通过”。

编辑已发布版本的说明时，只调整文字、链接和结构，保留该版本的真实行为、资产和标签。校验和与验证记录应对应原发行产物，不能使用其他版本的结果替代。

## 内容与排版

1. **一句话摘要**：说明这一版解决的主要问题和上游基础版本。
2. **更新内容**：按实际内容使用“新增”“修复”“改进”分类，用简短条目描述用户能感知的变化；有相关 PR 或提交时附链接。不要把已有功能写成新增。
3. **下载与安装**：用表格标明平台、完整安装包及 SHA-256 文件，链接到 README 中的三种安装方法。历史版本的 Homebrew 链接只能说明安装当前稳定版，不能暗示会安装历史版本。
4. **升级说明**：明确用户是否需要额外操作。较长的命令可放入 `<details>`，保持主页面便于浏览。
5. **验证与限制**：列出实际完成的检查，区分自动化与本机验证，并链接对应版本的记录。未公证或未覆盖的环境应说明。
6. **完整变更**：使用相邻有效标签的 compare 链接；首个 MacFanPro 版本没有上一 MacFanPro 标签时，链接本版本源代码即可。

Release 正文中的文件链接应使用完整 GitHub URL。对会随时间变化的操作文档可链接 `main`；对历史验证证据使用已确认的提交链接。仅有链接或校验和不代表已完成实机验证。

## 参考

采用常见的 GitHub Markdown 标题、分类列表、下载入口和完整变更链接，保持中文内容，不添加无内容的分类、徽章或装饰。

- [Stats v3.0.17](https://github.com/exelban/stats/releases/tag/v3.0.17)：按修复、功能和本地化分组。
- [GitHub CLI v2.101.0](https://github.com/cli/cli/releases/tag/v2.101.0)：突出升级影响，按变化类型组织条目并链接 PR。
- [GitHub 自动生成发布说明文档](https://docs.github.com/en/repositories/releasing-projects-on-github/automatically-generated-release-notes)：完整变更与贡献者信息仍需人工检查是否适合该次发行。

在线安装器：打包时把 `Scripts/install.sh` 固定到当前发行版本，同时嵌入 App 并生成 `install.sh` / `install.sh.sha256` 两个附件。`SHA256SUMS` 必须继续只含发行包，以兼容已部署的 0.2.3.32 更新器。草稿验收需检查附件脚本与包内脚本一致、两个校验文件正确，并按 [安装器验证](../online-installer.md) 检查。首次上线要发布新版本，不能覆盖既有标签或向旧版本上传其他源码构建的产物。
