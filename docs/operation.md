# Aotearoa掼蛋俱乐部排位系统 — 运维手册

## 1. 系统概述

Aotearoa掼蛋俱乐部排位系统是一款纯前端 Web 应用，基于浏览器运行，无需后端服务器。系统使用 ReScript + React 构建，编译为静态 JavaScript 文件，托管于 Netlify CDN。

### 1.1 系统架构

```
┌──────────────────────────────────────────┐
│               用户浏览器                    │
│  ┌────────────────────────────────────┐  │
│  │         React SPA 应用              │  │
│  │  ┌──────────┐  ┌───────────────┐   │  │
│  │  │  UI 层    │  │  数据层 (纯函数)│   │  │
│  │  │ (页面组件) │  │  配对/计分/排名 │   │  │
│  │  └──────────┘  └───────────────┘   │  │
│  │         ↕ IndexedDB (LocalForage)   │  │
│  └────────────────────────────────────┘  │
│              ↕ JSON 文件导出/导入           │
│              ↕ GitHub Gist API (可选)      │
└──────────────────────────────────────────┘
              ↕ HTTPS
┌──────────────────────────────────────────┐
│            Netlify CDN (静态托管)           │
│  index.html + JS/CSS 静态资源              │
└──────────────────────────────────────────┘
```

### 1.2 技术栈

| 层级 | 技术 | 版本要求 |
|------|------|----------|
| 编程语言 | ReScript (编译至 JavaScript) | ^11.1.4 |
| UI 框架 | React | ^19.2.0 |
| 构建工具 | Vite | ^7.2.2 |
| 包管理 | pnpm | ^10.22.0 |
| 运行时 | Node.js | ≥24 |
| 本地存储 | LocalForage (IndexedDB) | ^1.10.0 |
| 配对算法 | rescript-blossom | ^4.0.0 |
| 测试框架 | Vitest | ^3.2.4 |
| 云端备份 | GitHub Gist API (via Netlify Auth) | — |

---

## 2. 环境搭建

### 2.1 系统要求

- **操作系统**：macOS、Linux 或 Windows
- **Node.js**：版本 24 或以上
- **pnpm**：版本 10.22.0 或以上（通过 Corepack 自动管理）
- **Git**：用于克隆源码仓库
- **浏览器**：Chrome 90+、Firefox 88+、Safari 14+、Edge 90+

### 2.2 安装步骤

```bash
# 1. 克隆仓库
git clone https://github.com/NZSpark/guandan.git
cd guandan

# 2. 安装 Corepack（如尚未安装）
npm install -g corepack

# 3. 安装依赖
pnpm install
```

### 2.3 本地开发

```bash
# 终端 1：启动 ReScript 编译器（监视模式）
pnpm run res:dev

# 终端 2：启动 Vite 开发服务器
pnpm run dev
```

开发服务器默认监听 `http://localhost:5173`。修改 ReScript 源代码后，编译器会自动重新编译，浏览器刷新即可看到变化。

### 2.4 构建生产版本

```bash
# 编译 ReScript
pnpm run res:build

# 构建优化后的静态文件
pnpm run build
```

构建产物位于 `dist/` 目录，包含 `index.html` 及所有 JS/CSS 资源文件，可直接部署到任意静态文件服务器或 CDN。

---

## 3. 部署指南

### 3.1 Netlify 部署（当前生产环境）

本系统当前托管于 Netlify，配置文件 `netlify.toml` 已就绪：

```toml
[build]
  command = "pnpm run build"
  publish = "dist"
```

**部署方式**：
1. 将代码推送到 GitHub 仓库
2. 在 Netlify 中关联该仓库
3. Netlify 自动检测 `netlify.toml`，执行构建并发布

**环境变量**（在 Netlify 控制台设置）：
- `NETLIFY_AUTH_PROVIDERS_SITE_ID` — Netlify 站点 ID（用于 GitHub OAuth）

### 3.2 其他静态托管平台

构建产物为纯静态文件，可部署到以下平台：

| 平台 | 部署方式 |
|------|----------|
| **GitHub Pages** | 将 `dist/` 推送到 `gh-pages` 分支 |
| **Vercel** | 关联仓库，构建命令 `pnpm run build`，输出目录 `dist` |
| **Cloudflare Pages** | 同上配置 |
| **Nginx / Apache** | 将 `dist/` 目录内容复制到 Web 根目录 |
| **任意对象存储** | 上传到 S3/GCS/OSS 并配置静态网站托管 |

### 3.3 Nginx 配置示例

```nginx
server {
    listen 80;
    server_name guandan.example.com;

    root /var/www/guandan;
    index index.html;

    # SPA 路由回退
    location / {
        try_files $uri $uri/ /index.html;
    }

    # 静态资源缓存
    location /assets {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Gzip 压缩
    gzip on;
    gzip_types text/css application/javascript text/javascript;
}
```

---

## 4. 数据管理

### 4.1 数据存储位置

所有数据存储在用户浏览器的 **IndexedDB** 数据库中（通过 LocalForage 封装）。数据完全在客户端，不会自动上传到任何服务器。

