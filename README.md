

# Aotearoa掼蛋俱乐部排位系统

**Aotearoa掼蛋俱乐部排位系统** 是由 [Aotearoa掼蛋俱乐部]() 开发维护的掼蛋比赛管理 Web 应用。系统支持瑞士移位制、小组单循环赛和淘汰赛三种赛制，可自动完成选手配对、级差计分、实时排名与数据导出等全部比赛管理流程。

[用户手册](./docs/usermanual.md) |
[运维手册](./docs/operation.md) |
[常见问题](./docs/faq.md)

---

## 关于 Aotearoa掼蛋俱乐部

Aotearoa掼蛋俱乐部致力于在新西兰推广和普及掼蛋这项中国传统牌类运动。本系统专为俱乐部的周赛、月赛、年度总决赛等各类赛事而打造，旨在让比赛组织者从繁琐的人工配对和计分中解放出来，专注于比赛本身。

---

## 功能特性

| 模块 | 功能 |
|------|------|
| **队伍管理** | 录入队伍/队员信息，支持 CSV 批量导入，设置回避规则 |
| **三种赛制** | 瑞士移位制（Swiss）、小组单循环赛（Group Stage）、淘汰赛（Knockout） |
| **智能配对** | 瑞士制自动配对（Blossom 算法）、小组赛蛇形分组圈圈法排表、淘汰赛种子排位 |
| **手动干预** | 支持手动取消/创建配对，灵活应对比赛中的特殊情况 |
| **级差计分** | 按掼蛋级数（2–A）录入结果，自动计算场分、净积小分、累积小分 |
| **实时排名** | 多级破同分规则（总积分 → 相互胜负 → 净积小分 → 累积小分） |
| **数据安全** | 纯客户端存储（IndexedDB），支持 JSON 文件导入/导出与 GitHub Gist 云端备份 |
| **跨平台** | 纯 Web 应用，任何现代浏览器均可使用，无需安装 |

### 赛制对比

| 赛制 | 配对方式 | 轮次数 | 适用场景 |
|------|----------|--------|----------|
| 瑞士移位制 | 按积分分组配对，避免重复相遇 | `⌈log₂(N)⌉` | 周赛、月赛 |
| 小组单循环 | 蛇形分组，组内单循环 | 组内 `m-1` 轮 | 分组预选赛 |
| 淘汰赛 | 种子排位，单败淘汰 | `log₂(N)` | 总决赛、杯赛 |

---

## 快速开始

### 本地开发

```bash
# 系统要求：Node.js ≥ 24
git clone https://github.com/NZSpark/guandan.git
cd guandan
npm install -g corepack
pnpm install

# 编译 ReScript（监视模式）
pnpm run res:dev

# 启动开发服务器（另一个终端）
pnpm run dev
```

详细开发指南请参见 [运维手册](./docs/operation.md)。

---

## 截图

![轮次配对界面](./screenshot-round.png)

![计分录入界面](./screenshot-score-detail.png)

---

## 文档

- **[用户手册](./docs/usermanual.md)** — 面向比赛组织者的完整操作指南
- **[运维手册](./docs/operation.md)** — 面向开发/运维人员的部署与维护指南
- **[常见问题](./docs/faq.md)** — 常见问题解答

---

## 技术栈

| 层级 | 技术 |
|------|------|
| 语言 | [ReScript](https://rescript-lang.org/) |
| UI 框架 | [React](https://reactjs.org/) 19 |
| 构建工具 | [Vite](https://vitejs.dev/) 7 |
| 包管理 | [pnpm](https://pnpm.io/) |
| 配对算法 | [rescript-blossom](https://github.com/johnridesabike/rescript-blossom) |
| 测试 | [Vitest](https://vitest.dev/) |


---

## 贡献

欢迎通过以下方式参与贡献：

- [提交 Bug 报告或功能建议](https://github.com/NZSpark/guandan/issues)
- [查看贡献指南](./CONTRIBUTING.md)
- 发送邮件至 spark.zheng@icloud.com

---

## 致谢

- 系统以https://github.com/johnridesabike/coronate为基础进行开发
- 使用了Codebuddy作为开发工具。


