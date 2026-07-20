/*
  淘汰赛配对引擎 — 种子排位 + 标准 bracket 模板。
  参照南山杯 Aotearoa 掼蛋大赛指南（2026）。

  规则：
  - 按积分排种子位（积分高的对积分低的）
  - 同一俱乐部/社团的队伍尽量分到不同半区和不同对阵
  - 支持 16 队 / 8 队 / 4 队
*/
open! Belt
module Id = Data_Id
module Scoring = Data_Scoring

type bracketSize = Sixteen | Eight | Four

type bracketEntry = {
  matchLabel: string,
  team1Id: Id.t,
  team2Id: Id.t,
}

/** 16 强模板：(种子1, 种子2, 标签) */
let template16: array<(int, int, string)> = [
  (1, 16, "上半区①"),
  (8, 9, "上半区②"),
  (5, 12, "上半区③"),
  (4, 13, "上半区④"),
  (3, 14, "下半区⑤"),
  (6, 11, "下半区⑥"),
  (7, 10, "下半区⑦"),
  (2, 15, "下半区⑧"),
]

/** 8 强模板 */
let template8: array<(int, int, string)> = [
  (1, 8, "上半区①"),
  (4, 5, "上半区②"),
  (3, 6, "下半区③"),
  (2, 7, "下半区④"),
]

/** 4 强模板 */
let template4: array<(int, int, string)> = [
  (1, 4, "半决赛①"),
  (2, 3, "半决赛②"),
]

/** 种子排位：按 score 降序 */
let seedTeams = (
  teams: Id.Map.t<Data_Team.t>,
  scoreData: Id.Map.t<Scoring.t>,
): array<Id.t> => {
  let scored = teams
  ->Map.toArray
  ->Array.map(((id, team)) => {
    let score = switch Map.get(scoreData, id) {
    | Some(s) => s.totalFieldScore
    | None => team.initialScore
    }
    (id, team.club, score)
  })
  let _ = scored->Belt.SortArray.stableSortBy(((_, _, a), (_, _, b)) => compare(b, a))
  Array.map(scored, ((id, _, _)) => id)
}

/** 从 seededIds 按种子号获取 teamId */
let getSeed = (seededIds: array<Id.t>, seedNum: int): Id.t => {
  let idx = seedNum - 1
  if idx >= 0 && idx < Array.length(seededIds) {
    Array.getUnsafe(seededIds, idx)
  } else {
    Id.teamBye
  }
}

/** 检测对阵中是否有同俱乐部冲突 */
let hasClubClash = (br: array<bracketEntry>, teams: Id.Map.t<Data_Team.t>, idx: int): bool => {
  let entry = Array.getUnsafe(br, idx)
  switch (Map.get(teams, entry.team1Id), Map.get(teams, entry.team2Id)) {
  | (Some(a), Some(b)) => a.club != "" && a.club == b.club
  | _ => false
  }
}

/** 计算 bracket 中同俱乐部冲突总数 */
let countClashes = (br: array<bracketEntry>, teams: Id.Map.t<Data_Team.t>): int => {
  let c = ref(0)
  for i in 0 to Array.length(br) - 1 {
    if hasClubClash(br, teams, i) { c.contents = c.contents + 1 }
  }
  c.contents
}

/**
  构建对阵表，并做同俱乐部错开优化。
  返回: array<bracketEntry> 按对阵顺序排列
*/
let buildBracket = (
  seededIds: array<Id.t>,
  teams: Id.Map.t<Data_Team.t>,
  size: bracketSize,
): array<bracketEntry> => {
  let template = switch size {
  | Sixteen => template16
  | Eight => template8
  | Four => template4
  }

  let n = Array.length(template)
  let half = n / 2

  /* 构建初始对阵（不可变） */
  let initialBracket = Array.mapWithIndex(template, (_, (s1, s2, label)) => {
    let t1 = getSeed(seededIds, s1)
    let t2 = getSeed(seededIds, s2)
    ({matchLabel: label, team1Id: t1, team2Id: t2} : bracketEntry)
  })

  /* 尝试交换以消除同俱乐部冲突（最多 20 次迭代，不可变） */
  let bracketRef = ref(initialBracket)
  for _iter in 0 to 20 - 1 {
    let current = bracketRef.contents

    /* 收集有冲突的索引 */
    let clashIdxsRef = ref([])
    for i in 0 to n - 1 {
      if hasClubClash(current, teams, i) {
        clashIdxsRef.contents = Belt.Array.concatMany([clashIdxsRef.contents, [i]])
      }
    }
    let clashIdxs = clashIdxsRef.contents

    if Array.length(clashIdxs) > 0 {
      let targetIdx = Array.getUnsafe(clashIdxs, 0)
      let target = Array.getUnsafe(current, targetIdx)
      let conflictTeam = target.team1Id
      let conflictClub = switch Map.get(teams, conflictTeam) {
      | Some(t) => t.club
      | None => ""
      }
      let conflictIsUpper = targetIdx < half

      /* 在对面的半区找可交换的队伍 */
      let swapped = ref(false)
      let start = conflictIsUpper ? half : 0
      let end_ = conflictIsUpper ? n : half
      for ti in start to end_ - 1 {
        if !swapped.contents {
          let source = Array.getUnsafe(current, ti)
          let club1 = switch Map.get(teams, source.team1Id) {
          | Some(t) => t.club
          | None => ""
          }
          if club1 != conflictClub && !Id.isTeamBye(source.team1Id) && !Id.isTeamBye(conflictTeam) {
            let oldClashes = countClashes(current, teams)

            /* 构建交换后的 bracket */
            let newBr = Array.makeBy(n, j =>
              if j == targetIdx {
                {matchLabel: target.matchLabel, team1Id: source.team1Id, team2Id: target.team2Id}
              } else if j == ti {
                {matchLabel: source.matchLabel, team1Id: conflictTeam, team2Id: source.team2Id}
              } else {
                Array.getUnsafe(current, j)
              }
            )

            let newClashes = countClashes(newBr, teams)
            if newClashes < oldClashes {
              bracketRef.contents = newBr
              swapped.contents = true
            }
          }
        }
      }
    }
  }

  /* 过滤掉轮空对阵 */
  bracketRef.contents->Array.keep(b => !Id.isTeamBye(b.team1Id) && !Id.isTeamBye(b.team2Id))
}

/** 从 teams 和 scoreData 生成完整淘汰赛对阵表 */
let generateBracket = (
  teams: Id.Map.t<Data_Team.t>,
  scoreData: Id.Map.t<Scoring.t>,
  size: bracketSize,
): array<bracketEntry> => {
  let seeded = seedTeams(teams, scoreData)
  let maxSize = switch size {
  | Sixteen => 16
  | Eight => 8
  | Four => 4
  }
  let selectedIds = if Array.length(seeded) > maxSize {
    Array.slice(seeded, ~offset=0, ~len=maxSize)
  } else {
    seeded
  }
  buildBracket(selectedIds, teams, size)
}