关键存储键：
- `config` — 全局配置
- `players` — 选手数据
- `teams` — 队伍数据
- `tournaments` — 赛事数据

### 4.2 数据备份策略

#### 4.2.1 用户侧备份

建议指导俱乐部管理员在每次比赛后执行 JSON 文件导出（参考用户手册 3.6 节）。

#### 4.2.2 运维侧备份

作为运维人员，可以定期从生产版本中导出数据：

1. 访问 [https://ai3d.co.nz/guandan/](https://ai3d.co.nz/guandan/)
2. 进入「选项」→「导出到本地文件」
3. 将 JSON 文件保存到安全位置（如云盘、NAS）
4. 建议命名规范：`guandan-backup-YYYY-MM-DD.json`

### 4.3 数据恢复

#### 4.3.1 从 JSON 文件恢复

1. 进入「选项」页面
2. 点击「从本地文件导入」
3. 选择备份的 JSON 文件
4. 系统自动加载全部数据

#### 4.3.2 从 GitHub Gist 恢复

1. 确保已登录 GitHub
2. 在「选项」页面选择要恢复的 Gist
3. 点击「从此 Gist 加载」

### 4.4 数据迁移

如需在不同设备间迁移数据：

1. 在旧设备上导出 JSON 文件或保存到 Gist
2. 在新设备上导入 JSON 文件或从 Gist 加载
3. 验证所有赛事和队伍数据完整性

---

## 5. 日常运维操作

### 5.1 新俱乐部注册并开始使用

1. 确保有稳定的网络连接
2. 访问 [https://ai3d.co.nz/guandan/](https://ai3d.co.nz/guandan/)
3. 在「选手与队伍管理」中录入所有会员队伍
4. 创建第一个赛事即可开始

### 5.2 每周比赛操作流程

```
赛前准备：
  1. 确认所有参赛队伍已在系统中注册
  2. 进入「赛事管理」→「添加赛事」（如"2026 WK29 周赛"）
  3. 在「设置」中选择「瑞士移位制」
  4. 在「选手」中勾选当日参赛的队伍
  5. 点击「完成选择，进入锦标赛」

比赛开始：
  6. 进入第 1 轮 → 点击「自动配对」
  7. 告知各队伍对阵信息（可截图或打印）
  8. 比赛结束后进入「录入第 1 轮」，录入结果

后续轮次：
  9. 进入第 2 轮 → 点击「自动配对」
  10. 重复步骤 7-8
  11. 所有轮次完成后，查看「积分榜」公布最终排名

赛后收尾：
  12. 拍照或打印积分榜
  13. 在「选项」中导出 JSON 备份
  14. 可选：保存到 GitHub Gist
```

### 5.3 处理迟到/临时加入的队伍

1. 在当前轮次开始前，进入赛事的「选手」标签页
2. 点击「编辑选手名单」
3. 勾选新加入的队伍
4. 该队伍从下一轮开始参与配对

### 5.4 处理队伍中途退赛

1. 进入赛事的「选手」标签页
2. 点击「编辑选手名单」
3. 取消勾选退赛队伍
4. 退赛队伍已参加的历史轮次不受影响

### 5.5 举办小组赛 + 淘汰赛的混合赛事

1. **第一阶段 — 小组赛**：
   - 创建赛事，选择「小组赛/单循环」
   - 完成全部小组赛后，导出积分榜
   
2. **第二阶段 — 淘汰赛**：
   - 创建新赛事，选择「淘汰赛」
   - 手动选择各小组出线队伍参赛

---

## 6. 测试

### 6.1 运行测试

```bash
pnpm test
```

### 6.2 运行单个测试文件

```bash
npx vitest run tests/CSV_test.res.mjs
```

### 6.3 测试覆盖范围

当前测试覆盖以下模块：
- CSV 导入解析
- 数据模块编解码
- 工具函数

---

## 7. 代码格式化

```bash
pnpm run format
```

该命令使用 ReScript 自带的格式化工具统一代码风格。

---

## 8. 故障排查

### 8.1 应用无法加载

| 现象 | 可能原因 | 解决方法 |
|------|----------|----------|
| 页面空白 | JavaScript 被禁用 | 在浏览器设置中启用 JavaScript |
| 页面空白 | 浏览器版本过低 | 更新至最新版 Chrome/Firefox/Edge |
| 加载缓慢 | 网络问题 | 检查网络连接，尝试刷新 |
| 部署后 404 | SPA 路由未配置回退 | 参见 Nginx 配置示例的 `try_files` 设置 |

### 8.2 数据丢失

| 现象 | 可能原因 | 解决方法 |
|------|----------|----------|
| 赛事数据消失 | 清除了浏览器数据 | 从备份 JSON 文件恢复 |
| 部分数据丢失 | 使用了隐私/无痕模式 | 退出无痕模式使用普通窗口（无痕模式数据不持久化） |
| 导入失败 | JSON 格式损坏 | 使用编辑器检查 JSON 语法，确保格式正确 |

### 8.3 自动配对异常

| 现象 | 可能原因 | 解决方法 |
|------|----------|----------|
| 自动配对按钮无反应 | 参赛队伍过少（<2） | 确保至少 2 支队伍被选中 |
| 配对结果不理想 | 队伍间设了回避规则 | 检查并清理不必要的回避设置 |
| 出现重复配对 | 所有可能组合已用尽 | 使用手动配对调整 |

### 8.4 构建失败

| 现象 | 可能原因 | 解决方法 |
|------|----------|----------|
| ReScript 编译错误 | 语法错误或类型不匹配 | 查看终端错误信息，定位并修复源码 |
| Vite 构建失败 | 依赖版本不兼容 | 删除 `node_modules` 和 `pnpm-lock.yaml`，重新 `pnpm install` |
| Node 版本不兼容 | Node.js 版本过低 | 升级到 Node.js 24+ |

### 8.5 编译调试

```bash
# 清理 ReScript 编译缓存
pnpm run res:clean

# 重新编译（显示详细错误）
pnpm run res:build

# 如仍有问题，完整清理后重试
rm -rf node_modules pnpm-lock.yaml
pnpm install
pnpm run res:build
```

---

## 9. 依赖更新

### 9.1 更新所有依赖

```bash
pnpm update
```

### 9.2 更新特定依赖

```bash
pnpm update <package-name>
```

### 9.3 更新后验证

```bash
pnpm run res:build    # 确认编译通过
pnpm run build        # 确认构建通过
pnpm test             # 确认测试通过
```

---

## 10. 生产环境监控

由于本系统为纯前端应用，无需传统的服务器监控。建议关注以下方面：

| 监控项 | 方法 | 频率 |
|--------|------|------|
| 网站可用性 | 访问 [ai3d.co.nz/guandan](https://ai3d.co.nz/guandan/) 确认可加载 | 每周 |
| Netlify 构建状态 | 查看 Netlify Dashboard 构建日志 | 每次推送后 |
| GitHub Issues | 查看 [GitHub Issues](https://github.com/NZSpark/guandan/issues) | 每周 |
| 浏览器兼容性 | 用 Chrome/Firefox/Safari 各测试一次 | 发版前 |

---

## 11. 代码结构与导航

```
guandan/
├── src/
│   ├── Data/              # 数据模型与业务逻辑
│   │   ├── Data_Team.res      # 队伍数据结构
│   │   ├── Data_Player.res    # 选手数据结构
│   │   ├── Data_Tournament.res # 赛事数据结构（含 Format 类型）
│   │   ├── Data_Match.res     # 比赛对阵结构
│   │   ├── Data_Pairing.res   # 瑞士制配对引擎
│   │   ├── Data_GroupStage.res # 小组赛引擎
│   │   ├── Data_Knockout.res  # 淘汰赛引擎
│   │   ├── Data_Scoring.res   # 计分与排名逻辑
│   │   └── Data_Rounds.res    # 轮次管理
│   ├── PageTournament/    # 赛事相关页面组件
│   │   ├── PageTourney.res       # 赛事主页面（多标签容器）
│   │   ├── PageTourneySetup.res  # 设置标签（赛制选择）
│   │   ├── PageTourneyPlayers.res # 选手选择标签
│   │   ├── PageRound.res         # 轮次配对标签
│   │   ├── PageTourneyScores.res # 分数录入标签
│   │   ├── PageTournamentStatus.res # 积分榜标签
│   │   ├── LoadTournament.res    # 赛事加载逻辑
│   │   └── TournamentUtils.res   # 赛事工具函数
│   ├── App.res            # 根组件 + 路由
│   ├── Db.res             # IndexedDB 数据持久化
│   ├── Router.res         # 路由定义
│   └── Hooks.res          # 通用 React Hooks
├── tests/                 # 测试文件
├── docs/                  # 文档
├── pytools/               # Python 辅助工具
├── index.html             # HTML 入口
├── vite.config.js         # Vite 构建配置
├── rescript.json          # ReScript 编译器配置
└── netlify.toml           # Netlify 部署配置
```

---

## 12. 联系与支持

- **源码仓库**：[https://github.com/NZSpark/guandan](https://github.com/NZSpark/guandan)
- **问题反馈**：[https://github.com/NZSpark/guandan/issues](https://github.com/NZSpark/guandan/issues)
- **邮箱**：spark.zheng@icloud.com
- **在线应用**：[https://ai3d.co.nz/guandan/](https://ai3d.co.nz/guandan/)

---

## 附录 A：构建与部署命令速查

| 命令 | 说明 |
|------|------|
| `pnpm install` | 安装所有依赖 |
| `pnpm run res:dev` | 启动 ReScript 编译器（监视模式） |
| `pnpm run res:build` | 一次性编译 ReScript |
| `pnpm run res:clean` | 清理 ReScript 编译缓存 |
| `pnpm run dev` | 启动 Vite 开发服务器 |
| `pnpm run build` | 构建生产版本（编译 + 打包） |
| `pnpm run preview` | 预览生产构建 |
| `pnpm test` | 运行测试套件 |
| `pnpm run format` | 格式化所有 ReScript 源码 |

## 附录 B：许可证

本项目使用 [MPL-2.0](https://github.com/NZSpark/guandan/blob/master/LICENSE) 许可证。
