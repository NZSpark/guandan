/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/
module Result: {
  type winner = Team1Won | Team2Won

  type t = {
    team1Level: Data_Level.t,
    team2Level: Data_Level.t,
    winner: option<winner>,
  }

  let toString: t => string
  let fromString: string => option<winner>
  let encode: t => Js.Json.t
  let decode: Js.Json.t => t

  /** 创建未设置的结果 */
  let makeNotSet: unit => t

  /** 场分: 胜3/平2/负1 */
  let fieldScoreForTeam: (t, bool) => float

  /** 胜/平/负字符串 */
  let resultForTeam: (t, bool) => string
}

type t = {
  id: Data_Id.t,
  team1Id: Data_Id.t,
  team2Id: Data_Id.t,
  result: Result.t,
  tableNumber: option<int>,
}

let isBye: t => bool

let decode: Js.Json.t => t

let encode: t => Js.Json.t

/** 手动创建一场比赛 */
let manualPair: (~team1: Data_Team.t, ~team2: Data_Team.t) => t

/** 获取某队在本场比赛中的对手ID */
let getOpponentId: (t, Data_Id.t) => Data_Id.t
