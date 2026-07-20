/*
  Copyright (c) 2021 John Jackson. 
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/
type t = {
  activeTeams: Data.Id.Map.t<Data.Team.t>,
  getTeam: Data.Id.t => option<Data.Team.t>,
  getPlayer: Data.Id.t => Data.Player.t,
  isItOver: bool,
  isNewRoundReady: bool,
  players: Data.Id.Map.t<Data.Player.t>,
  teams: Data.Id.Map.t<Data.Team.t>,
  teamsDispatch: Db.action<Data.Team.t> => unit,
  roundCount: int,
  tourney: Data.Tournament.t,
  setTourney: Data.Tournament.t => unit,
}

@react.component
let make: (
  ~children: t => React.element,
  ~tourneyId: Data.Id.t,
  ~windowDispatch: option<Window.action => unit>,
) => React.element
