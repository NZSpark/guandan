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

@react.component
let make = (
  ~roundId: int,
  ~data: LoadTournament.t,
  ~config: Config.t,
) => {
  let {tourney, setTourney, activeTeams, getTeam, getPlayer, teams: _teams, _} = data
  let {roundList, byeQueue, format, _} = tourney
  let {scoreData, unmatched, unmatchedWithBye} = TournamentUtils.useRoundData(roundId, data)
  let (showPairPicker, setShowPairPicker) = React.useState(() => false)
  let currRound = Rounds.get(roundList, roundId)

  /* Swiss 配对 */
  let handleSwissAutoPair = () => {
    let pairData = Pairing.make(
      scoreData,
      activeTeams,
      config.avoidTeamPairs,
    )
    let (pairDataWithoutBye, maybeByeTeam) = Pairing.setByeTeam(byeQueue, Id.teamBye, pairData)
    let pairs = Pairing.pairTeams(pairDataWithoutBye)
    let newMatches = pairs->Array.map(((t1Id, t2Id)) => {
      switch (Map.get(activeTeams, t1Id), Map.get(activeTeams, t2Id)) {
      | (Some(t1), Some(t2)) => Match.manualPair(~team1=t1, ~team2=t2)
      | _ => Match.manualPair(~team1=Team.bye, ~team2=Team.bye)
      }
    })

    let byeMatch = switch maybeByeTeam {
    | Some(pairTeam) => switch Map.get(activeTeams, pairTeam->Pairing.id) {
      | Some(team) => [Match.manualPair(~team1=team, ~team2=Team.bye)]
      | None => []
      }
    | None => []
    }

    let allMatches = Belt.Array.concatMany([newMatches, byeMatch])
    switch Rounds.set(roundList, roundId, Rounds.Round.fromArray(allMatches)) {
    | Some(newRoundList) => setTourney({...tourney, roundList: newRoundList})
    | None => ()
    }
  }

  /* 小组赛配对：生成全部轮次 */
  let handleGroupStageAutoPair = (groupCount: int) => {
    let (_groups, allRoundMatches) = GroupStage.generateSchedule(activeTeams, scoreData, groupCount)

    let newRoundListRef = ref(roundList)
    Array.forEachWithIndex(allRoundMatches, (i, roundMatches) => {
      let newMatches = roundMatches->Array.map(((t1Id, t2Id)) => {
        switch (Map.get(activeTeams, t1Id), Map.get(activeTeams, t2Id)) {
        | (Some(t1), Some(t2)) => Match.manualPair(~team1=t1, ~team2=t2)
        | _ => Match.manualPair(~team1=Team.bye, ~team2=Team.bye)
        }
      })
      switch Rounds.set(newRoundListRef.contents, i, Rounds.Round.fromArray(newMatches)) {
      | Some(newRL) => newRoundListRef.contents = newRL
      | None => ()
      }
    })

    setTourney({...tourney, roundList: newRoundListRef.contents})
  }

  /* 淘汰赛配对：生成对阵表 */
  let handleKnockoutAutoPair = (teamCount: int) => {
    let size =
      if teamCount >= 16 { Knockout.Sixteen }
      else if teamCount >= 8 { Knockout.Eight }
      else { Knockout.Four }
    let bracket = Knockout.generateBracket(activeTeams, scoreData, size)

    let newMatches = bracket->Array.map(entry => {
      switch (Map.get(activeTeams, entry.team1Id), Map.get(activeTeams, entry.team2Id)) {
      | (Some(t1), Some(t2)) => Match.manualPair(~team1=t1, ~team2=t2)
      | _ => Match.manualPair(~team1=Team.bye, ~team2=Team.bye)
      }
    })

    switch Rounds.set(roundList, roundId, Rounds.Round.fromArray(newMatches)) {
    | Some(newRoundList) => setTourney({...tourney, roundList: newRoundList})
    | None => ()
    }
  }

  let handleAutoPair = () =>
    switch format {
    | Tournament.Format.Swiss => handleSwissAutoPair()
    | Tournament.Format.GroupStage({groupCount}) => handleGroupStageAutoPair(groupCount)
    | Tournament.Format.Knockout({teamCount}) => handleKnockoutAutoPair(teamCount)
    }

  let handleAddManualPair = (team1: Team.t, team2: Team.t) => {
    let newMatch = Match.manualPair(~team1, ~team2)
    let newRound = switch currRound {
    | Some(r) => Rounds.Round.addMatches(r, [newMatch])
    | None => Rounds.Round.fromArray([newMatch])
    }
    switch Rounds.set(roundList, roundId, newRound) {
    | Some(newRoundList) => {
        setTourney({...tourney, roundList: newRoundList})
        setShowPairPicker(_ => false)
      }
    | None => ()
    }
  }

  let handleRemoveMatch = (matchId: Id.t) => {
    switch currRound {
    | Some(r) =>
      let newRound = Rounds.Round.removeMatchById(r, matchId)
      switch Rounds.set(roundList, roundId, newRound) {
      | Some(newRoundList) => setTourney({...tourney, roundList: newRoundList})
      | None => ()
      }
    | None => ()
    }
  }

  let getTeamDisplay = (teamId: Id.t): string =>
    if Id.isTeamBye(teamId) {
      "[轮空]"
    } else {
      switch getTeam(teamId) {
      | Some(t) => {
          let p1 = getPlayer(t.player1Id)
          let p2 = getPlayer(t.player2Id)
          t.name ++ " (" ++ p1.firstName ++ "/" ++ p2.firstName ++ ")"
        }
      | None => "未知队伍"
      }
    }

  let matchList = switch currRound {
  | Some(r) => Rounds.Round.toArray(r)
  | None => []
  }

  let matchCards = matchList->Array.mapWithIndex((_i, m) => {
    let t1Name = getTeamDisplay(m.team1Id)
    let t2Name = getTeamDisplay(m.team2Id)
    let resultStr = switch m.result.winner {
    | Some(Match.Result.Team1Won) => " — 队伍1胜"
    | Some(Match.Result.Team2Won) => " — 队伍2胜"
    | None => ""
    }
    <div key={Id.toString(m.id)} className="card" style={marginBottom: "0.5rem"}>
      <div className="card-body">
        <div style={display: "flex", justifyContent: "space-between", alignItems: "center"}>
          <div>
            <strong> {React.string(t1Name)} </strong>
            {" vs "->React.string}
            <strong> {React.string(t2Name)} </strong>
            {React.string(resultStr)}
          </div>
          <button
            className="button-micro button-danger"
            onClick={_ => handleRemoveMatch(m.id)}
            title="取消对阵">
            {React.string("✕")}
          </button>
        </div>
      </div>
    </div>
  })->React.array

  let formatDescription = switch format {
  | Tournament.Format.Swiss => React.string("瑞士移位制：每轮按积分配对")
  | Tournament.Format.GroupStage(_) => React.string("小组赛：蛇形分组 + 单循环")
  | Tournament.Format.Knockout(_) => React.string("淘汰赛：种子排位对阵")
  }

  <>
    <div className="grid-2col">
      <div>
        <h2> {React.string("第 " ++ Int.toString(roundId + 1) ++ " 轮对阵")} </h2>
        <small> {formatDescription} </small>
        {matchCards}
        {if Array.length(matchList) == 0 {
          <p> {React.string("暂无对阵。请自动配对或手动添加。")} </p>
        } else {
          React.null
        }}
      </div>
      <div>
        <h3> {React.string("未配对队伍")} </h3>
        <p> {React.string("剩余 " ++ Int.toString(Map.size(unmatched)) ++ " 支队伍")} </p>
        {unmatched->Map.valuesToArray->Array.map(t =>
          <div key={Id.toString(t.id)} className="card" style={marginBottom: "0.25rem"}>
            <div className="card-body">
              <strong> {React.string(t.name)} </strong>
            </div>
          </div>
        )->React.array}
      </div>
    </div>
    <div style={marginTop: "1rem"}>
      <button className="button button-primary" onClick={_ => handleAutoPair()}>
        {React.string("自动配对未匹配队伍")}
      </button>
      <button className="button" onClick={_ => setShowPairPicker(_ => true)} style={marginLeft: "0.5rem"}>
        {React.string("手动添加对阵")}
      </button>
    </div>
    {if showPairPicker {
      let pairedIds = matchList->Array.flatMap(m => [m.team1Id, m.team2Id])->Set.fromArray(~id=Id.id)
      let availableTeams = Map.keep(unmatchedWithBye, (id, _) =>
        !Set.has(pairedIds, id) || Id.isTeamBye(id)
      )
      <div style={marginTop: "1rem"}>
        <PairPicker
          teams=availableTeams
          getPlayer
          onAdd=handleAddManualPair
          onCancel={() => setShowPairPicker(_ => false)}
        />
      </div>
    } else {
      React.null
    }}
  </>
}
