/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/
type t

let toString: t => string

let fromString: string => t

/** 轮空队伍的固定ID */
let teamBye: t

/** 轮空队伍中占位选手的固定ID */
let noPlayer: t

/** 是否为轮空队伍 */
let isTeamBye: t => bool

let random: unit => t

let encode: t => Js.Json.t

let decode: Js.Json.t => t

let compare: (t, t) => int

let eq: (t, t) => bool

type identity

let id: Belt.Id.comparable<t, identity>

module Map: {
  type key = t
  type t<'v> = Belt.Map.t<key, 'v, identity>

  let fromStringArray: array<(string, 'v)> => t<'v>

  let toStringArray: t<'v> => array<(string, 'v)>
  let keysToStringArray: t<'v> => array<string>
}

module Set: {
  type value = t
  type t = Belt.Set.t<value, identity>
}

module Pair: {
  type id = t
  type t
  type identity
  let make: (id, id) => option<t>
  let has: (t, ~id: id) => bool
  let toTuple: t => (id, id)
  let id: Belt.Id.comparable<t, identity>
  module Id_Set = Set

  module Set: {
    type pair = t
    type t = Belt.Set.t<pair, identity>
    let encode: t => Js.Json.t
    let decode: Js.Json.t => t

    /**
     Flatten the `set((id1, id2), (id1, id3))` structure into an easy-to-access
     `{id1: set(id2, id3), id2: set(id1), id3: set(id1)}` structure.
     */
    let toMap: t => Map.t<Id_Set.t>
  }
}
