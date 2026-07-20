/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  参照南山杯Aotearoa掼蛋大赛指南(2026)及《掼蛋(国家)竞赛规则(2017版)》
  场分规则：胜3/平2/负1/缺席0
  破同分：总积分 → 相互胜负 → 净积小分 → 累积小分
*/
open! Belt
module Id = Data_Id

module FieldScore = {
  let win = 3.0
  let draw = 2.0
  let lose = 1.0
  let absent = 0.0
  let bye = 3.0
}

type t = {
  id: Id.t,
  teamId: Id.t,
  /** 各局场分（3.0/2.0/1.0） */
  results: list<float>,
  /** 总场分 */
  totalFieldScore: float,
  /** 总净积小分 */
  totalNetSmallScore: int,
  /** 总累积小分 */
  totalCumulativeSmallScore: int,
  /** 对阵记录: (对手队伍ID, 结果字符串 "W"/"L"/"D") */
  opponentResults: list<(Id.t, string)>,
  /** 轮空计数 */
  byeCount: int,
}

let make = (teamId: Id.t): t => {
  id: teamId,
  teamId,
  results: list{},
  totalNetSmallScore: 0,
  totalCumulativeSmallScore: 0,
  totalFieldScore: 0.0,
  opponentResults: list{},
  byeCount: 0,
}

