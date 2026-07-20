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
}

let make: (~id: Data_Id.t, ~name: string) => t

let encode: t => Js.Json.t

let decode: Js.Json.t => t
