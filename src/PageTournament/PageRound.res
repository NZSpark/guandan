/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/
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
      ~avoidClubs=config.avoidClubs,
    )
    let (pairDataWithoutBye, maybeByeTeam) = Pairing.setByeTeam(byeQueue, Id.teamBye, pairData)
    let pairs = Pairing.pairTeams(pairDataWithoutBye)
    let timeLimit = tourney.timeLimitMinutes
    let newMatches = pairs->Array.map(((t1Id, t2Id)) => {
      switch (Id.Map.get(activeTeams, t1Id), Id.Map.get(activeTeams, t2Id)) {
      | (Some(t1), Some(t2)) => Match.manualPair(~team1=t1, ~team2=t2, ~timeLimitMinutes=timeLimit)
      | _ => Match.manualPair(~team1=Team.bye, ~team2=Team.bye, ~timeLimitMinutes=timeLimit)
      }
    })

    let byeMatch = switch maybeByeTeam {
    | Some(pairTeam) => switch Id.Map.get(activeTeams, pairTeam->Pairing.id) {
      | Some(team) => [Match.manualPair(~team1=team, ~team2=Team.bye, ~timeLimitMinutes=timeLimit)]
      | None => []
      }
    | None => []
    }

    let allMatches = Array.concat(newMatches, byeMatch)
    switch Rounds.set(roundList, roundId, Rounds.Round.fromArray(allMatches)) {
    | Some(newRoundList) => setTourney({...tourney, roundList: newRoundList})
    | None => ()
    }
  }

  /* 小组赛配对：生成全部轮次 */
  let handleGroupStageAutoPair = (groupCount: int) => {
    let (groups, allRoundMatches) = GroupStage.generateSchedule(activeTeams, scoreData, groupCount, ~randomDraw=tourney.groupRandomDraw)

    /* 构建并存储分组映射 */
    let groupAssignments = StageAdvance.groupAssignmentsFromGroups(groups, activeTeams)

    let timeLimit = tourney.timeLimitMinutes
    let newRoundListRef = ref(roundList)
    Array.forEachWithIndex(allRoundMatches, (roundMatches, i) => {
      let newMatches = roundMatches->Array.map(((t1Id, t2Id)) => {
        switch (Id.Map.get(activeTeams, t1Id), Id.Map.get(activeTeams, t2Id)) {
        | (Some(t1), Some(t2)) => Match.manualPair(~team1=t1, ~team2=t2, ~timeLimitMinutes=timeLimit)
        | _ => Match.manualPair(~team1=Team.bye, ~team2=Team.bye, ~timeLimitMinutes=timeLimit)
        }
      })
      switch Rounds.set(newRoundListRef.contents, i, Rounds.Round.fromArray(newMatches)) {
      | Some(newRL) => newRoundListRef.contents = newRL
      | None => ()
      }
    })

    setTourney({...tourney, roundList: newRoundListRef.contents, groupAssignments: Some(groupAssignments)})
  }

  /* 淘汰赛配对：生成对阵表 */
  let handleKnockoutAutoPair = (teamCount: int) => {
    let size =
      if teamCount >= 16 { Knockout.Sixteen }
      else if teamCount >= 8 { Knockout.Eight }
      else { Knockout.Four }
    let bracket = Knockout.generateBracket(activeTeams, scoreData, size)

    let timeLimit = tourney.timeLimitMinutes
    let newMatches = bracket->Array.map(entry => {
      switch (Id.Map.get(activeTeams, entry.team1Id), Id.Map.get(activeTeams, entry.team2Id)) {
      | (Some(t1), Some(t2)) => Match.manualPair(~team1=t1, ~team2=t2, ~timeLimitMinutes=timeLimit)
      | _ => Match.manualPair(~team1=Team.bye, ~team2=Team.bye, ~timeLimitMinutes=timeLimit)
      }
    })

    switch Rounds.set(roundList, roundId, Rounds.Round.fromArray(newMatches)) {
    | Some(newRoundList) => setTourney({...tourney, roundList: newRoundList})
    | None => ()
    }
  }

  /* 淘汰赛：从当前轮胜者生成下一轮对阵 */
  let handleKnockoutNextRound = () => {
    switch currRound {
    | Some(r) =>
      let currentRoundMatches = Rounds.Round.toArray(r)
      let nextPairs = Knockout.generateNextRoundPairs(currentRoundMatches)
      if Array.length(nextPairs) > 0 {
        let timeLimit = tourney.timeLimitMinutes
        let newMatches = nextPairs->Array.map(((t1Id, t2Id)) => {
          switch (Id.Map.get(activeTeams, t1Id), Id.Map.get(activeTeams, t2Id)) {
          | (Some(t1), Some(t2)) => Match.manualPair(~team1=t1, ~team2=t2, ~timeLimitMinutes=timeLimit)
          | _ => Match.manualPair(~team1=Team.bye, ~team2=Team.bye, ~timeLimitMinutes=timeLimit)
          }
        })
        let nextRoundId = Rounds.size(roundList)
        switch Rounds.set(roundList, nextRoundId, Rounds.Round.fromArray(newMatches)) {
        | Some(newRoundList) => setTourney({...tourney, roundList: newRoundList})
        | None => ()
        }
      } else {
        Webapi.Dom.Window.alert(Webapi.Dom.window, "部分比赛结果未录入，或已到决赛。请先完成本轮所有比赛的录入。")
      }
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
    let newMatch = Match.manualPair(~team1, ~team2, ~timeLimitMinutes=tourney.timeLimitMinutes)
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

  let matchList = switch currRound {
  | Some(r) => Rounds.Round.toArray(r)
  | None => []
  }

  let matchCards = matchList->Array.mapWithIndex((m, _i) => {
    let card = MatchCard.fromMatch(m, getTeam, getPlayer)
    <MatchCard key={Id.toString(m.id)} match=card onRemove={() => handleRemoveMatch(m.id)} />
  })->React.array

  let formatDescription = switch format {
  | Tournament.Format.Swiss => React.string("瑞士移位制：每轮按积分配对")
  | Tournament.Format.GroupStage(_) => React.string("小组赛：蛇形分组 + 单循环")
  | Tournament.Format.Knockout(_) => React.string("淘汰赛：种子排位对阵")
  }

  <>
    <div className="round-layout">
      <div className="round-matches">
        <h2> {React.string("第 " ++ Int.toString(roundId + 1) ++ " 轮对阵")} </h2>
        <small className="caption-20"> {formatDescription} </small>
        <div className="match-card-list">
          {matchCards}
        </div>
        {if Array.length(matchList) == 0 {
          <EmptyState icon=EmptyState.Clipboard title="暂无对阵" description="请自动配对或手动添加对阵。" />
        } else {
          React.null
        }}
      </div>
      <div className="round-unmatched">
        <h3> {React.string("未配对队伍")} </h3>
        <p className="caption-20">
          {React.string("剩余 " ++ Int.toString(Id.Map.size(unmatched)) ++ " 支队伍")}
        </p>
        <div className="unmatched-list">
          {unmatched->Id.Map.valuesToArray->Array.map(t =>
            <div key={Id.toString(t.id)} className="unmatched-team-card">
              <strong> {React.string(t.name)} </strong>
            </div>
          )->React.array}
        </div>
      </div>
    </div>
    <div className="round-actions">
      {let isKnockout = switch format {
      | Tournament.Format.Knockout(_) => true
      | Tournament.Format.Swiss | Tournament.Format.GroupStage(_) => false
      }
      if isKnockout && Rounds.size(roundList) > 0 {
        if !data.isItOver && data.isNewRoundReady {
          <button className="button button-primary" onClick={_ => handleKnockoutNextRound()}>
            {React.string("从胜者生成下一轮淘汰对阵")}
          </button>
        } else {
          React.null
        }
      } else {
        <button className="button button-primary" onClick={_ => handleAutoPair()}>
          <Icons.Repeat />
          {React.string(" 自动配对未匹配队伍")}
        </button>
      }}
      <button className="button" onClick={_ => setShowPairPicker(_ => true)} style={marginLeft: "0.5rem"}>
        <Icons.Plus />
        {React.string(" 手动添加对阵")}
      </button>
    </div>
    {if showPairPicker {
      let pairedIds = matchList->Array.flatMap(m => [m.team1Id, m.team2Id])->Id.Set.fromArray
      let availableTeams = Id.Map.keep(unmatchedWithBye, (id, _) =>
        !Id.Set.has(pairedIds, id) || Id.isTeamBye(id)
      )
      <div className="round-pair-picker">
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
