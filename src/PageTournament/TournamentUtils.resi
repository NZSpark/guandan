/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/

type roundData = {
  scoreData: Data.Id.Map.t<Data.Scoring.t>,
  unmatched: Data.Id.Map.t<Data.Team.t>,
  unmatchedWithBye: Data.Id.Map.t<Data.Team.t>,
}

let useRoundData: (int, LoadTournament.t) => roundData

type scoreInfo = {
  team: Data.Team.t,
  hasBye: bool,
  score: float,
  netSmallScore: int,
  cumulativeSmallScore: int,
  opponentResults: React.element,
}

let getScoreInfo: (
  ~team: Data.Team.t,
  ~scoreData: Data.Id.Map.t<Data.Scoring.t>,
  ~getTeam: Data.Id.t => option<Data.Team.t>,
  ~teams: Data.Id.Map.t<Data.Team.t>,
  ~getPlayer: Data.Id.t => Data.Player.t,
) => scoreInfo
