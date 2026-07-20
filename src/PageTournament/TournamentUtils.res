/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/
open! Belt
open Data
module Id = Data.Id

type roundData = {
  scoreData: Id.Map.t<Scoring.t>,
  unmatched: Id.Map.t<Data.Team.t>,
  unmatchedWithBye: Id.Map.t<Data.Team.t>,
}

let useRoundData = (
  roundId,
  {tourney: {roundList, _}, activeTeams, _}: LoadTournament.t,
) => {
  let scoreData = React.useMemo2(
    () => Scoring.fromTournament(~roundList, ~scoreAdjustments=Map.make(~id=Id.id)),
    (roundList, ()),
  )
  let isThisTheLastRound = roundId == Rounds.getLastKey(roundList)
  let unmatched = switch (Rounds.get(roundList, roundId), isThisTheLastRound) {
  | (Some(round), true) =>
    let matched = Rounds.Round.getMatched(round)
    Map.removeMany(activeTeams, matched)
  | _ => Map.make(~id=Id.id)
  }
  let unmatchedWithBye = Map.set(unmatched, Id.teamBye, Team.bye)
  {scoreData, unmatched, unmatchedWithBye}
}

type scoreInfo = {
  team: Data.Team.t,
  hasBye: bool,
  score: float,
  netSmallScore: int,
  cumulativeSmallScore: int,
  opponentResults: React.element,
}

let getScoreInfo = (
  ~team: Data.Team.t,
  ~scoreData,
  ~getTeam,
  ~teams as _,
  ~getPlayer as _,
) => {
  let {opponentResults, totalFieldScore, totalNetSmallScore, totalCumulativeSmallScore, byeCount, _} = switch Map.get(
    scoreData,
    team.id,
  ) {
  | Some(data) => data
  | None => Data.Scoring.make(team.id)
  }
  let hasBye = byeCount > 0

  let opponentResults =
    opponentResults
    ->List.toArray
    ->Array.mapWithIndex((i, (opId, result)) =>
      <li key={Data.Id.toString(opId) ++ ("-" ++ Int.toString(i))}>
        {switch getTeam(opId) {
        | Some(t) => t->Team.fullName->React.string
        | None => React.string("未知队伍")
        }}
        {" - "->React.string}
        {React.string(
          switch result {
          | "W" => "胜"
          | "D" => "平"
          | "L" => "负"
          | _ => "?"
          },
        )}
      </li>
    )
    ->React.array

  {
    team,
    hasBye,
    score: totalFieldScore,
    netSmallScore: totalNetSmallScore,
    cumulativeSmallScore: totalCumulativeSmallScore,
    opponentResults,
  }
}
