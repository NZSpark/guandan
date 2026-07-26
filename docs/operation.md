# Aotearoa掼蛋俱乐部排位系统 — 运维手册

## 1. 系统架构

Aotearoa掼蛋俱乐部排位系统是纯前端 SPA（单页应用），数据完全存储在客户端浏览器中。编译产物为静态文件，托管于 Netlify CDN。

```
┌──────────────────────────────────────────────────┐
│                   用户浏览器                       │
│  ┌────────────────────────────────────────────┐  │
│  │              React SPA                      │  │
│  │  ┌────────────┐  ┌──────────────────┐     │  │
│  │  │  页面组件    │  │  数据层（纯函数）  │     │  │
│  │  │ (rescript)  │  │  配对/计分/排名    │     │  │
│  │  └────────────┘  └──────────────────┘     │  │
│  │         ↕ LocalForage (IndexedDB)           │  │
│  └────────────────────────────────────────────┘  │
│         ↕ JSON 文件导出/导入                       │
│         ↕ GitHub Gist API (可选)                  │
└──────────────────────────────────────────────────┘
         ↕ HTTPS
┌──────────────────────────────────────────────────┐
│           Netlify CDN（静态托管）                   │
│  index.html + JS/CSS 等静态资源                    │
└──────────────────────────────────────────────────┘
```

---

## 2. 技术栈

| 层级 | 技术 | 版本 |
|------|------|------|
| 编程语言 | ReScript（编译至 JavaScript） | ^11.1.4 |
| UI 框架 | React | ^19.2.0 |
| 构建工具 | Vite | ^7.2.2 |
| 包管理 | pnpm | ^10.22.0 |
| Node.js | 运行环境 | ≥ 24 |
| 本地存储 | LocalForage (IndexedDB) | ^1.10.0 |
| 配对算法 | rescript-blossom (Blossom) | ^4.0.0 |
| 测试 | Vitest | ^3.2.4 |
| 云端备份 | @octokit/core (GitHub Gist API) | ^7.0.6 |
| 认证 | netlify-auth-providers | ^1.0.0-alpha5 |

---

## 3. 环境搭建

### 3.1 系统要求

- **操作系统**：macOS、Linux、Windows（WSL）
- **Node.js**：≥ 24
- **pnpm**：通过 Corepack 自动管理
- **Git**：用于克隆仓库

### 3.2 安装

```bash
git clone https://github.com/NZSpark/guandan.git
cd guandan
npm install -g corepack
pnpm install
```

### 3.3 本地开发

开发时需要两个终端：

```bash
# 终端 1：ReScript 编译器（监视模式）
pnpm run res:dev

# 终端 2：Vite 开发服务器
pnpm run dev
```

开发服务器运行于 `http://localhost:3000`。修改 ReScript 源文件后编译器自动编译，浏览器刷新即见变化。

### 3.4 构建生产版本

```bash
pnpm run res:build   # 一次性编译 ReScript
pnpm run build       # Vite 生产构建 → dist/
pnpm run preview     # 预览生产构建
```

---

## 4. 部署

### 4.1 Netlify（当前生产环境）

`netlify.toml` 已配置就绪：

```toml
[build]
  command = "pnpm run build"
  publish = "dist"

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200

[dev]
  port = 3000
```

部署流程：
1. 推送代码到 GitHub 仓库
2. Netlify 自动执行构建并发布

**环境变量**（在 Netlify 控制台设置）：

| 变量 | 用途 |
|------|------|
| `NETLIFY_AUTH_PROVIDERS_SITE_ID` | Netlify 站点 ID（GitHub OAuth 认证使用） |

### 4.2 其他平台

构建产物为纯静态文件，可部署到任意静态托管平台：

| 平台 | 构建命令 | 输出目录 |
|------|----------|----------|
| **Vercel** | `pnpm run build` | `dist` |
| **Cloudflare Pages** | `pnpm run build` | `dist` |
| **GitHub Pages** | `pnpm run build`，推 `dist/` 到 `gh-pages` 分支 | — |
| **Nginx / Apache** | 复制的 `dist/` 内容到 Web 根目录 | — |

### 4.3 Nginx 配置

```nginx
server {
    listen 80;
    server_name guandan.example.com;

    root /var/www/guandan;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /assets {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    gzip on;
    gzip_types text/css application/javascript text/javascript;
}
```

`try_files` 配置确保 SPA 路由在直接访问子路径时正确回退到 `index.html`。

---

## 5. 代码结构

