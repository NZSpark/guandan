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

let log2 = num => log(num) /. log(2.0)

let calcNumOfRoundsSwiss = teamCount => {
  let roundCount = teamCount->float_of_int->log2->ceil
  roundCount != neg_infinity ? int_of_float(roundCount) : 0
}

let calcNumOfRoundsGroupStage = (teamCount, groupCount) => {
  let groupCount = if groupCount <= 0 {max(1, teamCount / 4)} else {groupCount}
  let baseSize = teamCount / groupCount
  let remainder = teamCount - baseSize * groupCount
  let maxGroupSize = baseSize + (remainder > 0 ? 1 : 0)
  if maxGroupSize / 2 * 2 == maxGroupSize {maxGroupSize - 1} else {maxGroupSize}
}

let calcNumOfRoundsKnockout = teamCount => {
  if teamCount <= 2 {1}
  else if teamCount <= 4 {2}
  else if teamCount <= 8 {3}
  else if teamCount <= 16 {4}
  else {5}
}

let calcNumOfRounds = (tourney: Tournament.t, activeTeamCount: int): int =>
  switch tourney.format {
  | Tournament.Format.Swiss => calcNumOfRoundsSwiss(activeTeamCount)
  | Tournament.Format.GroupStage({groupCount}) => calcNumOfRoundsGroupStage(activeTeamCount, groupCount)
  | Tournament.Format.Knockout({teamCount}) => calcNumOfRoundsKnockout(teamCount)
  }

let emptyTourney = Tournament.make(~id=Id.random(), ~name="")

let tournamentReducer = (_, action) => action

type t = {
  activeTeams: Id.Map.t<Team.t>,
  getTeam: Id.t => option<Team.t>,
  getPlayer: Id.t => Player.t,
  isItOver: bool,
  isNewRoundReady: bool,
  players: Id.Map.t<Player.t>,
  teams: Id.Map.t<Team.t>,
  teamsDispatch: Db.action<Team.t> => unit,
  roundCount: int,
  tourney: Tournament.t,
  setTourney: Tournament.t => unit,
}

type loadStatus = NotLoaded | Loaded | Error

let isLoadedDone = x =>
  switch x {
  | NotLoaded => false
  | Loaded | Error => true
  }

@react.component
let make = (~children, ~tourneyId, ~windowDispatch) => {
  let (tourney, setTourney) = React.useReducer(tournamentReducer, emptyTourney)
  let {name, teamIds, roundList, format, _} = tourney
  let {items: teams, dispatch: teamsDispatch, loaded: areTeamsLoaded} = Db.useAllTeams()
  let {items: players, dispatch: _, loaded: arePlayersLoaded} = Db.useAllPlayers()
  let (tourneyLoaded, setTourneyLoaded) = React.useState(() => NotLoaded)
  Hooks.useLoadingCursorUntil(isLoadedDone(tourneyLoaded) && areTeamsLoaded && arePlayersLoaded)

  let getTeam = id => Map.get(teams, id)
  let getPlayer = Player.getMaybe(players, ...)

  let actualWindowDispatch = switch windowDispatch {
  | Some(dispatch) => dispatch
  | None => _ => ()
  }
  React.useEffect2(() => {
    actualWindowDispatch(Window.SetTitle(name))
    Some(() => actualWindowDispatch(SetTitle("")))
  }, (name, actualWindowDispatch))

  /* Initialize the tournament from the database. */
  React.useEffect1(() => {
    let didCancel = ref(false)
    Db.getTourney(tourneyId)
    ->Promise.thenResolve(value =>
      switch value {
      | _ if didCancel.contents => ()
      | None => setTourneyLoaded(_ => Error)
      | Some(value) =>
        setTourney(value)
        setTourneyLoaded(_ => Loaded)
      }
    )
    ->Promise.catch(_ => {
      if !didCancel.contents {
        setTourneyLoaded(_ => Error)
      }
      Promise.resolve()
    })
    ->ignore
    Some(() => didCancel := true)
  }, [tourneyId])

  /* Save the tournament to DB. */
  React.useEffect3(() => {
    switch tourneyLoaded {
    | NotLoaded | Error => ()
    | Loaded =>
      if Id.eq(tourneyId, tourney.id) {
        Db.setTourney(tourneyId, tourney)->ignore
      }
    }
    None
  }, (tourneyLoaded, tourneyId, tourney))

  switch (tourneyLoaded, areTeamsLoaded, arePlayersLoaded) {
  | (Loaded, true, true) =>
    let activeTeams = Map.keep(teams, (id, _) => Set.has(teamIds, id))
    let roundCount = calcNumOfRounds(tourney, Map.size(activeTeams))
    let lastRoundId = Rounds.size(roundList) - 1

    /* For non-Swiss formats, all rounds are generated upfront, so the tournament is over
       when all rounds have all results scored */
    let isSwiss = switch format {
    | Tournament.Format.Swiss => true
    | Tournament.Format.GroupStage(_) | Tournament.Format.Knockout(_) => false
    }

    let isItOver = if isSwiss {
      Rounds.size(roundList) >= roundCount
    } else {
      /* Non-Swiss: all rounds generated upfront, check if all matches have results */
      Rounds.size(roundList) >= roundCount &&
        Rounds.size(roundList) > 0 &&
        (lastRoundId < 0 || Rounds.isRoundComplete(roundList, activeTeams, lastRoundId))
    }

    let isNewRoundReady = if isSwiss {
      Rounds.size(roundList) == 0
        ? true
        : Rounds.isRoundComplete(roundList, activeTeams, Rounds.size(roundList) - 1)
    } else {
      /* Non-Swiss: only show "new round" if no rounds exist yet */
      Rounds.size(roundList) == 0
    }

    children({
      activeTeams,
      getTeam,
      getPlayer,
      isItOver,
      isNewRoundReady,
      players,
      teams,
      teamsDispatch,
      roundCount,
      tourney,
      setTourney,
    })
  | (Error, _, _) => React.string("错误：无法加载锦标赛。")
  | (NotLoaded, _, _) | (Loaded, false, _) | (Loaded, _, false) => React.string("加载中...")
  }
}
