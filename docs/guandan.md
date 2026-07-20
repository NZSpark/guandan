# AotearoaGuandan → Aotearoa掼蛋俱乐部排位系统 改造方案

## 一、项目当前架构概览

AotearoaGuandan 是一个**纯前端单页应用**，使用 **ReScript + React** 构建，数据通过 **LocalForage**（浏览器 IndexedDB）本地存储。核心是瑞士制（Swiss-system）国际象棋锦标赛管理，1v1 对阵，基于 USCF 规则的计分和破同分系统。

### 核心数据流（当前）

```
选手注册 → 创建锦标赛 → 添加单人选手 → 按轮次1v1配对 → 录入胜/负/平 → 计分排名
```

---

## 二、掼蛋与象棋的核心差异

| 维度 | 国际象棋（当前） | 掼蛋（目标） |
|------|-----------------|-------------|
| 参赛单元 | 1人 | 2人队伍（固定搭档） |
| 每场比赛 | 2人对弈 | 4人对战（2队×2人） |
| 结果类型 | 胜/负/平 | 级差制（记录双方打到的最终级数） |
| 计分方式 | Elo等级分 + 场分(1/0.5/0) | 场分制（胜3/平2/负1/缺席0） |
| 破同分 | USCF规则（中位数/Solkoff/累积分等） | 相互胜负→净积小分→累积小分→抽签 |
| 配对算法 | Blossom加权匹配 + 颜色平衡 | 瑞士制队伍配对（场分优先，无颜色） |
| "颜色"概念 | 白方/黑方交替 | 不需要 |
| 轮空 | 单人轮空 | 队伍轮空（得3分，不计小分） |
| 评级体系 | Elo rating（动态变化） | 不使用等级分 |
| 赛事阶段 | 单一瑞士制 | 瑞士→小组循环→淘汰→决赛 |

---

## 三、全新数据模型设计

> 不保留任何旧数据格式，所有模型按掼蛋需求全新设计。

### 3.1 选手 `Data_Player.res`

选手作为个体存在，是队伍的子单元。选手库独立于赛事，可跨赛事复用。

```rescript
type t = {
  id: Data_Id.t,
  firstName: string,
  lastName: string,
  // 删除：matchCount, rating（掼蛋中选手无独立等级分）
  // 删除：type_（不再有 Dummy/Missing 分类，轮空改为队伍级别处理）
}
```

**改动说明**：大幅简化，只保留身份信息。`rating`/`matchCount`/`type_` 全部移除，不再需要 Dummy 选手和 Missing 占位符。

### 3.2 队伍 `Data_Team.res` — 新增模块

队伍是参赛的基本单元，也是计分和排名的对象。

```rescript
type t = {
  id: Data_Id.t,
  name: string,                   // 队伍名称（如"雷霆战队"）
  player1Id: Data_Id.t,           // 队员1
  player2Id: Data_Id.t,           // 队员2
  isBye: bool,                    // 是否为轮空占位队
  // 可选扩展
  initialLevel: Level.t,          // 起始级数（默认从2开始）
  rating: int,                    // 队伍等级分（可选）
}

// 轮空队伍常量
let bye: t = {
  id: Data_Id.teamBye,
  name: "[轮空]",
  player1Id: Data_Id.noPlayer,
  player2Id: Data_Id.noPlayer,
  isBye: true,
  initialLevel: Two,
  rating: 0,
}
```

**改动说明**：队伍取代选手成为参赛单元。轮空不再是一个特殊的"选手"，而是特殊的"队伍"。

### 3.3 级数体系 `Data_Level.res` — 新增模块

