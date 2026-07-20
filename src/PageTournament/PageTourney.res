/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/
open! Belt
open Data

module Inner = {
  @react.component
  let make = (~data: LoadTournament.t) => {
    let {tourney, setTourney, isNewRoundReady, isItOver, roundCount: _, _} = data
    let {roundList, _} = tourney

    let (activeTab, setActiveTab) = React.useState(() =>
      if Rounds.size(roundList) > 0 {
        Rounds.size(roundList) - 1
      } else {
        -1
      }
    )
    /* Use -1 for Status, round index for Round, 1000 + round index for Scores, etc. */
    /* Simple int encoding for active tab: -1=Status, -2=Setup, -3=Players, -4=Loading, n>=0=Round(n), 1000+n=Scores(n) */
    let tabIs = (v, _i) => activeTab == v
    let tabIsRound = i => activeTab == i
    let tabIsScores = i => activeTab == 1000 + i

    /* Map Pages.Page.t callbacks to activeTab switching */
    let goToPage = (page: Pages.Page.t) =>
      switch page {
      | TourneySetup(_) => setActiveTab(_ => -2)
      | TourneyPlayers(_) => setActiveTab(_ => -3)
      | Tourney(_) => setActiveTab(_ => -1)
      | TournamentList | Options | Players | Help | NotFound => ()
      }

    let handleNewRound = () => {
      let newRoundList = Rounds.addRound(roundList)
      let newRoundId = Rounds.size(newRoundList) - 1
      setTourney({...tourney, roundList: newRoundList})
      setActiveTab(_ => newRoundId)
    }

    let renderTab = () =>
      if activeTab < 0 {
        switch activeTab {
        | -2 => <PageTourneySetup tourney setTourney goToPage />
        | -3 => <PageTourneyPlayers tourney setTourney data goToPage />
        | -4 => React.string("加载中...")
        | _ => <PageTournamentStatus data />
        }
      } else if activeTab >= 1000 {
        <PageTourneyScores data roundId={activeTab - 1000} />
      } else {
        <PageRound roundId=activeTab data config=Config.default />
      }

    let isStatus = tabIs(activeTab, -1)
    let isSetupOrPlayers = tabIs(activeTab, -2) || tabIs(activeTab, -3)

    let makeRoundTabs = () => {
      let lastKey = Rounds.getLastKey(roundList)
      Array.makeBy(lastKey + 1, i => {
        let isComplete = Rounds.isRoundComplete(roundList, data.activeTeams, i)
        <button
          key={Int.toString(i)}
          className={"button button-micro" ++ (tabIsRound(i) ? " button-primary" : "")}
          onClick={_ => setActiveTab(_ => i)}>
          {React.string("第" ++ Int.toString(i + 1) ++ "轮")}
          {isComplete ? React.string(" ✓") : React.null}
        </button>
      })
    }

    let scoreRoundsTabs = () => {
      Array.makeBy(Rounds.size(roundList), i => {
        <button
          key={"score-" ++ Int.toString(i)}
          className={"button button-micro" ++ (tabIsScores(i) ? " button-primary" : "")}
          onClick={_ => setActiveTab(_ => 1000 + i)}>
          {React.string("录入第" ++ Int.toString(i + 1) ++ "轮")}
        </button>
      })
    }

    let isCurrentTabRound = activeTab >= 0 && activeTab < 1000

    <>
      <h1> {React.string(tourney.name)} </h1>
      <div style={marginBottom: "0.5rem"}>
        <button
          className={"button button-micro" ++ (isStatus ? " button-primary" : "")}
          onClick={_ => setActiveTab(_ => -1)}>
          {React.string("积分榜")}
        </button>
        <button
          className={"button button-micro" ++ (isSetupOrPlayers ? " button-primary" : "")}
          onClick={_ => setActiveTab(_ => -2)}>
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
