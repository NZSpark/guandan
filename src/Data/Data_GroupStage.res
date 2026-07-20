/*
  小组赛配对引擎 — 蛇形分组 + 单循环（圈圈法）。
  参照南山杯 Aotearoa 掼蛋大赛指南（2026）。

  规则：
  - 蛇形排位分组（按积分高低）
  - 同一俱乐部/社团的队伍尽量分到不同组
  - 每组内进行单循环（每两队之间对阵一次）
  - 组内对阵轮次安排中，同一俱乐部的队伍尽量错开
*/
open! Belt
module Id = Data_Id
module Scoring = Data_Scoring

/** 分组后的队伍信息 */
type groupTeam = {
  teamId: Id.t,
  club: string,
  score: float,
}

/** 一组队伍：按 seedIndex 映射的队伍列表 */
type group = array<groupTeam>

/** 计算各组应有多少支队伍 */
let calcGroupSizes = (teamCount: int, groupCount: int): array<int> => {
  let baseSize = teamCount / groupCount
  let remainder = teamCount - baseSize * groupCount
  Array.makeBy(groupCount, i => baseSize + (i < remainder ? 1 : 0))
}

/** 计算理想分组数（每组 4 队） */
let idealGroupCount = (teamCount: int): int => max(1, teamCount / 4)

/** 计算一组内的俱乐部冲突数 */
let countClubConflicts = (grp: array<groupTeam>): int => {
  let total = ref(0)
  for i in 0 to Array.length(grp) - 1 {
    let team = Array.getUnsafe(grp, i)
    if team.club != "" {
      for j in i + 1 to Array.length(grp) - 1 {
        if Array.getUnsafe(grp, j).club == team.club {
          total.contents = total.contents + 1
        }
      }
    }
  }
  total.contents
}

/** 计算所有组的总冲突数 */
let totalConflicts = (groups: array<array<groupTeam>>): int => {
  Array.reduce(groups, 0, (acc, g) => acc + countClubConflicts(g))
}