```rescript
type t = Two | Three | Four | Five | Six
        | Seven | Eight | Nine | Ten
        | Jack | Queen | King | Ace  // Ace = A

let toInt = x =>
  switch x {
  | Two => 2 | Three => 3 | Four => 4 | Five => 5
  | Six => 6 | Seven => 7 | Eight => 8 | Nine => 9
  | Ten => 10 | Jack => 11 | Queen => 12 | King => 13 | Ace => 14
  }

let fromInt = x =>
  switch x {
  | 2 => Two | 3 => Three | 4 => Four | 5 => Five
  | 6 => Six | 7 => Seven | 8 => Eight | 9 => Nine
  | 10 => Ten | 11 => Jack | 12 => Queen | 13 => King
  | 14 | _ => Ace
  }

let toString = x =>
  switch x {
  | Two => "2" | Three => "3" | Four => "4" | Five => "5"
  | Six => "6" | Seven => "7" | Eight => "8" | Nine => "9"
  | Ten => "10" | Jack => "J" | Queen => "Q" | King => "K" | Ace => "A"
  }

let levelDiff = (a, b) => toInt(a) - toInt(b)
```

### 3.4 比赛 `Data_Match.res` — 完全重写

当前是 1v1（whiteId vs blackId），改为 2v2 队伍对战。

```rescript
module Result = {
  type t = {
    team1Level: Level.t,       // 队伍1本局打到的最终级数
    team2Level: Level.t,       // 队伍2本局打到的最终级数
    winner: option<winner>,    // 胜者：Team1 | Team2 | None(平局)
  }
  
  type winner = Team1 | Team2
  
  // 级差 = 队伍1级数 - 队伍2级数（正值=队1领先）
  let calcDiff = (result: t): int =>
    Level.toInt(result.team1Level) - Level.toInt(result.team2Level)
    
  // 净积小分 = 己方级数 - 对方级数
  let calcNetSmallScore = (myLevel: int, opponentLevel: int): int =>
    myLevel - opponentLevel
    
  // 累积小分 = (己方级数 - 2) + 过A加分
  // 过A者另加1分
  let calcCumulativeSmallScore = (level: Level.t): int => {
    let base = Level.toInt(level) - 2  // 从2开始算
    switch level {
    | Ace => base + 1  // 过A另加1分
    | _ => base
    }
  }
}

type t = {
  id: Id.t,
  team1Id: Id.t,
  team2Id: Id.t,
  result: Result.t,
  tableNumber: option<int>,    // 桌号
  // 比赛时限（分钟），0表示无限制
  timeLimitMinutes: option<int>,
}
```

**改动说明**：删除所有 `whiteId/blackId`、`whiteOrigRating/blackOrigRating`、`whiteNewRating/blackNewRating`、`swapColors` 等象棋特有字段和函数。新增小分计算逻辑和时限字段。

### 3.5 轮次 `Data_Rounds.res` — 适配新 Match

```rescript
module Round = {
  type t = array<Match.t>
  
  // 获取本轮所有参赛队伍的ID
  let getMatched = (round: t) => {
    let q = MutableQueue.make()
    Array.forEach(round, ({team1Id, team2Id, _}) => {
      MutableQueue.add(q, team1Id)
      MutableQueue.add(q, team2Id)
    })
    MutableQueue.toArray(q)
  }
  
  // ... 其余操作类似，字段名从 whiteId/blackId 改为 team1Id/team2Id
}

type t = array<Round.t>

let isRoundComplete = (roundList, teams, roundId) =>
  switch roundList[roundId] {
  | Some(round) =>
    if roundId < Array.size(roundList) - 1 {
      true
    } else {
      let matched = Round.getMatched(round)
      let unmatched = Map.removeMany(teams, matched)
      let results = Array.map(round, match => match.result.winner)
      Map.size(unmatched) == 0 && !Js.Array2.includes(results, None)
    }
  | None => true
  }
```

### 3.6 计分系统 `Data_Scoring.res` — 完全重写

**核心逻辑**（参照《掼蛋（国家）竞赛规则（2017版）》及南山杯2026规则）：

- **场分（Field Score）**：胜方得 3 分，打平各得 2 分，负方得 1 分
- **小分（Small Score）**：用于破同分的二级指标，分净积小分和累积小分两种

