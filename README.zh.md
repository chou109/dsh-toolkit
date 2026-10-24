# dsh-toolkit —— DeepSeek Harness 0.2.x 增强包

面向 **DeepSeek Harness 0.2.1-rc.2** 的两个即插即用客户端插件，全部以标准 bundle 安装——**不打补丁、不改 Harness 任何文件**：

| 组件 | 版本 | 作用 |
|---|---|---|
| **MsgRail**（`dsh-msgrail`） | 2.0.0 | 输入框下方的全量消息轨道：悬停预览、点击跳转 |
| **Workspace Launcher**（`dsh-workspace-launcher`） | 2.0.0 | 会话标题栏菜单：用资源管理器 / VS Code / 终端打开工作区，或复制路径 |

> English: [README.md](README.md)

## 0.2.x 的变化

1.x 的工具包是靠补丁实现的：修改 `dsh-client-ui-layout`、`dsh-client-ui-workspace`、`dsh-host-apiproxy`、`dsh-llm-pi-ai`。DSH 0.2 的客户端包全部是动态 bundle，直接改已安装文件既不安全也没必要。两个保留组件全部改为通过官方 slot 与宿主路由接入。

| 旧组件 | 0.2.x 状态 |
|---|---|
| **msgrail** | ✅ 已移植到 2.0.0 —— `conversation.composer.dock` + 会话 `eventSource`，不再打布局补丁 |
| **workspace-launcher** | ✅ 已移植到 2.0.0 —— 会话标题栏动作，不再打工作区客户端补丁 |
| **archives** | ⛔ **已退役** —— DSH 0.2 原生支持归档/取消归档（行菜单 + 视图筛选），无需安装 |
| **vision-bridge** | ⏸ **未移植** —— 它的两个宿主补丁针对 0.1.x 包。请使用 Harness 自带的图片能力或视觉 MCP；历史补丁保留在 `components/vision-bridge/` |

## 环境要求

- DeepSeek Harness **0.2.1-rc.2**（桌面版或 `dsh web`）
- 其他什么都不需要：插件本身不需要 `git`，也不需要构建

## 安装

### 插件管理器（桌面版，推荐）

1. 插件 → 从文件夹安装。
2. 选择 `components/msgrail/plugin/dsh-msgrail`。
3. 再选择 `components/workspace-launcher/plugin/dsh-workspace-launcher`。
4. 启用两者，刷新页面。

### 命令行

```bash
dsh plugin --profile <profile> add /absolute/path/to/components/msgrail/plugin/dsh-msgrail
dsh plugin --profile <profile> add /absolute/path/to/components/workspace-launcher/plugin/dsh-workspace-launcher
```

### 脚本

```powershell
.\install.ps1                 # Windows：安装/链接两个 bundle
```

```bash
./install.sh                  # macOS / Linux
```

脚本不会修改任何 Harness 包；如果找不到 `dsh` CLI，会打印插件管理器步骤。

## 验证

1. **MsgRail** —— 打开一个包含你发送的消息的会话；输入框下方出现刻度带。悬停出预览，点击滚动对话。
2. **Workspace Launcher** —— 会话标题栏出现“打开工作区”；菜单能拉起资源管理器 / VS Code / 终端并复制路径。

## 卸载

在插件管理器中停用或移除两个 bundle（或删除 `cordis.patch.yml` 里的 `insert` 行），刷新页面即可。因为没有打补丁，不需要任何还原步骤。

## 为什么不再打补丁

0.1.x 的补丁只能撑到下一次 Harness 更新，而且周围代码一变就可能损坏已安装的 bundle。0.2 的插件契约（`dsh.bundle.patch` + `dsh.client` + slot 服务）跨版本稳定，也是唯一受支持的扩展方式。即使将来某个 slot 或服务签名变化，插件也只会在自己的槽位里可见地失败，而不会拖垮整个界面。

## 仓库结构

```
components/
  msgrail/plugin/dsh-msgrail/                     bundle（清单 + patch + 客户端）
  workspace-launcher/plugin/dsh-workspace-launcher/
  archives/                                       已退役的 0.1.x 参考
  vision-bridge/                                  0.1.x 补丁（未移植）
install.ps1 / install.sh                          仅安装 bundle
```

## 许可证

MIT。
