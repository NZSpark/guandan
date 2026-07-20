/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/
open! Belt

module Format = {
  type t =
    | Swiss
    | GroupStage({groupCount: int})
    | Knockout({teamCount: int})

  let default = Swiss

  let toString = (f: t): string =>
    switch f {
    | Swiss => "swiss"
    | GroupStage(_) => "group"
    | Knockout(_) => "knockout"
    }

  let fromString = (s: string): t =>
    switch s {
    | "group" => GroupStage({groupCount: 4})
    | "knockout" => Knockout({teamCount: 16})
    | "swiss" | _ => Swiss
    }

  let label = (f: t): string =>
    switch f {
    | Swiss => "瑞士移位制"
    | GroupStage(_) => "小组赛（单循环）"
    | Knockout(_) => "淘汰赛"
    }

  let decode = (json: Js.Json.t): t =>
    switch Js.Json.decodeString(json) {
    | Some(s) => fromString(s)
    | None => default
    }

  let encode = (f: t): Js.Json.t => f->toString->Js.Json.string
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

let make = (~id, ~name) => {
  id,
  name,
  format: Format.default,
  byeQueue: [],
  date: Js.Date.make(),
  teamIds: Set.make(~id=Data_Id.id),
  roundList: Data_Rounds.empty,
  tieBreaks: Data_Scoring.defaultTieBreaks,
}

/**
  LocalForage/IndexedDB sometimes automatically parses the date for us already,
  and I'm not sure how to properly handle it.
  */
external unsafe_date: Js.Json.t => Js.Date.t = "%identity"

@raises(Not_found)
let decode = json => {
  let d = Js.Json.decodeObject(json)->Option.getExn
  {
    id: d->Js.Dict.get("id")->Option.getExn->Data_Id.decode,
    name: d->Js.Dict.get("name")->Option.flatMap(Js.Json.decodeString)->Option.getExn,
    format: d
    ->Js.Dict.get("format")
    ->Option.map(Format.decode)
    ->Option.getWithDefault(Format.default),
    date: d
    ->Js.Dict.get("date")
    ->Option.map(json =>
      switch Js.Json.decodeString(json) {
      | Some(s) => Js.Date.fromString(s)
      | None => unsafe_date(json)
      }
    )
    ->Option.getExn,
    teamIds: d
    ->Js.Dict.get("teamIds")
    ->Option.flatMap(Js.Json.decodeArray)
    ->Option.getExn
    ->Array.map(Data_Id.decode)
    ->Set.fromArray(~id=Data_Id.id),
    byeQueue: d
    ->Js.Dict.get("byeQueue")
    ->Option.flatMap(Js.Json.decodeArray)
    ->Option.getExn
    ->Array.map(Data_Id.decode),
    tieBreaks: d
    ->Js.Dict.get("tieBreaks")
    ->Option.flatMap(Js.Json.decodeArray)
    ->Option.getExn
    ->Array.map(Data_Scoring.TieBreak.decode),
    roundList: d->Js.Dict.get("roundList")->Option.getExn->Data_Rounds.decode,
  }
}

let encode = data =>
  Js.Dict.fromArray([
    ("id", data.id->Data_Id.encode),
    ("name", data.name->Js.Json.string),
    ("format", data.format->Format.encode),
    ("date", data.date->Js.Date.toJSONUnsafe->Js.Json.string),
    ("teamIds", data.teamIds->Set.toArray->Array.map(Data_Id.encode)->Js.Json.array),
    ("byeQueue", data.byeQueue->Array.map(Data_Id.encode)->Js.Json.array),
    ("tieBreaks", data.tieBreaks->Array.map(Data_Scoring.TieBreak.encode)->Js.Json.array),
    ("roundList", data.roundList->Data_Rounds.encode),
  ])->Js.Json.object_
