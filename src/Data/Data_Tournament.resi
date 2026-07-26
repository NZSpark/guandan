/*
  Copyright (c) 2021 John Jackson.
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/

module Format: {
  type t =
    | Swiss
    | GroupStage({groupCount: int})
    | Knockout({teamCount: int})

  let default: t

  let toString: t => string

  let fromString: string => t

  let label: t => string

  let decode: Js.Json.t => t

  let encode: t => Js.Json.t
}

type t = {
  id: Data_Id.t,
  name: string,
  date: Js.Date.t,
  format: Format.t,
  teamIds: Data_Id.Set.t,
  byeQueue: array<Data_Id.t>,
  tieBreaks: array<Data_Scoring.TieBreak.t>,
  roundList: Data_Rounds.t,
  /** 瑞士制轮数（可配置），None 时按 log2(n) 自动计算。小组赛/淘汰赛忽略。 */
  swissRounds: option<int>,
  /** 默认比赛时间限制（分钟）。海选/小组赛70，淘汰赛/决赛120。None 表示无限制。 */
  timeLimitMinutes: option<int>,
  /** 小组赛使用随机抽签（按积分分档后档内随机）而非蛇形分组 */
  groupRandomDraw: bool,
}

let make: (~id: Data_Id.t, ~name: string) => t

let encode: t => Js.Json.t

let decode: Js.Json.t => t
