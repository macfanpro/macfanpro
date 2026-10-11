# Gitee 镜像

- GitHub 维护源：<https://github.com/macfanpro/macfanpro>
- Gitee 镜像：<https://gitee.com/macfanpro/macfanpro>
- Gitee 发行版本：<https://gitee.com/macfanpro/macfanpro/releases>

镜像包括代码历史、全部分支和标签、已公开 Release 的标题、说明、预发布标记及全部附件。发行说明中的附件下载链接替换为 Gitee 地址，上传后重新下载核对 SHA-256；附件内容保持原样。Gitee 的发行记录创建时间是同步时间，原始发布时间以 GitHub 为准。

## 自动同步

GitHub Actions 的 **Mirror to Gitee** 工作流执行同步：

- 推送或删除分支、标签：同步 Git 引用。
- 发布、编辑、删除或取消公开 Release：同步对应版本及附件。
- 手动执行工作流：补同步全部代码和已公开版本，并清理 GitHub 已撤回的镜像版本。

GitHub 是唯一维护源；请在 GitHub 修改代码和版本说明。Gitee 中的分支、标签和发行版本以 GitHub 为准，同步会覆盖或删除对应的镜像内容。Git 推送使用原子操作和预期旧值检查，避免在上传过程中覆盖并发修改；附件同名但校验和不同则报错，保留现场供维护者检查。

并发任务依次执行，使用 GitHub 的 [`queue: max`](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#example-queueing-multiple-pending-runs) 保留最多 100 个等待任务，避免连续推送挤掉待同步的发行事件。失败时工作流明确报错，修复后可手动重跑：已存在的版本和附件会先核验，避免重复上传。新增已公开版本的附件后，也可以手动补同步；同名附件被替换时需先调查校验和变化，再处理镜像中的旧附件。

## 授权与手动补同步

在 GitHub 仓库的 Actions secret 中配置 `GITEE_TOKEN`，使用拥有目标仓库写权限、包含 `projects` 权限的 Gitee 私人令牌。令牌同时用于 Gitee Git HTTPS 推送和发行 API；不要提交到代码、配置文件或日志中。

```bash
gh workflow run mirror-gitee.yml -R macfanpro/macfanpro
```

也可在本机设置 `GITEE_TOKEN`，登录 GitHub CLI 后执行：

```bash
python3 Scripts/mirror-gitee.py
```

## 下载提示

普通用户可在 Gitee 发行页直接下载 DMG。原始附件中的在线安装脚本、应用更新检查仍按原版访问 GitHub；下载原版 `install.sh` 不会自动把其内部地址改成 Gitee。需要避开 GitHub 下载时，使用 Gitee 的 DMG 或完整压缩包，更新时下载对应新版覆盖安装。

本镜像不复制 GitHub 的账号权限、Issues、PR、讨论、Actions 运行记录或 Homebrew tap；这些仍由原平台维护。镜像过程不构建或安装应用。

## 首次迁移验证（2026-10-11）

- GitHub 与 Gitee 的 3 个分支、38 个标签逐项核对提交/对象 ID，一致。
- 36 个公开版本、130 个附件全部迁移；每个附件上传后从 Gitee 公开地址重新下载，SHA-256 与 GitHub 原文件一致。
- 当前最新版本为 `v0.2.3.63`，版本标题、说明中的下载地址、预发布状态和附件列表已核验。
- 本地 Debug / Release 测试、安装脚本检查、镜像脚本离线回归和本地化打包检查通过；令牌通过 Git HTTPS 认证的实测通过。
- 未安装或启动发行包，未操作本机后台服务或真实风扇。
