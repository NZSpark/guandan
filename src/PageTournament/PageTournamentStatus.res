/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/
open Data
module Id = Data_Id

let medalBadge = rank =>
  switch rank {
  | 0 => <span className="standings-medal medal-gold" title="第1名"> {React.string("1")} </span>
  | 1 => <span className="standings-medal medal-silver" title="第2名"> {React.string("2")} </span>
  | 2 => <span className="standings-medal medal-bronze" title="第3名"> {React.string("3")} </span>
  | _ => <span className="standings-rank"> {React.int(rank + 1)} </span>
  }

let formatFieldScore = (score: float, _rank: int): string => {
  /* 2026 rules: win=1, draw=0.5, lose=0, absent=-1, bye=1 */
  if score == 0.0 {
    "0"
  } else if score > 0.0 {
    "+" ++ Js.Float.toFixedWithPrecision(score, ~digits=1)
  } else {
    Js.Float.toFixedWithPrecision(score, ~digits=1)
  }
}

let formatNetSmallScore = (ns: int): string =>
  if ns >= 0 {
    "+" ++ Int.toString(ns)
  } else {
    Int.toString(ns)
  }

let isTop3 = rank => rank < 3

let trClass = rank =>
  if isTop3(rank) {
    "standings-row standings-row-top3"
  } else {
    "standings-row"
  }

@react.component
let make = (~data: LoadTournament.t) => {
  let {tourney, getTeam, getPlayer, _} = data
  let {roundList, tieBreaks, format, _} = tourney

  let scoreData = React.useMemo1(
    () => Scoring.fromTournament(~roundList, ~scoreAdjustments=Id.Map.make()),
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

  let isSwiss = switch format {
  | Tournament.Format.Swiss => true
  | Tournament.Format.GroupStage(_) | Tournament.Format.Knockout(_) => false
  }

  let showOpponentScore = isSwiss && Array.length(standings) > 1
  let showWins = isSwiss && Array.length(standings) > 1

  <>
    <h2> {React.string("积分榜")} </h2>
    {if Array.length(standings) == 0 {
      <EmptyState icon=EmptyState.Trophy title="暂无比赛数据" description="完成比赛录入后，积分榜将在此展示。" />
    } else {
      <div className="standings-wrapper">
        <table className="standings-table">
          <thead>
            <tr>
              <th className="standings-col-rank"> {React.string("排名")} </th>
              <th className="standings-col-team"> {React.string("队伍")} </th>
              <th className="standings-col-players"> {React.string("队员")} </th>
              <th className="standings-col-num"> {React.string("场分")} </th>
              {if showOpponentScore {
                <th className="standings-col-num"> {React.string("对手分")} </th>
              } else {
                React.null
              }}
              {if showWins {
                <th className="standings-col-num"> {React.string("胜场")} </th>
              } else {
                React.null
              }}
              <th className="standings-col-num"> {React.string("净积小分")} </th>
              <th className="standings-col-num"> {React.string("累积小分")} </th>
            </tr>
          </thead>
          <tbody>
            {standings->Array.mapWithIndex((s, i) => {
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
              let fsClass = if s.fieldScore > 0.0 {
                "score-positive"
              } else if s.fieldScore < 0.0 {
                "score-negative"
              } else {
                "score-neutral"
              }

              <tr key={Id.toString(s.id)} className={trClass(i)}>
                <td className="standings-col-rank center">
                  {medalBadge(i)}
                </td>
                <td className="standings-col-team">
                  <strong> {React.string(teamName)} </strong>
                </td>
                <td className="standings-col-players">
                  {React.string(playerNames)}
                </td>
                <td className={"standings-col-num " ++ fsClass}>
                  {React.string(formatFieldScore(s.fieldScore, i))}
                </td>
                {if showOpponentScore {
                  <td className="standings-col-num score-neutral">
                    {React.string(Js.Float.toFixedWithPrecision(s.opponentScore, ~digits=1))}
                  </td>
                } else {
                  React.null
                }}
                {if showWins {
                  <td className="standings-col-num">
                    {React.int(s.wins)}
                  </td>
                } else {
                  React.null
                }}
                <td className="standings-col-num">
                  {React.string(formatNetSmallScore(s.netSmallScore))}
                </td>
                <td className="standings-col-num">
                  {React.int(s.cumulativeSmallScore)}
                </td>
              </tr>
            })->React.array}
          </tbody>
        </table>
      </div>
    }}
    <div className="standings-tiebreak-info">
      <span className="caption-20">
        {React.string("破同分: " ++
          tieBreaks->Array.map(getTieBreakLabel)->Js.Array2.joinWith(" → "))}
      </span>
      {if isSwiss {
        <span className="caption-20" style={marginLeft: "1rem"}>
          {React.string("| 场分规则: 胜+1 / 平+0.5 / 负0 / 缺席-1 / 轮空+1")}
        </span>
      } else {
        React.null
      }}
    </div>
  </>
}
