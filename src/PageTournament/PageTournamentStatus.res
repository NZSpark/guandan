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
let make = (~data: LoadTournament.t) => {
  let {tourney, getTeam, getPlayer, _} = data
  let {roundList, tieBreaks, _} = tourney

  let scoreData = React.useMemo1(
    () => Scoring.fromTournament(~roundList, ~scoreAdjustments=Map.make(~id=Id.id)),
    [roundList],
  )

  let standings = React.useMemo1(
    () => Scoring.createStandingArray(scoreData, scoreData),
    [scoreData],
  )

  let _getTeamDisplay = (teamId: Id.t): string =>
    switch getTeam(teamId) {
    | Some(t) => {
        let p1 = getPlayer(t.player1Id)
        let p2 = getPlayer(t.player2Id)
        t.name ++ " (" ++ p1.firstName ++ "/" ++ p2.firstName ++ ")"
      }
    | None => "未知队伍"
    }

  let getTieBreakLabel = (tb: Scoring.TieBreak.t) =>
    Scoring.TieBreak.toPrettyString(tb)

  <>
    <h2> {React.string("积分榜")} </h2>
    {if Array.length(standings) == 0 {
      <p> {React.string("暂无比赛数据。")} </p>
    } else {
      <div style={overflowX: "auto"}>
        <table className="table" style={width: "100%", textAlign: "left"}>
          <thead>
            <tr>
              <th> {React.string("排名")} </th>
              <th> {React.string("队伍")} </th>
              <th> {React.string("队员")} </th>
              <th> {React.string("场分")} </th>
              <th> {React.string("净积小分")} </th>
              <th> {React.string("累积小分")} </th>
            </tr>
          </thead>
          <tbody>
            {standings->Array.mapWithIndex((i, s) => {
              let team = getTeam(s.id)
              let teamName = switch team {
              | Some(t) => t.name
              | None => "未知"
              }
              let playerNames = switch team {
              | Some(t) => {
                  let p1 = getPlayer(t.player1Id)
                  let p2 = getPlayer(t.player2Id)
                  p1.firstName ++ "/" ++ p2.firstName
                }
              | None => "?"
              }
              <tr key={Id.toString(s.id)}>
                <td> {React.int(i + 1)} </td>
                <td> <strong> {React.string(teamName)} </strong> </td>
                <td> {React.string(playerNames)} </td>
                <td> {React.string(s.fieldScore->Float.toString)} </td>
                <td>
                  {React.string(
                    s.netSmallScore >= 0
                      ? "+" ++ Int.toString(s.netSmallScore)
                      : Int.toString(s.netSmallScore),
                  )}
                </td>
                <td> {React.int(s.cumulativeSmallScore)} </td>
              </tr>
            })->React.array}
          </tbody>
        </table>
      </div>
    }}
    <div style={marginTop: "1rem"}>
      <p style={fontSize: "small", color: "gray"}>
        {React.string("破同分规则: " ++
          tieBreaks->Array.map(getTieBreakLabel)->Js.Array2.joinWith(" → "))}
      </p>
    </div>
  </>
}