```rescript
// 场分常量
module FieldScore = {
  let win = 3.0
  let draw = 2.0
  let lose = 1.0
  let absent = 0.0  // 缺席判负，对手自动获3分
  let bye = 3.0     // 轮空队伍自动获3分（视同获胜）
}

// 队伍计分记录
type t = {
  teamId: Id.t,
  // 场分
  results: list<float>,              // 各局获得的场分
  totalFieldScore: float,            // 总场分（排名第一依据）
  // 小分统计
  totalNetSmallScore: int,           // 总净积小分 = Σ(己方级数 - 对方级数)
  totalCumulativeSmallScore: int,    // 总累积小分 = Σ(己方级数 - 2 + 过A加分)
  // 对阵记录（用于相互胜负关系破同分）
  opponentResults: list<(Id.t, MatchResult.result)>,  // (对手队ID, 比赛结果)
  // 按轮次的累计（用于破同分）
  cumulativeFieldScores: list<float>, // 每轮后的累计场分
  // 轮空标记
  byeCount: int,
}

module MatchResult = {
  type result =
    | Win
    | Lose
    | Draw
  
  // 根据级数和过A判定比赛结果
  let determine = (team1Level: Level.t, team2Level: Level.t): (result, result) => {
    let l1 = Level.toInt(team1Level)
    let l2 = Level.toInt(team2Level)
    if l1 > l2 {
      (Win, Lose)
    } else if l2 > l1 {
      (Lose, Win)
    } else {
      (Draw, Draw)
    }
  }
  
  // 场分计算（胜3/平2/负1/缺席0）
  let toFieldScore = (result: result): float =>
    switch result {
    | Win => FieldScore.win
    | Draw => FieldScore.draw
    | Lose => FieldScore.lose
    }
}

/**
 * 小分计算函数。
 *
 * 净积小分 = 己方级数 - 对方级数
 *   例：A队打K(13)，B队打8 → A净积小分=13-8=5，B净积小分=8-13=-5
 *
 * 累积小分 = (己方级数 - 2) + 过A加分
 *   2是起始级数（2不必打，但计算从小分累积时以2为基准）
 *   例：A队打K(13) → 累积小分=13-2=11；B队打8 → 累积小分=8-2=6
 *   过A者另加1分：如打到A(14) → 累积小分=14-2+1=13
 */
module SmallScore = {
  // 单场净积小分
  let netSmallScore = (myLevel: int, opponentLevel: int): int =>
    myLevel - opponentLevel
    
  // 单场累积小分
  let cumulativeSmallScore = (level: Level.t): int => {
    let base = Level.toInt(level) - 2
    switch level {
    | Ace => base + 1  // 过A另加1分
    | _ => base
    }
  }
}
```

**破同分规则**（按优先级递减，参照南山杯2026附录一）：

```rescript
module TieBreak = {
  type t =
    | TotalFieldScore      // 1. 总积分（场分总和）
    | DirectEncounter      // 2. 相互胜负关系
    | NetSmallScore        // 3. 净积小分（总净积小分）
    | CumulativeSmallScore // 4. 累积小分（总累积小分）
    // 5. 若仍无法区分，抽签决定（程序外操作）

  let toPrettyString = x =>
    switch x {
    | TotalFieldScore => "总积分"
    | DirectEncounter => "相互胜负"
    | NetSmallScore => "净积小分"
    | CumulativeSmallScore => "累积小分"
    }
    
  let defaultOrder = [TotalFieldScore, DirectEncounter, NetSmallScore, CumulativeSmallScore]
}
```

### 3.7 锦标赛 `Data_Tournament.res` — 重写

```rescript
// 赛事阶段类型
module Phase = {
  type t =
    | Swiss(int)        // 瑞士移位赛（n轮）
    | RoundRobin(int)   // 小组循环赛（n队/组）
    | SingleElimination // 淘汰赛
    | Final             // 决赛

  let toPrettyString = x =>
    switch x {
    | Swiss(n) => "瑞士移位赛(" ++ Belt.Int.toString(n) ++ "轮)"
    | RoundRobin(n) => "小组循环赛(" ++ Belt.Int.toString(n) ++ "队/组)"
    | SingleElimination => "淘汰赛"
    | Final => "决赛"
    }
}

type t = {
  id: Data_Id.t,
  name: string,
  date: Js.Date.t,
  phase: Phase.t,                    // 赛事阶段
  teamIds: Data_Id.Set.t,            // 参赛队伍集合
  byeQueue: array<Data_Id.t>,        // 轮空队列
  tieBreaks: array<TieBreak.t>,      // 破同分规则（默认4级）
  roundList: Data_Rounds.t,
  timeLimitMinutes: int,             // 每局限时（分钟），海选/小组70，淘汰/决赛120
  // 删除：playerIds, scoreAdjustments, scoreTable
}
```

