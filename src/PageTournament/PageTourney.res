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

module Inner = {
  @react.component
  let make = (~data: LoadTournament.t) => {
    let {tourney, setTourney, isNewRoundReady, isItOver, roundCount: _, _} = data
    let {roundList, _} = tourney

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

    let renderTab = () =>
      switch activeTab {
      | Setup => <PageTourneySetup tourney setTourney goToPage />
      | Players => <PageTourneyPlayers tourney setTourney data goToPage />
      | Status => <PageTournamentStatus data />
      | Scores(i) => <PageTourneyScores data roundId=i />
      | Round(i) => <PageRound roundId=i data config=Config.default />
      }

    let isStatus = switch activeTab { | Status => true | Setup | Players | Round(_) | Scores(_) => false }
    let isSetupOrPlayers = switch activeTab { | Setup | Players => true | Status | Round(_) | Scores(_) => false }

    let makeRoundTabs = () => {
      let lastKey = Rounds.getLastKey(roundList)
      Array.fromInitializer(~length=lastKey + 1, i => {
        let isComplete = Rounds.isRoundComplete(roundList, data.activeTeams, i)
        let isSelected = switch activeTab { | Round(j) => i == j | Status | Setup | Players | Scores(_) => false }
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
        let isSelected = switch activeTab { | Scores(j) => i == j | Status | Setup | Players | Round(_) => false }
        <button
          key={"score-" ++ Int.toString(i)}
          className={"button button-micro" ++ (isSelected ? " button-primary" : "")}
          onClick={_ => setActiveTab(_ => Scores(i))}>
          {React.string("录入第" ++ Int.toString(i + 1) ++ "轮")}
        </button>
      })
    }

    let isCurrentTabRound = switch activeTab { | Round(_) => true | Status | Setup | Players | Scores(_) => false }

    <>
      <h1> {React.string(tourney.name)} </h1>
      <div style={marginBottom: "0.5rem"}>
        <button
          className={"button button-micro" ++ (isStatus ? " button-primary" : "")}
          onClick={_ => setActiveTab(_ => Status)}>
          {React.string("积分榜")}
        </button>
        <button
          className={"button button-micro" ++ (isSetupOrPlayers ? " button-primary" : "")}
          onClick={_ => setActiveTab(_ => Setup)}>
          {React.string("设置")}
        </button>
        {makeRoundTabs()->React.array}
        {scoreRoundsTabs()->React.array}
      </div>
      {if isNewRoundReady && isCurrentTabRound {
        <>
          {!isItOver
            ? <button className="button button-primary" onClick={_ => handleNewRound()} style={marginBottom: "1rem"}>
                {React.string("+ 开始新一轮")}
              </button>
            : <p style={color: "green", fontWeight: "bold"}>
                {React.string("赛事已完成！查看积分榜查看最终排名。")}
              </p>}
        </>
      } else {
        React.null
      }}
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