```
guandan/
├── src/
│   ├── Main.res                  # 入口：挂载 React 到 DOM
│   ├── App.res / App.resi        # 根组件 + 路由分发
│   ├── Window.res / Window.resi  # 窗口布局（侧边栏、关于对话框）
│   ├── Router.res / Router.resi  # URL Hash 路由定义
│   ├── HomePage.res              # 首页（Hero + 快捷操作 + 最近赛事 + 功能卡片）
│   ├── MatchCard.res             # 比赛对阵卡片组件
│   ├── LevelPicker.res           # 级数药丸选择器（2–A）
│   ├── Icons.res                 # react-feather 图标绑定
│   ├── Utils.res / Utils.resi    # 工具函数与 Webpack 资源
│   ├── Db.res / Db.resi          # IndexedDB 数据持久化
│   ├── Hooks.res / Hooks.resi    # 通用 React Hooks
│   ├── Toast.res / Toast.resi    # Toast 通知
│   ├── Breadcrumbs.res           # 面包屑导航
│   ├── EmptyState.res / .resi    # 空状态占位组件
│   ├── HelpDialogs.res / .resi   # 帮助对话框
│   ├── index.css                 # 全局样式
│   │
│   ├── Data/                     # 数据模型与业务逻辑
│   │   ├── Data.res              # 聚合导出
│   │   ├── Data_Player.res       # 选手模型
│   │   ├── Data_Team.res         # 队伍模型（双人固定配对）
│   │   ├── Data_Level.res        # 级数体系（2–A, 13 级）
│   │   ├── Data_Match.res        # 比赛对阵模型
│   │   ├── Data_Rounds.res       # 轮次管理
│   │   ├── Data_Scoring.res      # 计分与排名逻辑
│   │   ├── Data_Pairing.res      # 瑞士制 Blossom 配对引擎
│   │   ├── Data_GroupStage.res   # 小组赛引擎（蛇形分组 + 圈圈法）
│   │   ├── Data_Knockout.res     # 淘汰赛引擎（种子排位 + bracket）
│   │   ├── Data_Tournament.res   # 赛事模型（含 Format 类型）
│   │   ├── Data_Config.res       # 全局配置
│   │   ├── Data_CSV.res          # CSV 导入/导出
│   │   └── Data_Id.res           # 通用 ID 系统
│   │
│   ├── PageTournament/           # 赛事页面
│   │   ├── PageTourney.res       # 赛事主页面（Tab 容器）
│   │   ├── PageTourneySetup.res  # 设置标签
│   │   ├── PageTourneyPlayers.res# 选手选择标签
│   │   ├── PageRound.res         # 轮次配对标签
│   │   ├── PageTourneyScores.res # 分数录入标签
│   │   ├── PageTournamentStatus.res # 积分榜标签
│   │   ├── LoadTournament.res    # 赛事数据加载与计算
│   │   └── PairPicker.res        # 手动配对选择器
│   │
│   ├── PagePlayers.res           # 选手/队伍管理页面
│   ├── PageOptions.res           # 选项页面（备份/恢复）
│   ├── PageTournamentList.res    # 赛事列表页面
│   │
│   └── Externals/                # 外部库绑定
│       ├── NetlifyAuth.res       # Netlify OAuth
│       └── Octokit.res           # GitHub API
│
├── tests/                        # 测试文件
├── testutils/                    # 测试工具与测试数据
├── pytools/                      # Python 仿真工具
│   ├── simulate_guandan.py       # 完整赛事仿真
│   ├── haixuansai.py             # 瑞士移位制海选配对
│   ├── xiaozusai.py              # 小组赛单循环排位
│   └── taotaisai.py              # 淘汰赛 bracket 生成
├── output/                       # Python 仿真输出
├── docs/                         # 文档
├── graphics/                     # Logo 与图片资源
├── screenshots/                  # 应用截图
├── index.html                    # HTML 入口
├── vite.config.js                # Vite 配置
├── rescript.json                 # ReScript 编译器配置
└── netlify.toml                  # Netlify 部署配置
```

---

## 6. 路由

基于 URL Hash 路由（`Router.res`）：

| 路由 | 页面 | 说明 |
|------|------|------|
| `#/` | 首页 | Logo、快捷操作、最近赛事、功能介绍 |
| `#/tourneys` | 赛事列表 | 所有赛事，支持按名称/日期排序 |
| `#/tourneys/:id` | 赛事详情 | Tab 容器（状态/设置/选手/轮次/分数/积分榜） |
| `#/players` | 选手/队伍 | 队伍管理、CSV 导入、回避规则 |
| `#/options` | 选项 | 数据导出/导入、JSON 编辑、GitHub Gist |

---

## 7. 数据管理

### 7.1 存储结构

所有数据存储在浏览器 IndexedDB 中（通过 LocalForage 封装），分为 4 个独立存储：

| 存储键 | 内容 |
|--------|------|
| `tournaments` | 全部赛事数据 |
| `teams` | 队伍信息 |
| `players` | 选手信息 |
| `options` | 全局配置（回避规则等） |

### 7.2 备份与恢复

**用户侧备份**：每次比赛后使用「选项」→「导出到本地文件」。

**运维侧备份**：可从生产环境导出数据并保存到云盘/NAS，建议命名规范 `guandan-backup-YYYY-MM-DD.json`。

**数据迁移**：在旧设备导出 JSON（或保存到 Gist），在新设备导入即可。

---

## 8. 每周比赛操作流程

