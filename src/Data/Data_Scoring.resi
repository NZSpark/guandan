/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.
*/

module FieldScore: {
  let win: float
  let draw: float
  let lose: float
  let absent: float
  let bye: float
}

type t = {
  id: Data_Id.t,
  teamId: Data_Id.t,
  /** 各局场分（3.0/2.0/1.0） */
  results: list<float>,
  /** 总场分 */
  totalFieldScore: float,
  /** 总净积小分 */
  totalNetSmallScore: int,
  /** 总累积小分 */
  totalCumulativeSmallScore: int,
  /** 对阵记录: (对手队伍ID, 结果字符串 "W"/"L"/"D") */
  opponentResults: list<(Data_Id.t, string)>,
  /** 轮空计数 */
  byeCount: int,
}

let make: Data_Id.t => t

let update: (
  option<t>,
  ~teamId: Data_Id.t,
  ~fieldScore: float,
  ~netSmall: int,
  ~cumSmall: int,
  ~oppId: Data_Id.t,
  ~resultStr: string,
) => option<t>

let oppResultsToSumById: (t, Data_Id.t) => option<float>

module TieBreak: {
  type t =
    | TotalFieldScore
    | DirectEncounter
    | NetSmallScore
    | CumulativeSmallScore

  let encode: t => Js.Json.t
  let decode: Js.Json.t => t
  let toString: t => string
  let toPrettyString: t => string
}

let defaultTieBreaks: array<TieBreak.t>

type teamScores = {
  id: Data_Id.t,
  fieldScore: float,
  netSmallScore: int,
  cumulativeSmallScore: int,
}

let getTieBreakValue: (teamScores, TieBreak.t) => int

let compareTeamScores: (array<TieBreak.t>, teamScores, teamScores) => int

let createStandingArray: (Data_Id.Map.t<t>, Data_Id.Map.t<t>) => array<teamScores>

let createStandingTree: (array<teamScores>, ~tieBreaks: array<TieBreak.t>) => list<list<teamScores>>

let fromTournament: (
  ~roundList: Data_Rounds.t,
  ~scoreAdjustments: Data_Id.Map.t<float>,
) => Data_Id.Map.t<t>