### 3.8 配对引擎 `Data_Pairing.res` — 简化重写

```rescript
type team = {
  id: Id.t,
  avoidIds: Id.Set.t,         // 回避队伍
  opponents: list<Id.t>,      // 已对阵过的队伍
  score: float,               // 当前场分
  totalLevelDiff: int,        // 总级差
  halfPos: int,
  isUpperHalf: bool,
}

type t = {
  teams: Id.Map.t<team>,
  maxScore: float,
  maxPriority: float,
}

// 配对优先级（大幅简化，去掉颜色平衡维度）
let priority = (~canMeet, ~scoreDiff, ~isDiffHalf, ~halfPosDiff, ~maxScore) => {
  let halves = isDiffHalf ? 4. /. (halfPosDiff +. 1.) : 0.
  let scores = maxScore *. 16. -. scoreDiff *. 16.
  let canMeet = canMeet ? 32. *. maxScore : 0.
  halves +. scores +. canMeet
}

// 分配轮空（按场分最低优先）
let setByeTeam = (byeQueue, dummyId, data: t) => {
  switch mod(Map.size(data.teams), 2) {
  | exception Division_by_zero => (data, None)
  | 0 => (data, None)
  | _ =>
    // 在场分最低的组中，选登记最早的队伍轮空
    let sorted = data.teams
    ->Map.valuesToArray
    ->SortArray.stableSortBy((a, b) => 
      switch compare(a.score, b.score) {
      | 0 => compare(byeQueue->Array.findIndex(Id.eq(a.id)), 
                     byeQueue->Array.findIndex(Id.eq(b.id)))
      | x => x
      }
    )
    let byeTeam = sorted[0]
    let teams = switch byeTeam {
    | Some(t) => Map.remove(data.teams, t.id)
    | None => data.teams
    }
    ({...data, teams}, byeTeam)
  }
}

// 配对主逻辑：Blossom最大权匹配
let pairTeams = ({teams, maxScore, _}) => {
  // 与原版类似，但 calcPairIdeal 中去掉 colorScore/lastColor 维度
  // 输出结果为 (team1Id, team2Id) 二元组，不再分配"颜色"
  // ...
}
```

### 3.9 全局配置 `Data_Config.res` — 简化

```rescript
type t = {
  avoidTeamPairs: Data_Id.Pair.Set.t,   // 队伍回避对
  lastBackup: Js.Date.t,
  defaultTieBreaks: array<TieBreak.t>,   // 默认破同分规则
  // 删除：byeValue, whiteAlias, blackAlias, defaultScoreTable
}
```

---

## 四、数据库层改造 `src/Db.res`

### 表结构变更

| 表名 | 当前 | 目标 |
|------|------|------|
| `players` | 选手（含 rating/matchCount/type_） | 选手（仅身份信息） |
| `teams` | — 不存在 | **新增**：队伍信息 |
| `tournaments` | 含 playerIds/scoreAdjustments | 改为 teamIds |
| `matches` | 含 whiteId/blackId/ratings | 改为 team1Id/team2Id/levelResult |
| `config` | 含 whiteAlias/blackAlias/byeValue | 改为 scoreTable/tieBreaks |

### 新增接口

```rescript
// 队伍 CRUD
let getAllTeams: unit => promise<Id.Map.t<Team.t>>
let getTeam: Id.t => promise<option<Team.t>>
let setTeam: Team.t => promise<unit>
let delTeam: Id.t => promise<unit>

// 按赛事获取队伍
let getTeamsForTournament: tournamentId => promise<Id.Map.t<Team.t>>
```

---

## 五、UI页面改造

### 5.1 选手管理 `src/PagePlayers.res`

- **简化**：去掉等级分、回避列表等象棋特有功能
- **新增**：选手列表仅显示姓名，用于队伍组建时选择

