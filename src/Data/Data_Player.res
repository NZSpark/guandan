/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/
module Option = Belt.Option

type t = {
  firstName: string,
  id: Data_Id.t,
  lastName: string,
  gender: string,
}

let fullName = t =>
  if t.firstName == "" {
    if t.lastName == "" {
      "未知"
    } else {
      t.lastName
    }
  } else if t.lastName == "" {
    t.firstName
  } else {
    t.firstName ++ " " ++ t.lastName
  }

let compareName = (a, b) =>
  switch compare(a.firstName, b.firstName) {
  | 0 => compare(a.lastName, b.lastName)
  | i => i
  }

let decode = json => {
  let d = Js.Json.decodeObject(json)
  {
    id: d->Option.flatMap(d => Js.Dict.get(d, "id"))->Option.getExn->Data_Id.decode,
    firstName: d
    ->Option.flatMap(d => Js.Dict.get(d, "firstName"))
    ->Option.flatMap(Js.Json.decodeString)
    ->Option.getExn,
    lastName: d
    ->Option.flatMap(d => Js.Dict.get(d, "lastName"))
    ->Option.flatMap(Js.Json.decodeString)
    ->Option.getExn,
    gender: d
    ->Option.flatMap(d => Js.Dict.get(d, "gender"))
    ->Option.flatMap(Js.Json.decodeString)
    ->Option.getWithDefault(""),
  }
}

let encode = data =>
  Js.Dict.fromArray([
    ("firstName", data.firstName->Js.Json.string),
    ("id", data.id->Data_Id.encode),
    ("lastName", data.lastName->Js.Json.string),
    ("gender", data.gender->Js.Json.string),
  ])->Js.Json.object_

let getMaybe = (playerMap, id) =>
  if Data_Id.eq(id, Data_Id.noPlayer) {
    {id: Data_Id.noPlayer, firstName: "[轮空]", lastName: "", gender: ""}
  } else {
    Belt.Map.getWithDefault(playerMap, id, {id, firstName: "未知", lastName: "选手", gender: ""})
  }
