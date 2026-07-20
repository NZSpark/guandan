/*
  Copyright (c) 2021 John Jackson. 
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/
open! Belt
open Data
module Id = Data.Id
let id = Data.Id.fromString

/* Demo players */
let p1: Player.t = {id: "Alice_Wang________"->id, firstName: "Alice", lastName: "Wang", gender: "女"}
let p2: Player.t = {id: "Bob_Li____________"->id, firstName: "Bob", lastName: "Li", gender: "男"}
let p3: Player.t = {id: "Carol_Chen_______"->id, firstName: "Carol", lastName: "Chen", gender: "女"}
let p4: Player.t = {id: "David_Zhang______"->id, firstName: "David", lastName: "Zhang", gender: "男"}

/* Demo teams */
let t1: Team.t = {id: "Team_Alpha_________"->id, name: "Alpha 队", player1Id: p1.id, player2Id: p2.id, isBye: false, club: "掼蛋俱乐部A", initialScore: 0.0}
let t2: Team.t = {id: "Team_Beta__________"->id, name: "Beta 队", player1Id: p3.id, player2Id: p4.id, isBye: false, club: "掼蛋俱乐部B", initialScore: 0.0}

let players: Id.Map.t<Player.t> =
  Map.fromArray(~id=Id.id, [(p1.id, p1), (p2.id, p2), (p3.id, p3), (p4.id, p4)])

let teams: Id.Map.t<Team.t> =
  Map.fromArray(~id=Id.id, [(t1.id, t1), (t2.id, t2)])

let config = Config.default
let tournaments: Id.Map.t<Tournament.t> = Map.make(~id=Id.id)