### 5.2 队伍管理 — 新增页面/组件

- 队伍列表（名称 + 队员1 + 队员2）
- 创建队伍（从选手库中选择2名选手）
- 编辑/删除队伍
- 支持队伍级等级分（可选）

### 5.3 锦标赛创建 `src/PageTournament/PageTourneySetup.res`

- 赛事名称（保留）
- 赛事阶段选择：瑞士移位制 / 小组循环赛
- 轮数设置（瑞士制：3~4 轮，小组赛：3 轮）
- 每局限时（海选/小组：70 分钟，淘汰/决赛：120 分钟）
- 破同分规则确认（默认按附录一四级规则）
- 参赛队伍选择（多选）

### 5.4 锦标赛队伍 `src/PageTournament/PageTourneyPlayers.res` — 替代原 PageTourneyPlayers

- 以**队伍**为添加/移除单元
- 每支队伍显示：队名 + 队员A + 队员B
- 支持添加[轮空]队伍

### 5.5 配对页面 `src/PageRound.res`

- **右侧栏"未配对队伍"**：显示未配对的队伍卡片（含队员信息）
- **右侧栏"已配对比赛"**：每场比赛显示 队伍A vs 队伍B
- 自动配对按钮："自动配对未匹配队伍"
- 手动配对：点击"添加"按钮选择队伍
- 取消配对：显示在已配对的比赛中

### 5.6 比赛结果录入

每场比赛的结果录入区域包含：

```
┌─────────────────────────────────────────────────┐
│  队伍A (张三 / 李四)  vs  队伍B (王五 / 赵六)     │
│                                                 │
│  队伍A 最终级数: [K ▼]    队伍B 最终级数: [8 ▼]  │
│  级差: +5 (队伍A领先)                            │
│                                                 │
│  判定: 队伍A 胜 → 队伍A 得 3 分，队伍B 得 1 分   │
│        队伍A 净积小分 +5   累积小分 11            │
│        队伍B 净积小分 -5   累积小分 6             │
│                                                 │
│  桌号: [__]    限时: [70] 分钟                   │
│  [ ] 缺席（队伍B未到场，队伍A自动获胜）           │
└─────────────────────────────────────────────────┘
```

- 级数从下拉菜单选择（2/3/4/5/6/7/8/9/10/J/Q/K/A）
- 级差值自动计算并显示
- 场分自动判定（胜3/平2/负1），不可手动修改
- 净积小分和累积小分自动计算并显示
- 支持标记缺席（缺席队伍得0分，对手自动3分）

### 5.7 积分榜 `src/PageTournament/PageTournamentStatus.res`

显示字段：

| 排名 | 队伍 | 队员 | 场分 | 净积小分 | 累积小分 |
|------|------|------|------|---------|---------|
| 1 | 雷霆队 | 张三/李四 | 9 | +15 | 33 |
| 2 | 火箭队 | 王五/赵六 | 7 | +8 | 24 |

排序规则：总积分 → 相互胜负 → 净积小分 → 累积小分

- **删除**：白方/黑方相关信息、棋赛特有统计、对手分
- **新增**：净积小分、累积小分列
- **交互**：同分队可点击展开查看相互胜负详情

### 5.8 选项页 `src/PageOptions.res`

- **删除**：白方别名、黑方别名、轮空分值
- **新增**：默认破同分规则顺序调整

### 5.9 对阵选择器 `src/PairPicker.res`

- 从选择2名选手改为选择2支队伍
- 队伍卡片显示成员信息
- **删除**：预选胜者逻辑

---

## 六、掼蛋计分细则

> 以下规则参照南山杯 Aotearoa 掼蛋大赛指南（2026）及《掼蛋（国家）竞赛规则（2017版）》。

### 6.1 场分规则（排名第一依据）

| 比赛结果 | 胜方 | 负方 | 说明 |
|---------|------|------|------|
| 级数领先 | 3 分 | 1 分 | 限时结束时级数高的一方获胜 |
| 过A获胜 | 3 分 | 1 分 | 先打过A的一方为胜方（A必打） |
| 平级 | 2 分 | 2 分 | 限时结束时双方级数相同 |
| 对手缺席 | 3 分 | 0 分 | 缺席队伍得0分 |
| 轮空 | 3 分 | — | 轮空队伍自动获3分 |