let oppResultsToSumById = ({opponentResults, _}, id) =>
  List.reduce(opponentResults, None, (acc, (id', result)) =>
    if Id.eq(id, id') {
      let score = switch result {
      | "W" => 3.0
      | "D" => 2.0
      | "L" => 1.0
      | _ => 0.0
      }
      switch acc {
      | Some(s) => Some(s +. score)
      | None => Some(score)
      }
    } else {
      acc
    }
  )

/**
 * 破同分类型（按优先级递减）
 * 南山杯2026附录一：
 * 1. 总积分 → 2. 相互胜负关系 → 3. 净积小分 → 4. 累积小分 → 5. 抽签
 */
module TieBreak = {
  type t =
    | TotalFieldScore
    | DirectEncounter
    | NetSmallScore
    | CumulativeSmallScore

  let toString = data =>
    switch data {
    | TotalFieldScore => "totalFieldScore"
    | DirectEncounter => "directEncounter"
    | NetSmallScore => "netSmallScore"
    | CumulativeSmallScore => "cumulativeSmallScore"
    }

  let toPrettyString = tieBreak =>
    switch tieBreak {
    | TotalFieldScore => "总积分"
    | DirectEncounter => "相互胜负"
    | NetSmallScore => "净积小分"
    | CumulativeSmallScore => "累积小分"
    }

  let fromString = json =>
    switch json {
    | "totalFieldScore" => TotalFieldScore
    | "directEncounter" => DirectEncounter
    | "netSmallScore" => NetSmallScore
    | "cumulativeSmallScore" => CumulativeSmallScore
    | _ => TotalFieldScore
    }

  let encode = data => data->toString->Js.Json.string

  @raises(Not_found)
  let decode = json => Js.Json.decodeString(json)->Option.getExn->fromString
}

let defaultTieBreaks = [TieBreak.TotalFieldScore, TieBreak.DirectEncounter,
                       TieBreak.NetSmallScore, TieBreak.CumulativeSmallScore]

let update = (
  data,
  ~teamId,
  ~fieldScore,
  ~netSmall,
  ~cumSmall,
  ~oppId,
  ~resultStr,
) =>
  switch data {
  | None =>
    Some({
      id: teamId,
      teamId,
      results: list{fieldScore},
      totalFieldScore: fieldScore,
      totalNetSmallScore: netSmall,
      totalCumulativeSmallScore: cumSmall,
      opponentResults: list{(oppId, resultStr)},
      byeCount: Data_Id.isTeamBye(oppId) ? 1 : 0,
    })
  | Some(data) =>
    Some({
      ...data,
      results: list{fieldScore, ...data.results},
      totalFieldScore: data.totalFieldScore +. fieldScore,
      totalNetSmallScore: data.totalNetSmallScore + netSmall,
      totalCumulativeSmallScore: data.totalCumulativeSmallScore + cumSmall,
      opponentResults: list{(oppId, resultStr), ...data.opponentResults},
      byeCount: Data_Id.isTeamBye(oppId) ? data.byeCount + 1 : data.byeCount,
    })
  }

let fromTournament = (~roundList, ~scoreAdjustments as _) =>
  roundList
  ->Data_Rounds.rounds2Matches
  ->MutableQueue.reduce(Map.make(~id=Data_Id.id), (acc, match: Data_Match.t) =>
    switch match.result.winner {
    | Some(_) | None =>
      let team1Score = Data_Match.Result.fieldScoreForTeam(match.result, true)
      let team2Score = Data_Match.Result.fieldScoreForTeam(match.result, false)
      let team1Result = Data_Match.Result.resultForTeam(match.result, true)
      let team2Result = Data_Match.Result.resultForTeam(match.result, false)
      let net1 = Data_Level.netSmallScore(match.result.team1Level, match.result.team2Level)
      let net2 = Data_Level.netSmallScore(match.result.team2Level, match.result.team1Level)
      let cum1 = Data_Level.cumulativeSmallScore(match.result.team1Level)
      let cum2 = Data_Level.cumulativeSmallScore(match.result.team2Level)

      let team1Update = update(
        ~teamId=match.team1Id,
        ~fieldScore=team1Score,
        ~netSmall=net1,
        ~cumSmall=cum1,
        ~oppId=match.team2Id,
        ~resultStr=team1Result,
        ...
      )
      let team2Update = update(
        ~teamId=match.team2Id,
        ~fieldScore=team2Score,
        ~netSmall=net2,
        ~cumSmall=cum2,
        ~oppId=match.team1Id,
        ~resultStr=team2Result,
        ...
      )
      acc->Map.update(match.team1Id, team1Update)->Map.update(match.team2Id, team2Update)
    }
  )

let _getTeamScore = (scores, id) =>
  switch Map.get(scores, id) {
  | None => 0.0
  | Some({totalFieldScore, _}) => totalFieldScore
  }

type teamScores = {
  id: Data_Id.t,
  fieldScore: float,
  netSmallScore: int,
  cumulativeSmallScore: int,
}

/** 获取破同分值 */
let getTieBreakValue = (scores: teamScores, x: TieBreak.t) =>
  switch x {
  | TotalFieldScore => scores.fieldScore->Belt.Float.toInt
  | NetSmallScore => scores.netSmallScore
  | CumulativeSmallScore => scores.cumulativeSmallScore
  | DirectEncounter => 0  /* 由外部处理 */
  }

/**
 * 比较两支队伍的排名（含破同分）。
 */
let compareTeamScores = (orderedMethods, a, b) => {
  let rec tieBreaksCompare = i =>
    switch orderedMethods[i] {
    | None => 0
    | Some(tieBreak) =>
      let va = getTieBreakValue(a, tieBreak)
      let vb = getTieBreakValue(b, tieBreak)
      switch compare(vb, va) {
      | 0 => tieBreaksCompare(succ(i))
      | x => x
      }
    }
  /* 先比场分（降序） */
  switch compare(b.fieldScore, a.fieldScore) {
  | 0 => tieBreaksCompare(1)  /* 跳过TotalFieldScore，从第二个开始 */
  | x => x
  }
}

let createStandingArray = (t, _allTeamScores) =>
  t
  ->Map.map(({teamId, totalFieldScore, totalNetSmallScore, totalCumulativeSmallScore, _}) => {
    id: teamId,
    fieldScore: totalFieldScore,
    netSmallScore: totalNetSmallScore,
    cumulativeSmallScore: totalCumulativeSmallScore,
  })
  ->Map.valuesToArray
  ->SortArray.stableSortBy(compareTeamScores(defaultTieBreaks, ...))

let createStandingTree = (standingArray, ~tieBreaks as _) =>
  Array.reduce(standingArray, list{}, (tree, standing) =>
    switch tree {
    | list{} => list{list{standing}}
    | list{treeHead, ...treeTail} =>
      switch treeHead {
      | list{} => list{list{standing}, ...tree}
      | list{lastStanding, ..._} =>
        if lastStanding.fieldScore == standing.fieldScore &&
           lastStanding.netSmallScore == standing.netSmallScore &&
           lastStanding.cumulativeSmallScore == standing.cumulativeSmallScore {
          list{list{standing, ...treeHead}, ...treeTail}
        } else {
          list{list{standing}, treeHead, ...treeTail}
        }
      }
    }
  )
