/**
  多阶段赛事晋级逻辑。
  参照南山杯 Aotearoa 掼蛋大赛指南（2026）。

  流程：
  - 海选赛（Swiss）结束后，取积分榜前 N 名晋级小组赛
  - 小组赛（GroupStage）结束后，每组前 M 名晋级淘汰赛
  - 淘汰赛（Knockout）结束后，冠军产生
*/
module Id = Data_Id
module Scoring = Data_Scoring

/** 从海选赛积分数据中获取前N名队伍ID，按排名降序排列 */
let getSwissAdvancingTeams = (scoreData: Id.Map.t<Scoring.t>, advanceCount: int): array<Id.t> => {
  let standings = Scoring.createStandingArray(scoreData, Id.Map.make())
  let sortedIds = standings->Array.map(s => s.id)
  let take = min(advanceCount, Array.length(sortedIds))
  Array.slice(sortedIds, ~start=0, ~end=take)
}

/** 小组内队伍得分 */
type groupTeamScore = {
  teamId: Id.t,
  fieldScore: float,
  netSmallScore: int,
  cumSmallScore: int,
  wins: int,
  opponentResults: list<(Id.t, string)>,
}

/** 小组赛破同分比较：总积分 → 相互胜负 → 净积小分 → 累积小分 */
let compareGroupTeamScores = (a: groupTeamScore, b: groupTeamScore): int => {
  /* 先比场分（降序） */
  switch compare(b.fieldScore, a.fieldScore) {
  | 0 =>
    /* 相互胜负：检查 a 对 b 的战绩 */
    let aVsB = List.find(a.opponentResults, ((id, _)) => Id.eq(id, b.teamId))
    let bVsA = List.find(b.opponentResults, ((id, _)) => Id.eq(id, a.teamId))
    switch (aVsB, bVsA) {
    | (Some((_, "W")), _) => -1  /* a 胜 b */
    | (_, Some((_, "W"))) => 1   /* b 胜 a */
    | _ =>
      switch compare(b.netSmallScore, a.netSmallScore) {
      | 0 => compare(b.cumSmallScore, a.cumSmallScore)
      | x => x
      }
    }
  | x => x
  }
}

/** 计算小组赛各组的队伍排名。
  * 返回: array<array<groupTeamScore>>，每个组内按排名降序排列 */
let computeGroupStandings = (
  roundList: Data_Rounds.t,
  groupAssignments: Id.Map.t<int>,
  groupCount: int,
): array<array<groupTeamScore>> => {
  let allMatches = Data_Rounds.rounds2Matches(roundList)

  /* 使用现有的 Scoring.update 函数累积每个组内队伍得分 */
  let groupAccumulators = Array.fromInitializer(~length=groupCount, _ => Id.Map.make())

  Array.forEach(allMatches, match => {
    switch (Id.Map.get(groupAssignments, match.team1Id), Id.Map.get(groupAssignments, match.team2Id)) {
    | (Some(g1), Some(g2)) if g1 == g2 =>
      /* 同组比赛 — 纳入该组积分 */
      let groupIdx = g1
      let currScores = Array.getUnsafe(groupAccumulators, groupIdx)

      /* 计算场分和结果 */
      let isBye = Data_Match.isBye(match)
      let (team1Score, team2Score, team1Result, team2Result) = if isBye {
        if Id.isTeamBye(match.team1Id) {
          (Scoring.FieldScore.lose, Scoring.FieldScore.bye, "L", "W")
        } else {
          (Scoring.FieldScore.bye, Scoring.FieldScore.lose, "W", "L")
        }
      } else {
        (
          Data_Match.Result.fieldScoreForTeam(match.result, true),
          Data_Match.Result.fieldScoreForTeam(match.result, false),
          Data_Match.Result.resultForTeam(match.result, true),
          Data_Match.Result.resultForTeam(match.result, false),
        )
      }
      let net1 = Data_Level.netSmallScore(match.result.team1Level, match.result.team2Level)
      let net2 = Data_Level.netSmallScore(match.result.team2Level, match.result.team1Level)
      let cum1 = Data_Level.cumulativeSmallScore(match.result.team1Level)
      let cum2 = Data_Level.cumulativeSmallScore(match.result.team2Level)

      let updated = currScores
      ->Id.Map.update(match.team1Id, Scoring.update(
        _,
        ~teamId=match.team1Id,
        ~fieldScore=team1Score,
        ~netSmall=net1,
        ~cumSmall=cum1,
        ~oppId=match.team2Id,
        ~resultStr=team1Result,
      ))
      ->Id.Map.update(match.team2Id, Scoring.update(
        _,
        ~teamId=match.team2Id,
        ~fieldScore=team2Score,
        ~netSmall=net2,
        ~cumSmall=cum2,
        ~oppId=match.team1Id,
        ~resultStr=team2Result,
      ))

      let _ = Array.setUnsafe(groupAccumulators, groupIdx, updated)
    | _ => ()  /* 不同组或未分配组 — 跳过 */
    }
  })

  /* 每个组内将累积分数转为排序后的 groupTeamScore 数组 */
  Array.fromInitializer(~length=groupCount, gIdx => {
    let scores = Array.getUnsafe(groupAccumulators, gIdx)
    scores
    ->Id.Map.map(({teamId, totalFieldScore, totalNetSmallScore, totalCumulativeSmallScore, wins, opponentResults, _}) => {
      teamId,
      fieldScore: totalFieldScore,
      netSmallScore: totalNetSmallScore,
      cumSmallScore: totalCumulativeSmallScore,
      wins,
      opponentResults,
    })
    ->Id.Map.valuesToArray
    ->Utils.Array.toSortedByInt(compareGroupTeamScores)
  })
}