**关键点**：
- 从 2 开始打，2 不必打，A 为必打
- 海选赛/小组赛每局限时 70 分钟，淘汰赛/决赛每局限时 120 分钟
- 淘汰赛/决赛 120 分钟内战平，加赛一副牌打 2，获得头游方获胜
- 打 A 时，必须有一家是头游且对家不是末游才最终获胜；累计 3 次 A 打不过去，退回 2 重打

### 6.2 小分规则（破同分二、三、四级指标）

#### 净积小分
```
净积小分 = 己方级数 - 对方级数
```
- 例：A 队打 K(13)，B 队打 8 → A 净积小分 = 13-8 = **+5**，B 净积小分 = 8-13 = **-5**
- 统计时取**各轮净积小分之和**（总净积小分）

#### 累积小分
```
累积小分 = (己方级数 - 2) + 过A加分
          其中 2 为起始级数基准，过A者另加 1 分
```
- 例：A 队打 K(13) → 累积小分 = 13-2 = **11**
- 例：A 队打过 A(14) → 累积小分 = 14-2+1 = **13**

### 6.3 破同分规则（优先级递减）

> 参照南山杯 2026 附录一。

| 优先级 | 指标 | 说明 | 判定方向 |
|--------|------|------|---------|
| 1 | **总积分** | 各轮场分之和 | 越大越好 |
| 2 | **相互胜负关系** | 同分队之间的直接对决结果 | 胜者优先 |
| 3 | **净积小分** | 各轮净积小分之和 | 越大越好 |
| 4 | **累积小分** | 各轮累积小分之和 | 越大越好 |
| 5 | **抽签** | 由组委会手动决定 | — |

**注**：3 队及以上总积分相同时，先比较净积小分，净积小分相同再比较累积小分。仅 2 队同分时，先看相互胜负关系。若仍无法区分，由组委会抽签（程序外操作）。

### 6.4 升级规则（附：规则体系）

掼蛋每局由多副牌组成，每副牌的结果决定级数升降：

| 本副牌结果 | 升/降级 | 说明 |
|-----------|---------|------|
| 双下（头游+二游） | 升 3 级 | 队友包揽前两名 |
| 对手一家末游 | 升 2 级 | 常规获胜 |
| 头游自己对门末游 | 升 1 级 | 仅获头游 |
| 双下（对手） | 对手升 3 级 | 本方全输 |

**进贡/抗贡**：
- 单下：末游向头游进贡最大牌（红心参谋除外），头游还一张 ≤10 的牌
- 双下：两末游向两胜方分别进贡，头游拿大牌，二游拿小牌
- 抗贡：末游抓到两个大王则不进贡，由头游先出牌

> **注意**：级数上升是掼蛋牌局内部的机制，锦标赛管理工具只需记录每场比赛双方**最终打到的级数**，内部每副牌的升降过程由现场裁判和选手自行处理。

### 6.5 违规与判罚（参考）

| 违规类型 | 判罚 |
|---------|------|
| 迟到 | 每迟到 5 分钟，对手升 1 级 |
| 越序出牌/抓牌（首次） | 退回，不罚 |
| 越序抓牌（累计 3 次） | 本局降 1 级 |
| 藏牌 | 对手升 3 级；累计 3 次视对手本局获胜 |
| 非法信息传递（累计 3 次） | 视对手本局获胜 |
| 超时出牌（第 3 次起） | 每次对手升 1 级 |
| 进贡小牌 | 对手升 2 级 |

> **注意**：违规判罚结果会体现在最终级数上（如对手升 N 级），工具通过录入的最终级数间接反映判罚结果，不单独记录判罚事件。

---

## 七、赛事类型

> 参照南山杯 2026 赛程：海选赛（瑞士移位制）→ 小组赛（单循环）→ 淘汰赛 → 决赛。

