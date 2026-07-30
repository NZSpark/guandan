/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/
open Data

/* Tab navigation — use proper variants instead of magic ints */
type tab =
  | Status      /* 积分榜 */
  | Setup       /* 设置 */
  | Players     /* 选手管理 */
  | Round(int)  /* 第 i 轮 (0-based) */
  | Scores(int) /* 录入第 i 轮分数 (0-based) */
  | Bracket     /* 淘汰赛对阵图 */

module Inner = {
  @react.component
  let make = (~data: LoadTournament.t) => {
    let {tourney, setTourney, isNewRoundReady, isItOver, roundCount: _, _} = data
    let {roundList, format, _} = tourney

    let (activeTab, setActiveTab) = React.useState(() =>
      if Rounds.size(roundList) > 0 {
        Round(Rounds.size(roundList) - 1)
      } else {
        Status
      }
    )

    /* Map Pages.Page.t callbacks to activeTab switching */
    let goToPage = (page: Pages.Page.t) =>
      switch page {
      | TourneySetup(_) => setActiveTab(_ => Setup)
      | TourneyPlayers(_) => setActiveTab(_ => Players)
      | Tourney(_) => setActiveTab(_ => Status)
      | TournamentList | Options | Players | Help | NotFound => ()
      }

    let handleNewRound = () => {
      let newRoundList = Rounds.addRound(roundList)
      let newRoundId = Rounds.size(newRoundList) - 1
      setTourney({...tourney, roundList: newRoundList})
      setActiveTab(_ => Round(newRoundId))
    }

    /* 晋级下一阶段：根据积分榜自动选择晋级队伍并创建新赛事 */
    let handleAdvanceToNextStage = () => {
      let teamCount = Id.Map.size(data.activeTeams)
      switch StageAdvance.getNextStageParams(format, teamCount) {
      | None => ()
      | Some(params) =>
        let advanceCount = params.advanceCount
        let advancingTeamIds = switch format {
        | Tournament.Format.Swiss =>
          /* 海选赛 → 按积分榜取前N名 */
          let scoreData = Scoring.fromTournament(~roundList, ~scoreAdjustments=Id.Map.make())
          StageAdvance.getSwissAdvancingTeams(scoreData, advanceCount)
        | Tournament.Format.GroupStage({groupCount}) =>
          /* 小组赛 → 每组前2名，交叉对阵排列 */
          switch tourney.groupAssignments {
          | Some(ga) => StageAdvance.getGroupAdvancingTeams(roundList, ga, groupCount, ~perGroup=2)
          | None =>
            /* 无分组信息 → 按积分榜取前N名 */
            let scoreData = Scoring.fromTournament(~roundList, ~scoreAdjustments=Id.Map.make())
            StageAdvance.getSwissAdvancingTeams(scoreData, advanceCount)
          }
        | Tournament.Format.Knockout(_) => []
        }
        if Array.length(advancingTeamIds) > 0 {
          let newId = Id.random()
          let newTourneyName = tourney.name ++ " — " ++ params.name
          let newTeamIds = advancingTeamIds->Id.Set.fromArray
          let newTourney = Tournament.make(
            ~id=newId,
            ~name=newTourneyName,
            ~parentTourneyId=tourney.id,
            ~teamIds=newTeamIds,
          )
          /* 从 stageParam 构建具体的 Format */
          let newFormat = switch params.kind {
          | StageAdvance.SwissToGroup => Tournament.Format.GroupStage({groupCount: params.stageParam})
          | StageAdvance.GroupToKnockout => Tournament.Format.Knockout({teamCount: params.stageParam})
          }
          /* 瑞士轮 → 小组赛：保存种子分数用于种子排位 */
          let seedScores = switch format {
          | Tournament.Format.Swiss =>
            let scoreData = Scoring.fromTournament(~roundList, ~scoreAdjustments=Id.Map.make())
            Some(Id.Map.map(scoreData, s => s.totalFieldScore))
          | Tournament.Format.GroupStage(_) =>
            /* 小组赛 → 淘汰赛：按晋级顺序分配种子分（排名高的分高） */
            let n = Array.length(advancingTeamIds)
            let scorePairs = advancingTeamIds->Array.mapWithIndex((teamId, idx) =>
              (teamId, Float.fromInt(n - idx))
            )
            Some(scorePairs->Id.Map.fromArray)
          | Tournament.Format.Knockout(_) => None
          }
          let newTourneyWithFormat = {
            ...newTourney,
            format: newFormat,
            timeLimitMinutes: Some(params.timeLimitMinutes),
            seedScores,
          }
          /* 持久化新赛事并跳转 */
          Db.setTourney(newId, newTourneyWithFormat)->Promise.then(_ => {
            Webapi.Dom.Window.setLocation(Webapi.Dom.window, "/tourneys/" ++ Id.toString(newId))
            Promise.resolve()
          })->ignore
        } else {
          Webapi.Dom.Window.alert(Webapi.Dom.window, "没有队伍可以晋级。请检查比赛结果录入。")
        }
      }
    }

    /* 是否有下一阶段 */
    let hasNextStage = switch StageAdvance.getNextStageParams(format, Id.Map.size(data.activeTeams)) {
    | Some(_) => true
    | None => false
    }

    let isKnockout = switch format {
    | Tournament.Format.Knockout(_) => true
    | Tournament.Format.Swiss | Tournament.Format.GroupStage(_) => false
    }

    let renderTab = () =>
      switch activeTab {
      | Setup => <PageTourneySetup tourney setTourney goToPage />
      | Players => <PageTourneyPlayers tourney setTourney data goToPage />
      | Status => <PageTournamentStatus data />
      | Scores(i) => <PageTourneyScores data roundId=i />
      | Round(i) => <PageRound roundId=i data config=Config.default />
      | Bracket => <BracketView roundList activeTeams=data.activeTeams getTeam=data.getTeam />
      }

    let isStatus = switch activeTab { | Status => true | Setup | Players | Round(_) | Scores(_) | Bracket => false }
    let isSetupOrPlayers = switch activeTab { | Setup | Players => true | Status | Round(_) | Scores(_) | Bracket => false }
    let isBracket = switch activeTab { | Bracket => true | Status | Setup | Players | Round(_) | Scores(_) => false }

    /* Round tab buttons */
    let makeRoundTabs = () => {
      let lastKey = Rounds.getLastKey(roundList)
      Array.fromInitializer(~length=lastKey + 1, i => {
        let isComplete = Rounds.isRoundComplete(roundList, data.activeTeams, i)
        let isSelected = switch activeTab { | Round(j) => i == j | Status | Setup | Players | Scores(_) | Bracket => false }
        <button
          key={Int.toString(i)}
          className={"button button-micro" ++ (isSelected ? " button-primary" : "")}
          onClick={_ => setActiveTab(_ => Round(i))}>
          {React.string("第" ++ Int.toString(i + 1) ++ "轮")}
          {isComplete ? React.string(" ✓") : React.null}
        </button>
      })
    }

    let scoreRoundsTabs = () => {
      Array.fromInitializer(~length=Rounds.size(roundList), i => {
        let isSelected = switch activeTab { | Scores(j) => i == j | Status | Setup | Players | Round(_) | Bracket => false }
        <button
          key={"score-" ++ Int.toString(i)}
          className={"button button-micro" ++ (isSelected ? " button-primary" : "")}
          onClick={_ => setActiveTab(_ => Scores(i))}>
          {React.string("录入第" ++ Int.toString(i + 1) ++ "轮")}
        </button>
      })
    }

    <>
      <Breadcrumbs items=[
        {label: "赛事列表", to_: Router.TournamentList},
        {label: tourney.name, to_: Router.Tournament(tourney.id)},
      ] />
      <h1 className="tourney-title"> {React.string(tourney.name)} </h1>
      <div className="tourney-format-badge">
        {React.string(Tournament.Format.label(format))}
      </div>

      /* ---- Tab Groups ---- */
      <div className="tourney-tab-groups">
        <div className="tourney-tab-group">
          <span className="tourney-tab-group-label"> {React.string("概览")} </span>
          <div className="tourney-tab-row">
            <button
              className={"button button-micro" ++ (isStatus ? " button-primary" : "")}
              onClick={_ => setActiveTab(_ => Status)}>
              <Icons.List />
              {React.string(" 积分榜")}
            </button>
            <button
              className={"button button-micro" ++ (isSetupOrPlayers ? " button-primary" : "")}
              onClick={_ => setActiveTab(_ => Setup)}>
              <Icons.Settings />
              {React.string(" 设置")}
            </button>
            {if isKnockout && Rounds.size(roundList) > 0 {
              <button
                className={"button button-micro" ++ (isBracket ? " button-primary" : "")}
                onClick={_ => setActiveTab(_ => Bracket)}>
                <Icons.Layers />
                {React.string(" 对阵图")}
              </button>
            } else {
              React.null
            }}
          </div>
        </div>

        {if Rounds.size(roundList) > 0 {
          <div className="tourney-tab-group">
            <span className="tourney-tab-group-label"> {React.string("对阵")} </span>
            <div className="tourney-tab-row">
              {makeRoundTabs()->React.array}
            </div>
          </div>
        } else {
          React.null
        }}

        {if Rounds.size(roundList) > 0 {
          <div className="tourney-tab-group">
            <span className="tourney-tab-group-label"> {React.string("录入")} </span>
            <div className="tourney-tab-row">
              {scoreRoundsTabs()->React.array}
            </div>
          </div>
        } else {
          React.null
        }}

        /* ---- Actions ---- */
        {if isNewRoundReady {
          <div className="tourney-actions">
            {!isItOver
              ? <button className="button button-primary" onClick={_ => handleNewRound()}>
                  {React.string("+ 开始新一轮")}
                </button>
              : React.null}
            {if isItOver {
              <>
                <div className="tourney-done-badge">
                  <Icons.CheckCircle />
                  {React.string(" 赛事已完成！查看积分榜查看最终排名。")}
                </div>
                {if hasNextStage {
                  <button className="button button-primary"
                    onClick={_ => handleAdvanceToNextStage()}>
                    <Icons.Repeat />
                    {React.string(" 晋级下一阶段")}
                  </button>
                } else {
                  React.null
                }}
              </>
            } else {
              React.null
            }}
          </div>
        } else {
          React.null
        }}
      </div>

      {renderTab()}
    </>
  }
}

@react.component
let make = (~tourneyId: Data.Id.t, ~windowDispatch: Window.action => unit) => {
  <LoadTournament tourneyId windowDispatch={Some(windowDispatch)}>
    {data => <Inner data />}
  </LoadTournament>
}
