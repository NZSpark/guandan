/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0.
*/
open! Belt
open Data
module Id = Data.Id

type teamCard = {
  team: Team.t,
  playerInfo: string,
}

let makeCard = (~team: Team.t, ~getPlayer: Id.t => Player.t): teamCard => {
  let p1 = getPlayer(team.player1Id)
  let p2 = getPlayer(team.player2Id)
  {
    team,
    playerInfo: p1->Player.fullName ++ " / " ++ p2->Player.fullName,
  }
}

module TeamCard = {
  @react.component
  let make = (~card: teamCard) =>
    <div className="card">
      <div className="card-body">
        <h4 className="card-title"> {React.string(card.team.name)} </h4>
        <p className="card-text"> {React.string(card.playerInfo)} </p>
      </div>
    </div>
}

@react.component
let make = (
  ~teams: Id.Map.t<Team.t>,
  ~getPlayer: Id.t => Player.t,
  ~onAdd: (Team.t, Team.t) => unit,
  ~onCancel: unit => unit,
) => {
  let (team1Selected, setTeam1) = React.useState(() => (None: option<Team.t>))
  let (team2Selected, setTeam2) = React.useState(() => (None: option<Team.t>))

  let handleSelectTeam = (team: Team.t) =>
    switch (team1Selected, team2Selected) {
    | (None, _) => setTeam1(_ => Some(team))
    | (Some(_), None) => setTeam2(_ => Some(team))
    | (Some(_), Some(_)) => ()
    }

  let handleConfirm = () =>
    switch (team1Selected, team2Selected) {
    | (Some(t1), Some(t2)) => onAdd(t1, t2)
    | _ => ()
    }

  let teamList = teams->Map.valuesToArray->Array.map(t => makeCard(~team=t, ~getPlayer))

  let teamButtons = teamList->Array.map(card => {
    let isSelected = switch (team1Selected, team2Selected) {
    | (Some(t), _) => Id.eq(t.id, card.team.id)
    | (_, Some(t)) => Id.eq(t.id, card.team.id)
    | _ => false
    }
    <button
      key={Id.toString(card.team.id)}
      className={"button" ++ (isSelected ? " button-selected" : "")}
      onClick={_ => handleSelectTeam(card.team)}
      disabled={isSelected}>
      <TeamCard card />
    </button>
  })->React.array

  <>
    <h2> {React.string("选择两支队伍对阵")} </h2>
    <p>
      {switch (team1Selected, team2Selected) {
      | (None, _) => React.string("请选择队伍1")
      | (Some(t1), None) => React.string("已选: " ++ t1.name ++ " — 请选择队伍2")
      | (Some(t1), Some(t2)) => React.string("已选: " ++ t1.name ++ " vs " ++ t2.name)
      }}
    </p>
    <div className="grid"> {teamButtons} </div>
    <div style={marginTop: "1rem"}>
      <button
        className="button button-primary"
        onClick={_ => handleConfirm()}
        disabled={switch (team1Selected, team2Selected) {
        | (Some(_), Some(_)) => false
        | _ => true
        }}>
        {React.string("确认对阵")}
      </button>
      <button className="button" onClick={_ => onCancel()} style={marginLeft: "0.5rem"}>
        {React.string("取消")}
      </button>
    </div>
  </>
}
