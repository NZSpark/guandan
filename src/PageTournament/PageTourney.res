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
    let isCurrentTabRound = switch activeTab { | Round(_) => true | Status | Setup | Players | Scores(_) | Bracket => false }
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
        {if isNewRoundReady && (isCurrentTabRound || Rounds.size(roundList) == 0) {
          <div className="tourney-actions">
            {!isItOver
              ? <button className="button button-primary" onClick={_ => handleNewRound()}>
                  {React.string("+ 开始新一轮")}
                </button>
              : React.null}
            {if isItOver {
              <div className="tourney-done-badge">
                <Icons.CheckCircle />
                {React.string(" 赛事已完成！查看积分榜查看最终排名。")}
              </div>
            } else {
              React.null
            }}
          </div>
        } else if isNewRoundReady {
          React.null
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