/** 从小组赛数据中获取每组前perGroup名队伍ID。
  * 返回按交叉对阵顺序排列的队伍ID列表，可直接用于淘汰赛种子排位。
  *
  * 排列规则（8组每组前2名 → 16队）：
  *   上半区: A1, B2, C1, D2, E1, F2, G1, H2
  *   下半区: B1, A2, D1, C2, F1, E2, H1, G2 */
let getGroupAdvancingTeams = (
  roundList: Data_Rounds.t,
  groupAssignments: Id.Map.t<int>,
  groupCount: int,
  ~perGroup: int,
): array<Id.t> => {
  let standingsPerGroup = computeGroupStandings(roundList, groupAssignments, groupCount)

  /* 提取每组前 perGroup 名 */
  let groupTops = Array.map(standingsPerGroup, groupScores =>
    Array.slice(groupScores, ~start=0, ~end=min(perGroup, Array.length(groupScores)))
  )

  /* 按交叉对阵顺序排列，上半区: (组0第1, 组1第2, 组2第1, 组3第2, ...) */
  let upperHalfRef = ref([])
  let lowerHalfRef = ref([])

  for i in 0 to groupCount - 1 {
    let idx = i
    let tops = Array.getUnsafe(groupTops, idx)
    let first = tops[0]
    let second = tops[1]

    if idx / 2 * 2 == idx {
      /* 偶数索引组: 第1名上半区，第2名下半区 */
      switch first {
      | Some(f) => upperHalfRef.contents = Array.concat(upperHalfRef.contents, [f])
      | None => ()
      }
      switch second {
      | Some(s) => lowerHalfRef.contents = Array.concat(lowerHalfRef.contents, [s])
      | None => ()
      }
    } else {
      /* 奇数索引组: 第1名下半区，第2名上半区 */
      switch first {
      | Some(f) => lowerHalfRef.contents = Array.concat(lowerHalfRef.contents, [f])
      | None => ()
      }
      switch second {
      | Some(s) => upperHalfRef.contents = Array.concat(upperHalfRef.contents, [s])
      | None => ()
      }
    }
  }

  /* 合并: 上半区 + 下半区 */
  Array.concat(
    Array.map(upperHalfRef.contents, s => s.teamId),
    Array.map(lowerHalfRef.contents, s => s.teamId),
  )
}

/** 从 GroupStage.generateSchedule 返回的 groups 构建 groupAssignments */
let groupAssignmentsFromGroups = (
  groups: array<Data_GroupStage.group>,
  activeTeams: Id.Map.t<Data_Team.t>,
): Id.Map.t<int> => {
  let resultRef = ref(Id.Map.make())
  Array.forEachWithIndex(groups, (group, gIdx) => {
    Array.forEach(group, (gt: Data_GroupStage.groupTeam) => {
      if Id.Map.has(activeTeams, gt.teamId) {
        resultRef.contents = Id.Map.set(resultRef.contents, gt.teamId, gIdx)
      }
    })
  })
  resultRef.contents
}

type nextStageKind = SwissToGroup | GroupToKnockout

type nextStageParams = {
  kind: nextStageKind,
  name: string,
  advanceCount: int,
  timeLimitMinutes: int,
  stageParam: int,
}

/** 根据当前赛制和队伍数获取下一阶段参数 */
let getNextStageParams = (format: Data_Tournament.Format.t, teamCount: int): option<nextStageParams> =>
  switch format {
  | Data_Tournament.Format.Swiss =>
    let advanceCount = min(32, teamCount)
    let groupCount = max(2, advanceCount / 4)
    Some({
      kind: SwissToGroup,
      name: "小组赛",
      advanceCount,
      timeLimitMinutes: 70,
      stageParam: groupCount,
    })

  | Data_Tournament.Format.GroupStage({groupCount}) =>
    let knockoutSize = min(groupCount * 2, 16)
    Some({
      kind: GroupToKnockout,
      name: "淘汰赛",
      advanceCount: knockoutSize,
      timeLimitMinutes: 120,
      stageParam: knockoutSize,
    })

  | Data_Tournament.Format.Knockout(_) =>
    None
  }
