/*
  Copyright (c) 2021 John Jackson.
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/

type t = {
  avoidTeamPairs: Data_Id.Pair.Set.t,
  /** 是否自动避免同俱乐部队相遇（瑞士制配对时生效） */
  avoidClubs: bool,
  lastBackup: Js.Date.t,
}

let decode: Js.Json.t => t
let encode: t => Js.Json.t

let default: t
