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
let make = (
  ~tourney: Tournament.t,
  ~setTourney: Tournament.t => unit,
  ~data: LoadTournament.t,
  ~goToPage: Pages.Page.t => unit,
) => {
  let {teams, getPlayer, _} = data
  let {teamIds, _} = tourney

  let toggleTeam = (id: Id.t) =>
    if Set.has(teamIds, id) {
      setTourney({...tourney, teamIds: Set.remove(teamIds, id)})
    } else {
      setTourney({...tourney, teamIds: Set.add(teamIds, id)})
    }

  let allTeams = teams->Map.valuesToArray->SortArray.stableSortBy((a, b) =>
    compare(a.name, b.name)
  )

  let selectedCount = Set.toArray(teamIds)->Array.length

  <>
    <h2> {React.string("赛事队伍 — " ++ tourney.name)} </h2>
    <p>
      {React.string("已选 " ++ Int.toString(selectedCount) ++ " 支队伍")}
    </p>
    <div className="grid">
      {allTeams->Array.map(t => {
        let isSelected = Set.has(teamIds, t.id)
        let p1 = getPlayer(t.player1Id)
        let p2 = getPlayer(t.player2Id)
        <div
          key={Id.toString(t.id)}
          className={"card" ++ (isSelected ? " card-selected" : "")}
          onClick={_ => toggleTeam(t.id)}
          style={cursor: "pointer"}>
          <div className="card-body">
            <h4 className="card-title"> {React.string(t.name)} </h4>
            <p className="card-text">
              {React.string(p1.firstName ++ " " ++ p1.lastName ++ " / " ++ p2.firstName ++ " " ++ p2.lastName)}
            </p>
          </div>
        </div>
      })->React.array}
    </div>
    <div style={marginTop: "1rem"}>
      <button
        className="button button-primary"
        onClick={_ => goToPage(Pages.Page.Tourney(tourney.id))}
        disabled={selectedCount < 2}>
        {React.string("完成选择，进入锦标赛")}
      </button>
      <button
        className="button"
        onClick={_ => goToPage(Pages.Page.TourneySetup(tourney.id))}
        style={marginLeft: "0.5rem"}>
        {React.string("返回设置")}
      </button>
    </div>
  </>
}
