/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/
open Data
module Id = Data_Id

@react.component
let make = (~data: LoadTournament.t, ~roundId: int) => {
  let {tourney, setTourney, getTeam, getPlayer, _} = data
  let {roundList, _} = tourney
  let round = Rounds.get(roundList, roundId)

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

  let completedCount = matchList->Array.filter(m =>
    switch m.result.winner {
    | Some(_) => true
    | None => Data_Level.toInt(m.result.team1Level) != 2 || Data_Level.toInt(m.result.team2Level) != 2
    }
  )->Array.length

  <>
    <h2> {React.string("第 " ++ Int.toString(roundId + 1) ++ " 轮 比赛结果录入")} </h2>
    {if Array.length(matchList) > 0 {
      <p className="caption-20">
        {React.string("已录入 " ++ Int.toString(completedCount) ++ " / " ++ Int.toString(Array.length(matchList)) ++ " 场比赛")}
      </p>
    } else {
      React.null
    }}

    {if Array.length(matchList) == 0 {
      <EmptyState icon=EmptyState.Clipboard title="本轮暂无比赛" description="请先在「对阵」页面生成本轮比赛。" />
    } else {
      <div className="score-entry-list">
        {matchList->Array.mapWithIndex((m, _) => {
          let matchCard = MatchCard.fromMatch(m, getTeam, getPlayer)
          let isByeMatch = Match.isBye(m)

          <div key={Id.toString(m.id)} className="score-entry-card">
            <MatchCard match=matchCard />
            {if isByeMatch {
              <div className="score-entry-bye">
                {React.string("轮空比赛，自动判胜，无需录入。")}
              </div>
            } else {
              <div className="score-entry-levels">
                <div className="score-entry-team-level">
                  <span className="score-entry-team-label">
                    {React.string("队伍1 · " ++ matchCard.team1Name)}
                  </span>
                  <LevelPicker
                    value={m.result.team1Level}
                    onChange={newLevel => handleSetResult(m.id, newLevel, m.result.team2Level)}
                    label="最终级数"
                  />
                </div>
                <div className="score-entry-divider" />
                <div className="score-entry-team-level">
                  <span className="score-entry-team-label">
                    {React.string("队伍2 · " ++ matchCard.team2Name)}
                  </span>
                  <LevelPicker
                    value={m.result.team2Level}
                    onChange={newLevel => handleSetResult(m.id, m.result.team1Level, newLevel)}
                    label="最终级数"
                  />
                </div>
              </div>
            }}
          </div>
        })->React.array}
      </div>
    }}
  </>
}