/**
  蛇形排位分组：按积分从高到低，蛇形分配到各组。
  然后做组间交换以尽量将同俱乐部队伍分散到不同组。
*/
let snakeDistribute = (teams: array<groupTeam>, groupCount: int): array<group> => {
  let n = Array.length(teams)
  if n == 0 || groupCount <= 0 {
    []
  } else {
    /* 按积分降序排序 */
    let sorted = Belt.SortArray.stableSortBy(Array.copy(teams), (a, b) => compare(b.score, a.score))

    /* 蛇形分配：预计算每个队伍应该去哪个组 */
    let groupOf = Array.makeBy(n, i => {
      let cycle = i / groupCount
      let posInCycle = i - cycle * groupCount
      if cycle / 2 * 2 != cycle {
        groupCount - 1 - posInCycle
      } else {
        posInCycle
      }
    })

    /* 根据预计算结果构建分组（不可变方式） */
    let initialGroups = Array.makeBy(groupCount, gIdx =>
      sorted
      ->Array.mapWithIndex((i, team) => (team, Array.getUnsafe(groupOf, i)))
      ->Array.keep(((_, g)) => g == gIdx)
      ->Array.map(((team, _)) => team)
    )

    /* 同俱乐部冲突交换优化 */
    let groupsRef = ref(initialGroups)
    let maxIters = n * 2
    for _iter in 0 to maxIters - 1 {
      let current = groupsRef.contents
      let improved = ref(false)

      for g1 in 0 to groupCount - 1 {
        if !improved.contents {
          for g2 in g1 + 1 to groupCount - 1 {
            if !improved.contents {
              let grp1 = Array.getUnsafe(current, g1)
              let grp2 = Array.getUnsafe(current, g2)
              let len1 = Array.length(grp1)
              let len2 = Array.length(grp2)

              for i1 in 0 to len1 - 1 {
                if !improved.contents {
                  let t1 = Array.getUnsafe(grp1, i1)
                  if t1.club != "" && countClubConflicts(grp1) > 0 {
                    for i2 in 0 to len2 - 1 {
                      if !improved.contents {
                        let t2 = Array.getUnsafe(grp2, i2)
                        if t2.club != "" && countClubConflicts(grp2) > 0 {
                          /* Try swap: build new groups with teams swapped */
                          let swappedGrp1 = Array.makeBy(len1, j =>
                            if j == i1 { t2 } else { Array.getUnsafe(grp1, j) }
                          )
                          let swappedGrp2 = Array.makeBy(len2, j =>
                            if j == i2 { t1 } else { Array.getUnsafe(grp2, j) }
                          )

                          let newGroups = Array.makeBy(groupCount, gIdx =>
                            if gIdx == g1 { swappedGrp1 }
                            else if gIdx == g2 { swappedGrp2 }
                            else { Array.getUnsafe(current, gIdx) }
                          )

                          if totalConflicts(newGroups) < totalConflicts(current) {
                            groupsRef.contents = newGroups
                            improved.contents = true
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
      if !improved.contents {
        /* No more improvements possible, break early */
        ()
      }
    }
    groupsRef.contents
  }
}

/**
  圈圈法（Circle Method）生成单循环轮次表。
  返回: array<array<(Id.t, Id.t)>>  每轮为对阵列表
*/
let roundRobinSchedule = (teamIds: array<Id.t>): array<array<(Id.t, Id.t)>> => {
  let n = Array.length(teamIds)
  if n < 2 {
    []
  } else {
    /* 奇数队时添加虚拟轮空位 */
    let hasBye = n / 2 * 2 != n
    let initialArr = if hasBye {
      Belt.Array.concatMany([Array.copy(teamIds), [Id.teamBye]])
    } else {
      Array.copy(teamIds)
    }
    let arrRef = ref(initialArr)
    let totalRounds = Array.length(arrRef.contents) - 1
    let half = Array.length(arrRef.contents) / 2

    Array.makeBy(totalRounds, _rnd => {
      let current = arrRef.contents
      let nArr = Array.length(current)
      let matchesRef = ref([])
      for i in 0 to half - 1 {
        let home = Array.getUnsafe(current, i)
        let away = Array.getUnsafe(current, nArr - 1 - i)
        if !Id.isTeamBye(home) && !Id.isTeamBye(away) {
          matchesRef.contents = Belt.Array.concatMany([matchesRef.contents, [(home, away)]])
        }
      }
      /* 旋转（固定第 0 位，其余顺时针旋转） */
      let newArr = Array.makeBy(nArr, j =>
        if j == 0 {
          Array.getUnsafe(current, 0)
        } else if j == 1 {
          Array.getUnsafe(current, nArr - 1)
        } else {
          Array.getUnsafe(current, j - 1)
        }
      )
      arrRef.contents = newArr
      matchesRef.contents
    })
  }
}

/**
  生成整个分组 + 小组赛对阵表。
  返回: groupedTeams（分组信息）, roundSchedule（每轮对阵列表）
*/
let generateSchedule = (
  teams: Id.Map.t<Data_Team.t>,
  scoreData: Id.Map.t<Scoring.t>,
  groupCount: int,
): (array<group>, array<array<(Id.t, Id.t)>>) => {
  /* 构建 groupTeam 数组 */
  let groupTeams =
    teams
    ->Map.toArray
    ->Array.map(((id, team)) => {
      let score = switch Map.get(scoreData, id) {
      | Some(s) => s.totalFieldScore
      | None => team.initialScore
      }
      {teamId: id, club: team.club, score}
    })

  /* 蛇形分组 */
  let groups = snakeDistribute(groupTeams, groupCount)

  /* 每组生成单循环赛程 */
  let allRoundMatches = {
    let maxRounds = {
      let getSize = g => {
        let s = Array.length(g)
        if s / 2 * 2 == s { s - 1 } else { s }
      }
      let lengths = Array.map(groups, getSize)
      Array.reduce(lengths, 0, (a, b) => a > b ? a : b)
    }

    Array.makeBy(maxRounds, round => {
      let listRef = ref([])
      Array.forEach(groups, g => {
        let teamIds = Array.map(g, gt => gt.teamId)
        let schedule = roundRobinSchedule(teamIds)
        if round < Array.length(schedule) {
          Array.forEach(Array.getUnsafe(schedule, round), pair => {
            listRef.contents = Belt.Array.concatMany([listRef.contents, [pair]])
          })
        }
      })
      listRef.contents
    })
  }

  (groups, allRoundMatches)
}

/** 计算总轮次数 */
let totalRounds = (group: group): int => {
  let s = Array.length(group)
  if s / 2 * 2 == s { s - 1 } else { s }
}
