/*
  Match card component — visually displays a matchup between two teams.
  Used in round viewing and score entry contexts.
*/
open Data
module Id = Data_Id

type result =
  | Team1Won(int)
  | Team2Won(int)
  | Draw(Data_Level.t, Data_Level.t)
  | Unplayed

type t = {
  team1Name: string,
  team1Players: string,
  team2Name: string,
  team2Players: string,
  result: result,
  isBye: bool,
}

let fromMatch = (m: Match.t, getTeam: Id.t => option<Team.t>, getPlayer: Id.t => Player.t): t => {
  let teamInfo = teamId => {
    if Id.isTeamBye(teamId) {
      ("[轮空]", "")
    } else {
      switch getTeam(teamId) {
      | Some(t) => {
        let p1 = getPlayer(t.player1Id)
        let p2 = getPlayer(t.player2Id)
        (t.name, p1.firstName ++ " " ++ p1.lastName ++ " / " ++ p2.firstName ++ " " ++ p2.lastName)
        }
      | None => ("未知", "")
      }
    }
  }

  let (t1Name, t1Players) = teamInfo(m.team1Id)
  let (t2Name, t2Players) = teamInfo(m.team2Id)

  let isDefaultLevel = (l: Data_Level.t) => Data_Level.toInt(l) == 2
  let result = switch m.result.winner {
  | Some(Match.Result.Team1Won) =>
    let diff = Data_Level.levelDiff(m.result.team1Level, m.result.team2Level)
    Team1Won(diff)
  | Some(Match.Result.Team2Won) =>
    let diff = Data_Level.levelDiff(m.result.team2Level, m.result.team1Level)
    Team2Won(diff)
  | None =>
    let l1 = m.result.team1Level
    let l2 = m.result.team2Level
    if isDefaultLevel(l1) && isDefaultLevel(l2) {
      Unplayed
    } else {
      Draw(l1, l2)
    }
  }

  {team1Name: t1Name, team1Players: t1Players, team2Name: t2Name, team2Players: t2Players, result, isBye: Match.isBye(m)}
}

let resultSummary = (m: t): string =>
  switch m.result {
  | Team1Won(diff) => m.team1Name ++ " 胜 (级差+" ++ Int.toString(diff) ++ ")"
  | Team2Won(diff) => m.team2Name ++ " 胜 (级差+" ++ Int.toString(diff) ++ ")"
  | Draw(l1, l2) => "平级 " ++ Data_Level.toString(l1) ++ "-" ++ Data_Level.toString(l2)
  | Unplayed => "未开赛"
  }

@react.component
let make = (
  ~match: t,
  ~onRemove: option<unit => unit>=?,
  ~compact: bool=false,
) => {
  let t1Won = switch match.result { | Team1Won(_) => true | Team2Won(_) | Draw(_, _) | Unplayed => false }
  let t2Won = switch match.result { | Team2Won(_) => true | Team1Won(_) | Draw(_, _) | Unplayed => false }

  <div className={"match-card" ++ (t1Won || t2Won ? " match-card-decided" : "")}>
    <div className="match-card-body">
      <div className={"match-card-team" ++ (t1Won ? " match-card-team-won" : "")}>
        <span className="match-card-team-name"> {React.string(match.team1Name)} </span>
        {if !compact && match.team1Players != "" {
          <span className="match-card-team-players"> {React.string(match.team1Players)} </span>
        } else {
          React.null
        }}
        {if t1Won {
          <span className="match-card-winner-badge"> {React.string("胜")} </span>
        } else {
          React.null
        }}
      </div>
      <div className="match-card-vs">
        <span className="match-card-vs-label"> {React.string("VS")} </span>
      </div>
      <div className={"match-card-team" ++ (t2Won ? " match-card-team-won" : "")}>
        <span className="match-card-team-name"> {React.string(match.team2Name)} </span>
        {if !compact && match.team2Players != "" {
          <span className="match-card-team-players"> {React.string(match.team2Players)} </span>
        } else {
          React.null
        }}
        {if t2Won {
          <span className="match-card-winner-badge"> {React.string("胜")} </span>
        } else {
          React.null
        }}
      </div>
      {switch onRemove {
        | Some(fn) =>
          <button
            className="match-card-remove"
            onClick={_ => fn()}
            title="移除此对阵"
            ariaLabel="移除此对阵">
            {React.string("×")}
          </button>
        | None => React.null
      }}
    </div>
    {if match.isBye {
      <div className="match-card-bye"> {React.string("轮空 — 自动判胜")} </div>
    } else {
      React.null
    }}
    {let summary = resultSummary(match)
     if summary != "未开赛" {
       <div className="match-card-result"> {React.string(summary)} </div>
     } else {
       React.null
     }}
  </div>
}
