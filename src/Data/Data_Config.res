/*
  Copyright (c) 2021 John Jackson.
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/
type t = {
  avoidTeamPairs: Data_Id.Pair.Set.t,
  avoidClubs: bool,
  lastBackup: Js.Date.t,
}

let decode = json => {
  let d = Js.Json.decodeObject(json)->Option.getExn
  {
    avoidTeamPairs: switch d->Js.Dict.get("avoidTeamPairs") {
    | Some(v) => Data_Id.Pair.Set.decode(v)
    | None => Data_Id.Pair.Set.make()
    },
    avoidClubs: switch d->Js.Dict.get("avoidClubs") {
    | Some(v) => Js.Json.decodeBoolean(v)->Option.getOr(false)
    | None => false
    },
    lastBackup: d
    ->Js.Dict.get("lastBackup")
    ->Option.flatMap(x => Js.Json.decodeString(x))
    ->Option.getOr("1970-01-01T00:00:00.000Z")
    ->Js.Date.fromString,
  }
}

let encode = data =>
  Js.Dict.fromArray([
    ("avoidTeamPairs", data.avoidTeamPairs->Data_Id.Pair.Set.encode),
    ("avoidClubs", data.avoidClubs->Js.Json.boolean),
    ("lastBackup", data.lastBackup->Js.Date.toJSONUnsafe->Js.Json.string),
  ])->Js.Json.object_

let default = {
  avoidTeamPairs: Data_Id.Pair.Set.make(),
  avoidClubs: true,
  lastBackup: Js.Date.fromFloat(0.0),
}
