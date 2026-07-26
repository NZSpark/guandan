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
let make = (
  ~tourney: Tournament.t,
  ~setTourney: Tournament.t => unit,
  ~data: LoadTournament.t,
  ~goToPage: Pages.Page.t => unit,
) => {
  let {teams, getPlayer, _} = data
  let {teamIds, _} = tourney

  let toggleTeam = (id: Id.t) =>
    if Id.Set.has(teamIds, id) {
      setTourney({...tourney, teamIds: Id.Set.remove(teamIds, id)})
    } else {
      setTourney({...tourney, teamIds: Id.Set.add(teamIds, id)})
    }

  let allTeams = teams->Id.Map.valuesToArray->Utils.Array.toSortedByInt((a, b) =>
    compare(a.name, b.name)
  )

  let selectedCount = Id.Set.toArray(teamIds)->Array.length

  <>
    <div className="players-header">
      <h2> {React.string("赛事队伍 — " ++ tourney.name)} </h2>
      <span className="players-count-badge">
        <Icons.Users />
        {React.string(" 已选 " ++ Int.toString(selectedCount) ++ " 队")}
      </span>
    </div>

    {if Array.length(allTeams) == 0 {
      <EmptyState icon=EmptyState.Users title="暂无队伍" description="请先在队伍管理中添加参考队伍。" />
    } else {
      <div className="players-grid">
        {allTeams->Array.map(t => {
          let isSelected = Id.Set.has(teamIds, t.id)
          let p1 = getPlayer(t.player1Id)
          let p2 = getPlayer(t.player2Id)
          <div
            key={Id.toString(t.id)}
            className={"player-select-card" ++ (isSelected ? " player-select-card--active" : "")}
            onClick={_ => toggleTeam(t.id)}
            role="checkbox"
            ariaChecked={isSelected ? #\"true" : #\"false"}>
            {if isSelected {
              <span className="player-select-check">
                <Icons.Check />
              </span>
            } else {
              React.null
            }}
            <div className="player-select-card-body">
              <strong className="player-select-card-name"> {React.string(t.name)} </strong>
              <span className="player-select-card-players">
                {React.string(p1.firstName ++ " " ++ p1.lastName ++ " / " ++ p2.firstName ++ " " ++ p2.lastName)}
              </span>
            </div>
          </div>
        })->React.array}
      </div>
    }}

    <div className="players-actions">
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
