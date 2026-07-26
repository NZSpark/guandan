/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  参照南山杯Aotearoa掼蛋大赛指南(2026)及《掼蛋(国家)竞赛规则(2017版)》
  场分规则（2026附录一）：
    海选赛&小组赛：胜1/平0.5/负0/缺席-1/轮空1
  破同分：
    海选赛：总积分 → 对手分 → 胜场数 → 贡献分（累积小分）
    小组赛：总积分 → 相互胜负 → 净积小分 → 累积小分
*/
module Id = Data_Id

module FieldScore = {
  /** 胜方得1分 */
  let win = 1.0
  /** 打平各得0.5分 */
  let draw = 0.5
  /** 负方得0分 */
  let lose = 0.0
  /** 缺席得-1分（对手自动获胜记1分） */
  let absent = -1.0
  /** 轮空自动获胜，记1分 */
  let bye = 1.0
}

type t = {
  id: Id.t,
  teamId: Id.t,
  /** 各局场分（1.0/0.5/0.0/-1.0） */
  results: list<float>,
  /** 总场分 */
  totalFieldScore: float,
  /** 对手分（Buchholz）：所有对手的总场分之和（瑞士制破同分用） */
  opponentScore: float,
  /** 胜场数（瑞士制破同分用） */
  wins: int,
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
  totalFieldScore: 0.0,
  opponentScore: 0.0,
  wins: 0,
  totalNetSmallScore: 0,
  totalCumulativeSmallScore: 0,
  opponentResults: list{},
  byeCount: 0,
}

let oppResultsToSumById = ({opponentResults, _}, id) =>
  List.reduce(opponentResults, None, (acc, (id', result)) =>
    if Id.eq(id, id') {
      let score = switch result {
      | "W" => FieldScore.win
      | "D" => FieldScore.draw
      | "L" => FieldScore.lose
      | _ => FieldScore.lose
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
 *
 * 南山杯2026附录一：
 *  海选赛：总积分 → 对手分 → 胜场数 → 贡献分
 *  小组赛：总积分 → 相互胜负 → 净积小分 → 累积小分
 */
module TieBreak = {
  type t =
    | TotalFieldScore
    | DirectEncounter
    | OpponentScore  /* 对手分（瑞士制Buchholz） */
    | Wins           /* 胜场数（瑞士制破同分） */
    | NetSmallScore
    | CumulativeSmallScore

  let toString = data =>
    switch data {
    | TotalFieldScore => "totalFieldScore"
    | DirectEncounter => "directEncounter"
    | OpponentScore => "opponentScore"
    | Wins => "wins"
    | NetSmallScore => "netSmallScore"
    | CumulativeSmallScore => "cumulativeSmallScore"
    }

  let toPrettyString = tieBreak =>
    switch tieBreak {
    | TotalFieldScore => "总积分"
    | DirectEncounter => "相互胜负"
    | OpponentScore => "对手分"
    | Wins => "胜场数"
    | NetSmallScore => "净积小分"
    | CumulativeSmallScore => "累积小分"
    }

  let fromString = json =>
    switch json {
    | "totalFieldScore" => TotalFieldScore
    | "directEncounter" => DirectEncounter
    | "opponentScore" => OpponentScore
    | "wins" => Wins
    | "netSmallScore" => NetSmallScore
    | "cumulativeSmallScore" => CumulativeSmallScore
    | _ => TotalFieldScore
    }

  let encode = data => data->toString->Js.Json.string

  @raises(Not_found)
  let decode = json => Js.Json.decodeString(json)->Option.getExn->fromString
}

/** 海选赛（瑞士制）破同分顺序：总积分 → 对手分 → 胜场数 → 累积小分（贡献分） */
let swissTieBreaks = [TieBreak.TotalFieldScore, TieBreak.OpponentScore,
                      TieBreak.Wins, TieBreak.CumulativeSmallScore]

/** 小组赛破同分顺序：总积分 → 相互胜负 → 净积小分 → 累积小分 */
let groupTieBreaks = [TieBreak.TotalFieldScore, TieBreak.DirectEncounter,
                       TieBreak.NetSmallScore, TieBreak.CumulativeSmallScore]

/** 默认破同分（保持向后兼容） */
let defaultTieBreaks = groupTieBreaks

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
    let isWin = resultStr == "W"
    Some({
      id: teamId,
      teamId,
      results: list{fieldScore},
      totalFieldScore: fieldScore,
      opponentScore: 0.0,
      wins: isWin ? 1 : 0,
      totalNetSmallScore: netSmall,
      totalCumulativeSmallScore: cumSmall,
      opponentResults: list{(oppId, resultStr)},
      byeCount: Data_Id.isTeamBye(oppId) ? 1 : 0,
    })
  | Some(data) =>
    let isWin = resultStr == "W"
    Some({
      ...data,
      results: list{fieldScore, ...data.results},
      totalFieldScore: data.totalFieldScore +. fieldScore,
      opponentScore: data.opponentScore,
      wins: data.wins + (isWin ? 1 : 0),
      totalNetSmallScore: data.totalNetSmallScore + netSmall,
      totalCumulativeSmallScore: data.totalCumulativeSmallScore + cumSmall,
      opponentResults: list{(oppId, resultStr), ...data.opponentResults},
      byeCount: Data_Id.isTeamBye(oppId) ? data.byeCount + 1 : data.byeCount,
    })
  }

let fromTournament = (~roundList, ~scoreAdjustments as _) => {
  let scores =
    roundList
    ->Data_Rounds.rounds2Matches
    ->Array.reduce(Id.Map.make(), (acc, match: Data_Match.t) =>
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
        acc->Id.Map.update(match.team1Id, team1Update)->Id.Map.update(match.team2Id, team2Update)
      }
    )
  /* 第二遍：计算每支队伍的对手分（Buchholz） */
  Id.Map.map(scores, ({opponentResults, _} as data) => {
    let opponentScore = List.reduce(opponentResults, 0., (acc, (oppId, _)) => {
      let oppScore = switch Id.Map.get(scores, oppId) {
      | Some(s) => s.totalFieldScore
      | None => 0.0
      }
      acc +. oppScore
    })
    {...data, opponentScore}
  })
}

let _getTeamScore = (scores, id) =>
  switch Id.Map.get(scores, id) {
  | None => 0.0
  | Some({totalFieldScore, _}) => totalFieldScore
  }

type teamScores = {
  id: Data_Id.t,
  fieldScore: float,
  opponentScore: float,
  wins: int,
  netSmallScore: int,
  cumulativeSmallScore: int,
}

/** 获取破同分值 */
let getTieBreakValue = (scores: teamScores, x: TieBreak.t) =>
  switch x {
  | TotalFieldScore => scores.fieldScore->Float.toInt
  | OpponentScore => (scores.opponentScore *. 2.0)->Float.toInt /* 乘以2避免0.5精度丢失 */
  | Wins => scores.wins
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
  ->Id.Map.map(({teamId, totalFieldScore, opponentScore, wins, totalNetSmallScore, totalCumulativeSmallScore, _}) => {
    id: teamId,
    fieldScore: totalFieldScore,
    opponentScore,
    wins,
    netSmallScore: totalNetSmallScore,
    cumulativeSmallScore: totalCumulativeSmallScore,
  })
  ->Id.Map.valuesToArray
  ->Utils.Array.toSortedByInt(compareTeamScores(defaultTieBreaks, ...))

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
