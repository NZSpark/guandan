/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/

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
  /** 瑞士制轮数（可配置），None 时按 log2(n) 自动计算 */
  swissRounds: option<int>,
  /** 默认比赛时间限制（分钟）。海选/小组赛70，淘汰赛/决赛120 */
  timeLimitMinutes: option<int>,
  /** 小组赛使用随机抽签（按积分分档后档内随机）而非蛇形分组 */
  groupRandomDraw: bool,
  /** 多阶段赛事：上一阶段赛事ID（瑞士→小组→淘汰） */
  parentTourneyId: option<Data_Id.t>,
  /** 小组赛分组信息：teamId → groupIndex (0-based)。小组赛配对时自动填充 */
  groupAssignments: option<Data_Id.Map.t<int>>,
  /** 种子分数（瑞士轮排名分）：从上一阶段传入，用于小组赛/淘汰赛种子排位。teamId → 分数 */
  seedScores: option<Data_Id.Map.t<float>>,
}

let make = (~id, ~name, ~parentTourneyId=?, ~teamIds=?) => {
  id,
  name,
  format: Format.default,
  byeQueue: [],
  date: Js.Date.make(),
  teamIds: switch teamIds {
  | Some(ids) => ids
  | None => Data_Id.Set.make()
  },
  roundList: Data_Rounds.empty,
  tieBreaks: Data_Scoring.defaultTieBreaks,
  swissRounds: None,
  timeLimitMinutes: None,
  groupRandomDraw: false,
  parentTourneyId,
  groupAssignments: None,
  seedScores: None,
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
    name: Option.getExn(Option.flatMap(d->Js.Dict.get("name"), x => Js.Json.decodeString(x))),
    format: d
    ->Js.Dict.get("format")
    ->Option.map(Format.decode)
    ->Option.getOr(Format.default),
    date: Option.getExn(d
    ->Js.Dict.get("date")
    ->Option.map(json =>
      switch Js.Json.decodeString(json) {
      | Some(s) => Js.Date.fromString(s)
      | None => unsafe_date(json)
      }
    )),
    teamIds: Option.getExn(d
    ->Js.Dict.get("teamIds")
    ->Option.flatMap(x => Js.Json.decodeArray(x)))
    ->Array.map(Data_Id.decode)
    ->Data_Id.Set.fromArray,
    byeQueue: Option.getExn(d
    ->Js.Dict.get("byeQueue")
    ->Option.flatMap(x => Js.Json.decodeArray(x)))
    ->Array.map(Data_Id.decode),
    tieBreaks: Option.getExn(d
    ->Js.Dict.get("tieBreaks")
    ->Option.flatMap(x => Js.Json.decodeArray(x)))
    ->Array.map(Data_Scoring.TieBreak.decode),
    roundList: d->Js.Dict.get("roundList")->Option.getExn->Data_Rounds.decode,
    swissRounds: d
    ->Js.Dict.get("swissRounds")
    ->Option.flatMap(x => Js.Json.decodeNumber(x))
    ->Option.map(Float.toInt),
    timeLimitMinutes: d
    ->Js.Dict.get("timeLimitMinutes")
    ->Option.flatMap(x => Js.Json.decodeNumber(x))
    ->Option.map(Float.toInt),
    groupRandomDraw: switch d->Js.Dict.get("groupRandomDraw") {
    | Some(v) => Js.Json.decodeBoolean(v)->Option.getOr(false)
    | None => false
    },
    parentTourneyId: d
    ->Js.Dict.get("parentTourneyId")
    ->Option.flatMap(x => Js.Json.decodeString(x))
    ->Option.map(Data_Id.fromString),
    groupAssignments: d
    ->Js.Dict.get("groupAssignments")
    ->Option.flatMap(x => Js.Json.decodeObject(x))
    ->Option.map(obj => {
      obj
      ->Js.Dict.entries
      ->Array.map(((teamId, groupIdx)) =>
        (Data_Id.fromString(teamId), Js.Json.decodeNumber(groupIdx)->Option.getOr(0.0)->Float.toInt)
      )
      ->Data_Id.Map.fromArray
    }),
    seedScores: d
    ->Js.Dict.get("seedScores")
    ->Option.flatMap(x => Js.Json.decodeObject(x))
    ->Option.map(obj => {
      obj
      ->Js.Dict.entries
      ->Array.map(((teamId, score)) =>
        (Data_Id.fromString(teamId), Js.Json.decodeNumber(score)->Option.getOr(0.0))
      )
      ->Data_Id.Map.fromArray
    }),
  }
}

let encode = data =>
  Js.Dict.fromArray([
    ("id", data.id->Data_Id.encode),
    ("name", data.name->Js.Json.string),
    ("format", data.format->Format.encode),
    ("date", data.date->Js.Date.toJSONUnsafe->Js.Json.string),
    ("teamIds", data.teamIds->Data_Id.Set.toArray->Array.map(Data_Id.encode)->Js.Json.array),
    ("byeQueue", data.byeQueue->Array.map(Data_Id.encode)->Js.Json.array),
    ("tieBreaks", data.tieBreaks->Array.map(Data_Scoring.TieBreak.encode)->Js.Json.array),
    ("roundList", data.roundList->Data_Rounds.encode),
    ("swissRounds",
      switch data.swissRounds {
      | Some(n) => n->Float.fromInt->Js.Json.number
      | None => Js.Json.null
      }
    ),
    ("timeLimitMinutes",
      switch data.timeLimitMinutes {
      | Some(n) => n->Float.fromInt->Js.Json.number
      | None => Js.Json.null
      }
    ),
    ("groupRandomDraw", data.groupRandomDraw->Js.Json.boolean),
    ("parentTourneyId",
      switch data.parentTourneyId {
      | Some(id) => id->Data_Id.encode
      | None => Js.Json.null
      }
    ),
    (
      "groupAssignments",
      switch data.groupAssignments {
      | Some(ga) =>
        ga
        ->Data_Id.Map.toArray
        ->Array.map(((teamId, groupIdx)) =>
          (Data_Id.toString(teamId), groupIdx->Float.fromInt->Js.Json.number)
        )
        ->Js.Dict.fromArray
        ->Js.Json.object_
      | None => Js.Json.null
      },
    ),
    (
      "seedScores",
      switch data.seedScores {
      | Some(ss) =>
        ss
        ->Data_Id.Map.toArray
        ->Array.map(((teamId, score)) =>
          (Data_Id.toString(teamId), score->Js.Json.number)
        )
        ->Js.Dict.fromArray
        ->Js.Json.object_
      | None => Js.Json.null
      },
    ),
  ])->Js.Json.object_