| 阶段 | 赛制 | 轮数 | 每局限时 | 晋级规则 |
|------|------|------|---------|---------|
| 海选赛 | 瑞士移位制 | 3~4 轮 | 70 分钟 | 前 32 名晋级小组赛 |
| 小组赛 | 单循环（4 队/组） | 3 轮 | 70 分钟 | 每组前 2 名（共 16 队）晋级淘汰赛 |
| 淘汰赛 | 单败淘汰 | 2 轮（16→8→4） | 120 分钟 | 胜者晋级，加赛打 2 头游胜 |
| 决赛 | 半决赛 + 决赛 | 2 轮 | 120 分钟 | 胜者晋级，加赛打 2 头游胜 |

**第一阶段实现**：瑞士移位制 + 单循环小组赛（覆盖海选和小组两个阶段），后续扩展淘汰赛。

**关键实现差异**：
- 瑞士制：需要配对算法（Blossom）按场分分组配对
- 单循环：预生成固定对阵表，无需配对算法，但需要同分破同分排序
- 淘汰赛：二叉树对阵表 + 种子排序，平局加赛判定

---

## 八、实施路线图

### 阶段A：核心数据模型（约55%工作量）

| 序号 | 任务 | 文件 |
|------|------|------|
| 1 | 新增级数体系模块 | `Data_Level.res` + `.resi` |
| 2 | 新增队伍模型 | `Data_Team.res` + `.resi` |
| 3 | 简化选手模型 | `Data_Player.res` + `.resi` |
| 4 | 重写比赛模型 | `Data_Match.res` + `.resi` |
| 5 | 重写计分系统 | `Data_Scoring.res` + `.resi` |
| 6 | 重写配对引擎 | `Data_Pairing.res` + `.resi` |
| 7 | 重写轮次模型 | `Data_Rounds.res` + `.resi` |
| 8 | 重写锦标赛模型 | `Data_Tournament.res` + `.resi` |
| 9 | 简化全局配置 | `Data_Config.res` + `.resi` |
| 10 | 更新 Data 汇总导出 | `Data.res` |
| 11 | 改造数据库层 | `Db.res` |

### 阶段B：UI改造（约35%工作量）

| 序号 | 任务 | 文件 |
|------|------|------|
| 12 | 队伍管理页面 | 新建队伍管理组件 |
| 13 | 简化选手管理 | `PagePlayers.res` |
| 14 | 锦标赛设置（掼蛋） | `PageTournament/PageTourneySetup.res` |
| 15 | 锦标赛队伍管理 | `PageTournament/PageTourneyPlayers.res` |
| 16 | 配对界面（队伍版） | `PageTournament/PageRound.res` |
| 17 | 比赛结果录入 | `PageTournament/PageTourneyScores.res` |
| 18 | 积分榜 | `PageTournament/PageTournamentStatus.res` |
| 19 | 对阵选择器 | `PageTournament/PairPicker.res` |
| 20 | 选项/配置页 | `PageOptions.res` |
| 21 | 负载数据 | `PageTournament/LoadTournament.res` |
| 22 | 统计工具 | `PageTournament/TournamentUtils.res` |
| 23 | 帮助文案 | `HelpDialogs.res` |
| 24 | 窗口标题/路由 | `Window.res`, `Pages.res` |

### 阶段C：测试与打磨（约10%工作量）

| 序号 | 任务 | 文件 |
|------|------|------|
| 25 | 重写 Match 测试 | `tests/Match_test.res` |
| 26 | 重写 Scoring 测试 | `tests/Scoring_test.res` |
| 27 | 重写 Pairing 测试 | `tests/Pairing_test.res` |
| 28 | 重写 轮次面板测试 | `tests/RoundPanels_test.res` |
| 29 | 新增 Team 测试 | `tests/Team_test.res` |
| 30 | 更新选手测试 | `tests/PagePlayers_test.res` |
| 31 | 更新锦标赛列表测试 | `tests/PageTournamentList_test.res` |
| 32 | 更新锦标赛选手测试 | `tests/PageTournamentPlayers_test.res` |
| 33 | 更新测试数据 | `testutils/TestData.res` |
| 34 | 编译验证 + 快照更新 | 全量构建 |
| 35 | 页面标题/描述 | `index.html`, `package.json`, `README.md` |

---

