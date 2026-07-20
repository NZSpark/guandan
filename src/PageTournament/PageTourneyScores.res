/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/
open! Belt
open Data
module Id = Data_Id

@react.component
let make = (~data: LoadTournament.t, ~roundId: int) => {
  let {tourney, setTourney, getTeam, getPlayer, _} = data
  let {roundList, _} = tourney
  let round = Rounds.get(roundList, roundId)

  let getTeamName = (teamId: Id.t): string =>
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

  let handleSetResult = (matchId: Id.t, team1Level: Data_Level.t, team2Level: Data_Level.t) => {
    switch round {
    | Some(r) =>
      switch Rounds.Round.getMatchById(r, matchId) {
      | Some(m) =>
        let winner = if Data_Level.toInt(team1Level) > Data_Level.toInt(team2Level) {
          Some(Match.Result.Team1Won)
        } else if Data_Level.toInt(team2Level) > Data_Level.toInt(team1Level) {
          Some(Match.Result.Team2Won)
        } else {
          None
        }
        let newMatch = {
          ...m,
          result: {team1Level, team2Level, winner},
        }
        switch Rounds.Round.setMatch(r, newMatch) {
        | Some(newRound) =>
          switch Rounds.set(roundList, roundId, newRound) {
          | Some(newRoundList) => setTourney({...tourney, roundList: newRoundList})
          | None => ()
          }
        | None => ()
        }
      | None => ()
      }
    | None => ()
    }
  }

  let matchList = switch round {
  | Some(r) => Rounds.Round.toArray(r)
  | None => []
  }

  <>
    <h2> {React.string("第 " ++ Int.toString(roundId + 1) ++ " 轮 比赛结果录入")} </h2>
    {if Array.length(matchList) == 0 {
      <p> {React.string("本轮暂无比赛。")} </p>
    } else {
      matchList->Array.mapWithIndex((_, m) => {
        let team1Name = getTeamName(m.team1Id)
        let team2Name = getTeamName(m.team2Id)
        let isByeMatch = Match.isBye(m)
        let currentScore = switch m.result.winner {
        | Some(Match.Result.Team1Won) =>
          let diff = Data_Level.levelDiff(m.result.team1Level, m.result.team2Level)
          team1Name ++ " 胜 (级差 +" ++ Int.toString(diff) ++ ")"
        | Some(Match.Result.Team2Won) =>
          let diff = Data_Level.levelDiff(m.result.team2Level, m.result.team1Level)
          team2Name ++ " 胜 (级差 +" ++ Int.toString(diff) ++ ")"
        | None =>
          let l1 = Data_Level.toString(m.result.team1Level)
          let l2 = Data_Level.toString(m.result.team2Level)
          if l1 == "2" && l2 == "2" {
            "未录入"
          } else {
            "平级 " ++ l1 ++ "-" ++ l2
          }
        }

        <div key={Id.toString(m.id)} className="card" style={marginBottom: "1rem"}>
          <div className="card-body">
            <h4>
              {React.string(team1Name)}
              {" vs "->React.string}
              {React.string(team2Name)}
            </h4>
            <div style={marginBottom: "0.5rem"}>
              <strong> {React.string("当前结果: ")} </strong>
              {React.string(currentScore)}
            </div>
            {if isByeMatch {
              <p> {React.string("轮空比赛，自动判胜。")} </p>
            } else {
              let levelOptions = Data_Level.all->Array.map(l =>
                <option key={Data_Level.toString(l)} value={Data_Level.toString(l)}>
                  {React.string(Data_Level.toString(l))}
                </option>
              )

              <div className="grid-2col">
                <div>
                  <label> {React.string("队伍1 最终级数:")} </label>
                  <select
                    value={Data_Level.toString(m.result.team1Level)}
                    onChange={e => {
                      let val = ReactEvent.Form.target(e)["value"]
                      handleSetResult(m.id, Data_Level.fromString(val), m.result.team2Level)
                    }}>
                    {levelOptions->React.array}
                  </select>
                </div>
                <div>
                  <label> {React.string("队伍2 最终级数:")} </label>
                  <select
                    value={Data_Level.toString(m.result.team2Level)}
                    onChange={e => {
                      let val = ReactEvent.Form.target(e)["value"]
                      handleSetResult(m.id, m.result.team1Level, Data_Level.fromString(val))
                    }}>
                    {levelOptions->React.array}
                  </select>
                </div>
              </div>
            }}
          </div>
        </div>
      })->React.array
    }}
  </>
}
