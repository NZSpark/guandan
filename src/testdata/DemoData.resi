/*
  Copyright (c) 2021 John Jackson. 
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/
let p1: Data.Player.t
let p2: Data.Player.t
let p3: Data.Player.t
let p4: Data.Player.t
let t1: Data.Team.t
let t2: Data.Team.t
let config: Data.Config.t
let players: Data.Id.Map.t<Data.Player.t>
let teams: Data.Id.Map.t<Data.Team.t>
let tournaments: Data.Id.Map.t<Data.Tournament.t>
