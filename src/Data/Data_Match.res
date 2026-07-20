/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/
module Id = Data_Id
module Option = Belt.Option

module Result = {
  type winner = Team1Won | Team2Won

  type t = {
    team1Level: Data_Level.t,
    team2Level: Data_Level.t,
    winner: option<winner>,
  }

  let toString = x =>
    switch x.winner {
    | Some(Team1Won) => "team1won"
    | Some(Team2Won) => "team2won"
    | None => "notSet"
    }

  let fromString = x =>
    switch x {
    | "team1won" => Some(Team1Won)
    | "team2won" => Some(Team2Won)
    | _ => None
    }

  let encode = data => {
    let winnerStr = switch data.winner {
    | Some(Team1Won) => "team1won"
    | Some(Team2Won) => "team2won"
    | None => "notSet"
    }
    Js.Dict.fromArray([
      ("team1Level", data.team1Level->Data_Level.encode),
      ("team2Level", data.team2Level->Data_Level.encode),
      ("winner", winnerStr->Js.Json.string),
    ])->Js.Json.object_
  }

  let decode = json => {
    let d = Js.Json.decodeObject(json)->Option.getExn
    {
      team1Level: d->Js.Dict.get("team1Level")->Option.getExn->Data_Level.decode,
      team2Level: d->Js.Dict.get("team2Level")->Option.getExn->Data_Level.decode,
      winner: d
      ->Js.Dict.get("winner")
      ->Option.flatMap(Js.Json.decodeString)
      ->Option.map(fromString)
      ->Option.getWithDefault(None),
    }
  }

  let makeNotSet = () => {
    team1Level: Data_Level.Two,
    team2Level: Data_Level.Two,
    winner: None,
  }

  let fieldScoreForTeam = (result: t, isTeam1: bool): float =>
    switch result.winner {
    | Some(Team1Won) => isTeam1 ? 3.0 : 1.0
    | Some(Team2Won) => isTeam1 ? 1.0 : 3.0
    | None => 2.0  /* 平级各得2分 */
    }

  /** 胜/平/负判定 */
  let resultForTeam = (result: t, isTeam1: bool): string => {
    let fs = fieldScoreForTeam(result, isTeam1)
    if fs == 3.0 { "W" } else if fs == 2.0 { "D" } else { "L" }
  }
}

type t = {
  id: Id.t,
  team1Id: Id.t,
  team2Id: Id.t,
  result: Result.t,
  tableNumber: option<int>,
}

let isBye = ({team1Id, team2Id, _}) => Data_Id.isTeamBye(team1Id) || Data_Id.isTeamBye(team2Id)

let decode = json => {
  let d = Js.Json.decodeObject(json)
  {
    id: d->Option.flatMap(d => Js.Dict.get(d, "id"))->Option.getExn->Id.decode,
    team1Id: d->Option.flatMap(d => Js.Dict.get(d, "team1Id"))->Option.getExn->Id.decode,
    team2Id: d->Option.flatMap(d => Js.Dict.get(d, "team2Id"))->Option.getExn->Id.decode,
    result: d->Option.flatMap(d => Js.Dict.get(d, "result"))->Option.getExn->Result.decode,
    tableNumber: d
    ->Option.flatMap(d => Js.Dict.get(d, "tableNumber"))
    ->Option.flatMap(Js.Json.decodeNumber)
    ->Option.map(Belt.Float.toInt),
  }
}

let encode = data =>
  Js.Dict.fromArray([
    ("id", data.id->Id.encode),
    ("team1Id", data.team1Id->Id.encode),
    ("team2Id", data.team2Id->Id.encode),
    ("result", data.result->Result.encode),
    ("tableNumber",
      switch data.tableNumber {
      | Some(n) => n->Belt.Float.fromInt->Js.Json.number
      | None => Js.Json.null
      }
    ),
  ])->Js.Json.object_

let manualPair = (~team1: Data_Team.t, ~team2: Data_Team.t) => {
  id: Id.random(),
  team1Id: team1.id,
  team2Id: team2.id,
  result: Result.makeNotSet(),
  tableNumber: None,
}

/**
 * 通过将team2Id的bye match交换到team1获得对手ID
 */
let getOpponentId = (match: t, teamId: Id.t): Id.t =>
  if Id.eq(teamId, match.team1Id) {
    match.team2Id
  } else {
    match.team1Id
  }
