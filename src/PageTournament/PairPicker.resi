/*
  Copyright (c) 2021 John Jackson. 
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0.
*/
type teamCard = {
  team: Data.Team.t,
  playerInfo: string,
}

let makeCard: (~team: Data.Team.t, ~getPlayer: Data.Id.t => Data.Player.t) => teamCard

@react.component
let make: (
  ~teams: Data.Id.Map.t<Data.Team.t>,
  ~getPlayer: Data.Id.t => Data.Player.t,
  ~onAdd: (Data.Team.t, Data.Team.t) => unit,
  ~onCancel: unit => unit,
) => React.element