```
赛前：
  1. 确认参赛队伍已录入系统
  2. 创建新赛事（如"2026 WK30 周赛"）
  3. 设置 → 瑞士移位制
  4. 选手 → 勾选当日参赛队伍

比赛：
  5. 第 1 轮 → 自动配对 → 公布对阵
  6. 录入第 1 轮结果
  7. 第 N 轮 → 自动配对 → 公布对阵 → 录结果
  8. 最后轮次完成 → 积分榜公布最终排名

赛后：
  9. 截图/打印积分榜
  10. 导出 JSON 备份
  11. （可选）保存到 GitHub Gist
```

### 8.1 处理迟到/中途加入

在新轮次开始前，进入赛事的「选手」标签页 →「编辑选手名单」→ 勾选新队伍。新队伍从下一轮开始参赛。

### 8.2 处理退赛

进入「选手」标签页 →「编辑选手名单」→ 取消勾选。退赛队伍的历史轮次不受影响。

### 8.3 小组赛 + 淘汰赛混合赛事

1. **第一阶段**：创建赛事（小组赛），完成后导出积分榜
2. **第二阶段**：创建新赛事（淘汰赛），手动选择晋级队伍参赛

---

## 9. 测试

```bash
pnpm test                          # 运行全部测试
npx vitest run tests/CSV_test.res.mjs  # 运行单个测试文件
```

测试覆盖：CSV 解析、数据编解码、工具函数。

---

## 10. 代码规范

- 使用 `open! Belt`
- 警告模式 `+A-3-44-102`：所有模式匹配必须穷尽（禁止 `_` 通配符用于 variant 解构）
- 数据模型提供对称的 `encode`/`decode` 函数用于 JSON 序列化
- ReScript 输出为 ESM 格式，内联至 `.res.mjs`

### 10.1 代码格式化

```bash
pnpm run format
```

---

## 11. 故障排查

### 应用加载

| 现象 | 可能原因 | 解决方法 |
|------|----------|----------|
| 页面空白 | JavaScript 禁用 | 浏览器设置中启用 |
| 页面空白 | 浏览器过旧 | 更新至最新 Chrome/Firefox |
| 部署后 404 | SPA 路由未回退 | 配置 `try_files`（参见 Nginx 示例） |

### 数据

| 现象 | 可能原因 | 解决方法 |
|------|----------|----------|
| 数据消失 | 清除浏览器数据 | 从备份 JSON 恢复 |
| 数据丢失 | 使用无痕模式 | 使用普通窗口（无痕模式不持久化） |
| 导入失败 | JSON 格式损坏 | 用编辑器检查 JSON 语法 |

### 配对

| 现象 | 可能原因 | 解决方法 |
|------|----------|----------|
| 自动配对无反应 | 参赛队伍 < 2 | 确保 ≥ 2 支队伍被选中 |
| 结果不理想 | 回避规则过多 | 清理不必要的回避设置 |
| 出现重复 | 所有组合已用尽 | 手动配对调整 |

### 构建

| 现象 | 可能原因 | 解决方法 |
|------|----------|----------|
| ReScript 编译错误 | 语法/类型错误 | 查看终端输出定位源码 |
| Vite 构建失败 | 依赖不兼容 | `rm -rf node_modules pnpm-lock.yaml && pnpm install` |
| Node 版本不兼容 | < 24 | 升级到 Node.js 24+ |

### 清理重装

```bash
pnpm run res:clean              # 清理编译缓存

# 完整清理
rm -rf node_modules pnpm-lock.yaml
pnpm install
pnpm run res:build
pnpm test
```

---

## 12. 依赖更新

```bash
pnpm update                 # 更新全部依赖
pnpm update <package-name>  # 更新指定依赖

# 更新后验证
pnpm run res:build
pnpm run build
pnpm test
```

---

## 13. 监控

本系统为纯前端应用，无需传统服务器监控。建议关注：

| 监控项 | 方法 | 频率 |
|--------|------|------|
| 网站可用性 | 访问在线地址确认可加载 | 每周 |
| Netlify 构建 | 查看 Dashboard 构建日志 | 每次推送后 |
| GitHub Issues | 查看 Issues 页面 | 每周 |
| 浏览器兼容 | Chrome / Firefox / Safari 各测一次 | 发版前 |

---

## 14. 附录：命令速查

| 命令 | 说明 |
|------|------|
| `pnpm install` | 安装依赖 |
| `pnpm run res:dev` | ReScript 编译（监视） |
| `pnpm run res:build` | ReScript 编译（一次性） |
| `pnpm run res:clean` | 清理编译缓存 |
| `pnpm run dev` | Vite 开发服务器 |
| `pnpm run build` | 生产构建 |
| `pnpm run preview` | 预览生产构建 |
| `pnpm test` | 运行测试 |
| `pnpm run format` | 格式化源码 |

---

## 15. 联系方式

- **源码**：[github.com/NZSpark/guandan](https://github.com/NZSpark/guandan)
- **Issues**：[GitHub Issues](https://github.com/NZSpark/guandan/issues)
- **邮箱**：spark.zheng@icloud.com
- **在线应用**：[ai3d.co.nz/guandan](https://ai3d.co.nz/guandan/)

---

**许可证**：[MPL-2.0](https://github.com/NZSpark/guandan/blob/master/LICENSE)