## 九、文件改动总清单

### 新增文件（4个）
```
src/Data/Data_Level.res
src/Data/Data_Level.resi
src/Data/Data_Team.res
src/Data/Data_Team.resi
tests/Team_test.res
tests/Team_test.resi
```

### 重写文件（改动 > 70%，11个）
```
src/Data/Data_Match.res + .resi
src/Data/Data_Scoring.res + .resi
src/Data/Data_Pairing.res + .resi
src/Data/Data_Rounds.res + .resi
src/Data/Data_Tournament.res + .resi
src/Data/Data_Config.res + .resi
tests/Scoring_test.res
tests/Pairing_test.res
tests/Match_test.res
tests/RoundPanels_test.res
```

### 大幅修改文件（改动 30-70%，13个）
```
src/Data/Data.res
src/Data/Data_Player.res + .resi
src/Db.res
src/PageTournament/PageTourneySetup.res
src/PageTournament/PageTourneyPlayers.res
src/PageTournament/PageRound.res
src/PageTournament/PageTourneyScores.res
src/PageTournament/PageTournamentStatus.res
src/PageTournament/PairPicker.res
src/PageTournament/TournamentUtils.res
src/PageTournament/LoadTournament.res
src/PageOptions.res
src/Hooks.res
```

### 局部修改文件（改动 < 30%，12个）
```
src/Pages.res
src/Window.res
src/HelpDialogs.res
src/PagePlayers.res
src/PageTournamentList.res
src/PageTournament/PageTourney.res
index.html
package.json
README.md
docs/faq.md
testutils/TestData.res
testutils/ReactTestingLibrary.res（如需要）
```

---

## 十、关键技术决策

### 10.1 轮空实现
轮空不再通过特殊的"轮空选手"来实现，而是队伍级别的概念：
- 当队伍数为奇数时，一支队伍轮空
- 轮空队伍自动获得场分 3 分（等同获胜）
- 轮空不产生小分（净积小分、累积小分均为 0）
- 轮空优先级：已轮空过的队伍排在轮空队列末尾

### 10.2 配对算法简化
去掉颜色平衡逻辑后，配对算法（仅瑞士移位制需要）的权重维度变为：
1. **避免已对阵过**：最高权重（不可相遇）
2. **场分相近**：第二权重（同分优先配对）
3. **上下半区交叉**：第三权重（同分组内交叉配对）

小组循环赛使用预生成固定对阵表，淘汰赛使用二叉树对阵 + 种子排位，均不需要配对算法。

### 10.3 ID 体系
```
Data_Id.t（通用ID）:
  - 选手ID: 普通随机ID
  - 队伍ID: 普通随机ID
  - 锦标赛ID: 普通随机ID
  - 比赛ID: 普通随机ID
  - teamBye: 特殊固定值（用于标识轮空队伍）
  - noPlayer: 特殊固定值（轮空队伍的占位选手ID）
```

### 10.4 数据存储
- 选手和队伍分开存储（两个 LocalForage store）
- 旧数据不做迁移，首次启动时如果检测到旧格式数据，提示用户清空
- 或在 Db 模块初始化时自动清空旧数据并新建

---

## 十一、注意事项

1. **ReScript 编译**：改动涉及约 40 个文件，建议逐模块改造、逐模块编译通过，避免一次性改动后出现大量类型错误难以定位。

2. **UI 布局**：4 人对战的信息密度更高，比赛卡片和结果录入需要重新设计布局，注意移动端适配。

3. **测试数据**：`testutils/TestData.res` 需要完全重写，新的测试数据需要包含队伍、级数、掼蛋比赛场景。

4. **快照测试**：所有包含 UI 的快照测试都需要更新。

5. **CI/CD**：`netlify.toml` 和 `vite.config.js` 无需修改。

6. **第三方依赖**：
   - `rescript-blossom`：保留（配对算法仍使用 Blossom）
   - `numeral`：保留（积分显示格式化）
   - `localforage`：保留（数据持久化）
   - 无需新增依赖

7. **语言**：全部界面文案使用中文，级数名称可采用中文缩写或字母（2-9, 10, J, Q, K, A）。
