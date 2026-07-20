/*
  掼蛋队伍模型。队伍是参赛和排名的基本单元。
*/
module Id = Data_Id

type t = {
  id: Id.t,
  name: string,
  player1Id: Id.t,
  player2Id: Id.t,
  isBye: bool,
  club: string,
  initialScore: float,
}

let fullName = t => t.name

let compareName = (a, b) => compare(a.name, b.name)

/** 轮空队伍常量 */
let bye: t = {
  id: Id.teamBye,
  name: "[轮空]",
  player1Id: Id.noPlayer,
  player2Id: Id.noPlayer,
  isBye: true,
  club: "",
  initialScore: 0.0,
}

let decode = json => {
  let d = Js.Json.decodeObject(json)->Belt.Option.getExn
  {
    id: d->Js.Dict.get("id")->Belt.Option.getExn->Id.decode,
    name: d->Js.Dict.get("name")->Belt.Option.flatMap(Js.Json.decodeString)->Belt.Option.getWithDefault(""),
    player1Id: d->Js.Dict.get("player1Id")->Belt.Option.flatMap(Js.Json.decodeString)->Belt.Option.map(Id.fromString)->Belt.Option.getWithDefault(Id.noPlayer),
    player2Id: d->Js.Dict.get("player2Id")->Belt.Option.flatMap(Js.Json.decodeString)->Belt.Option.map(Id.fromString)->Belt.Option.getWithDefault(Id.noPlayer),
    isBye: d->Js.Dict.get("isBye")->Belt.Option.flatMap(Js.Json.decodeBoolean)->Belt.Option.getWithDefault(false),
    club: d->Js.Dict.get("club")->Belt.Option.flatMap(Js.Json.decodeString)->Belt.Option.getWithDefault(""),
    initialScore: d->Js.Dict.get("initialScore")->Belt.Option.flatMap(Js.Json.decodeNumber)->Belt.Option.getWithDefault(0.0),
  }
}

let encode = data =>
  Js.Dict.fromArray([
    ("id", data.id->Id.encode),
    ("name", data.name->Js.Json.string),
    ("player1Id", data.player1Id->Id.toString->Js.Json.string),
    ("player2Id", data.player2Id->Id.toString->Js.Json.string),
    ("isBye", data.isBye->Js.Json.boolean),
    ("club", data.club->Js.Json.string),
    ("initialScore", data.initialScore->Js.Json.number),
  ])->Js.Json.object_

let getPlayerIds = (team: t): array<Id.t> => [team.player1Id, team.player2Id]
