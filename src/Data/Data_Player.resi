/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/

type t = {
  firstName: string,
  id: Data_Id.t,
  lastName: string,
  gender: string,
}

let fullName: t => string

let compareName: (t, t) => int

let encode: t => Js.Json.t

let decode: Js.Json.t => t

/**
  安全获取选手信息。如果选手不存在，显示"未知选手"。
  如果是轮空占位ID，返回"[轮空]"。
 */
let getMaybe: (Data_Id.Map.t<t>, Data_Id.t) => t
