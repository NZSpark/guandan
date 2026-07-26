/*
  Copyright (c) 2021 John Jackson.
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/
type t = string

let toString = x => x

let fromString = x => x

/** 轮空队伍的固定ID */
let teamBye = "________TEAM_BYE________"

/** 轮空队伍中占位选手的ID */
let noPlayer = "________NO_PLAYER________"

let isTeamBye = id => id == teamBye

let random = Externals.nanoid

let encode = s => Js.Json.string(s)

let decode = json => Js.Json.decodeString(json)->Option.getExn

let compare: (t, t) => int = compare

let eq: (t, t) => bool = (a, b) => a == b

module Cmp = unpack(Belt.Id.comparable(~cmp=compare))

type identity = Cmp.identity

let id: Belt.Id.comparable<t, identity> = module(Cmp)

module Map = {
  type key = t
  type t<'v> = Belt.Map.t<key, 'v, identity>
  @inline external fromBelt: Belt.Map.t<key, 'v, identity> => t<'v> = "%identity"
  let fromArray = arr => fromBelt(Belt.Map.fromArray(arr, ~id))
  let toStringArray: t<'v> => array<(string, 'v)> = x => Belt.Map.toArray(x)
  let keysToStringArray: t<'v> => array<string> = x => Belt.Map.keysToArray(x)
  let make: unit => t<'v> = () => fromBelt(Belt.Map.make(~id))
  let set: (t<'v>, key, 'v) => t<'v> = (map, key, v) => fromBelt(Belt.Map.set(map, key, v))
  let get: (t<'v>, key) => option<'v> = (map, key) => Belt.Map.get(map, key)
  let update: (t<'v>, key, option<'v> => option<'v>) => t<'v> = (map, key, f) => {
    let current = Belt.Map.get(map, key)
    switch f(current) {
    | Some(v) => fromBelt(Belt.Map.set(map, key, v))
    | None => fromBelt(Belt.Map.remove(map, key))
    }
  }
  let remove: (t<'v>, key) => t<'v> = (map, key) => fromBelt(Belt.Map.remove(map, key))
  let removeMany: (t<'v>, array<key>) => t<'v> = (map, keys) => fromBelt(Belt.Map.removeMany(map, keys))
  let size: t<'v> => int = map => Belt.Map.size(map)
  let toArray: t<'v> => array<(key, 'v)> = map => Belt.Map.toArray(map)
  let valuesToArray: t<'v> => array<'v> = map => Belt.Map.valuesToArray(map)
  let map: (t<'a>, 'a => 'b) => t<'b> = (map, f) => fromBelt(Belt.Map.map(map, f))
  let keep: (t<'a>, (key, 'a) => bool) => t<'a> = (map, f) => fromBelt(Belt.Map.keep(map, f))
  let reduce: (t<'a>, 'b, ('b, key, 'a) => 'b) => 'b = (map, init, f) => Belt.Map.reduce(map, init, f)
  let mapWithKey: (t<'a>, (key, 'a) => 'b) => t<'b> = (map, f) => fromBelt(Belt.Map.mapWithKey(map, f))
  let merge: (t<'a>, t<'b>, (key, option<'a>, option<'b>) => option<'c>) => t<'c> = (map1, map2, f) =>
    fromBelt(Belt.Map.merge(map1, map2, f))
  let has: (t<'v>, key) => bool = (map, key) => Belt.Map.has(map, key)
}

module Set = {
  type value = t
  type t = Belt.Set.t<value, identity>
  let make = () => Belt.Set.make(~id)
  let fromArray = arr => Belt.Set.fromArray(arr, ~id)
  let toArray = s => Belt.Set.toArray(s)
  let has = (s, v) => Belt.Set.has(s, v)
  let add = (s, v) => Belt.Set.add(s, v)
  let size = s => Belt.Set.size(s)
  let remove = (s, v) => Belt.Set.remove(s, v)
  let union = (s1, s2) => Belt.Set.union(s1, s2)
}

module Pair = {
  type id = t
  type t = (t, t)

  /* This sorts the pairs. */
  let make = (a, b) =>
    switch compare(a, b) {
    | 0 => None
    | 1 => Some((a, b))
    | _ => Some((b, a))
    }

  /* This only works if the pairs are sorted. */
  let compare = ((a, b), (c, d)) =>
    switch compare(a, c) {
    | 0 =>
      switch compare(b, d) {
      | 0 => 0
      | x => x
      }
    | x => x
    }

  let has = ((a, b): t, ~id) => eq(a, id) || eq(b, id)

  let toTuple = t => t

  let decode = json => {
    let arr = Js.Json.decodeArray(json)
    let a = arr->Option.flatMap(arr => arr[0])->Option.getExn
    let b = arr->Option.flatMap(arr => arr[1])->Option.getExn
    (decode(a), decode(b))
  }

  let encode = ((a, b)) => Js.Json.array([encode(a), encode(b)])

  module Cmp = unpack(Belt.Id.comparable(~cmp=compare))

  type identity = Cmp.identity

  let id_id = id
  let id: Belt.Id.comparable<t, identity> = module(Cmp)

  module Id_Set = Set

  module Set = {
    type pair = t
    type t = Belt.Set.t<pair, identity>

    let make = () => Belt.Set.make(~id)
    let fromArray = arr => Belt.Set.fromArray(arr, ~id)
    let toArray = s => Belt.Set.toArray(s)

    let decode = json =>
      json->Js.Json.decodeArray->Option.getExn->Array.map(decode)->Belt.Set.fromArray(~id)

    let encode = data => data->Belt.Set.toArray->Array.map(encode)->Js.Json.array

    let toMapReducer = (acc, (id1, id2)) => {
      let s1 = Belt.Set.make(~id=id_id)->Belt.Set.add(id2)
      let s2 = Belt.Set.make(~id=id_id)->Belt.Set.add(id1)
      acc
      ->Map.update(id1, s =>
        switch s {
        | None => Some(s1)
        | Some(s) => Some(Belt.Set.union(s, s1))
        }
      )
      ->Map.update(id2, s =>
        switch s {
        | None => Some(s2)
        | Some(s) => Some(Belt.Set.union(s, s2))
        }
      )
    }

    let toMap = x => Belt.Set.reduce(x, Map.make(), toMapReducer)
  }
}
