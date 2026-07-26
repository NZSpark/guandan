/*
  Knockout tournament bracket visualization.
  Uses CSS flex layout for 16/8/4 team brackets.
*/
open Data
module Id = Data_Id

type bracketMatch = {
  team1Name: string,
  team2Name: string,
  team1Won: bool,
  team2Won: bool,
  score: string,
}

type bracketRound = {
  name: string,
  matches: array<bracketMatch>,
}

let getScore = (m: Match.t): string =>
  switch m.result.winner {
  | Some(Match.Result.Team1Won) =>
    let diff = Data_Level.levelDiff(m.result.team1Level, m.result.team2Level)
    "胜 (级差+" ++ Int.toString(diff) ++ ")"
  | Some(Match.Result.Team2Won) =>
    let diff = Data_Level.levelDiff(m.result.team2Level, m.result.team1Level)
    "胜 (级差+" ++ Int.toString(diff) ++ ")"
  | None =>
    let l1 = Data_Level.toString(m.result.team1Level)
    let l2 = Data_Level.toString(m.result.team2Level)
    if l1 == "2" && l2 == "2" { "" } else { l1 ++ "-" ++ l2 }
  }

let roundName = (totalRounds, rIdx) =>
  if totalRounds >= 4 {
    switch rIdx {
    | 0 => "16强"
    | 1 => "1/4决赛"
    | 2 => "半决赛"
    | 3 => "决赛"
    | _ => "第" ++ Int.toString(rIdx + 1) ++ "轮"
    }
  } else if totalRounds == 3 {
    switch rIdx {
    | 0 => "1/4决赛"
    | 1 => "半决赛"
    | 2 => "决赛"
    | _ => "第" ++ Int.toString(rIdx + 1) ++ "轮"
    }
  } else if totalRounds == 2 {
    switch rIdx {
    | 0 => "半决赛"
    | 1 => "决赛"
    | _ => "第" ++ Int.toString(rIdx + 1) ++ "轮"
    }
  } else {
    "第" ++ Int.toString(rIdx + 1) ++ "轮"
  }

@react.component
let make = (
  ~roundList: Data_Rounds.t,
  ~activeTeams as _activeTeams: Id.Map.t<Team.t>,
  ~getTeam: Id.t => option<Team.t>,
) => {
  let totalRounds = Rounds.size(roundList)

  let rounds = React.useMemo1(() =>
    Array.fromInitializer(~length=totalRounds, rIdx => {
      let name = roundName(totalRounds, rIdx)
      let matches = switch Rounds.get(roundList, rIdx) {
      | Some(r) =>
        Rounds.Round.toArray(r)->Array.mapWithIndex((m, _) => {
          let t1Name =
            if Id.isTeamBye(m.team1Id) {
              "[待定]"
            } else {
              switch getTeam(m.team1Id) {
              | Some(t) => t.name
              | None => "?"
              }
            }
          let t2Name =
            if Id.isTeamBye(m.team2Id) {
              "[待定]"
            } else {
              switch getTeam(m.team2Id) {
              | Some(t) => t.name
              | None => "?"
              }
            }
          {
            team1Name: t1Name,
            team2Name: t2Name,
            team1Won: switch m.result.winner {
            | Some(Match.Result.Team1Won) => true
            | Some(Match.Result.Team2Won) => false
            | None => false
            },
            team2Won: switch m.result.winner {
            | Some(Match.Result.Team2Won) => true
            | Some(Match.Result.Team1Won) => false
            | None => false
            },
            score: getScore(m),
          }
        })
      | None => []
      }
      {name, matches}
    }),
    [roundList],
  )

  if totalRounds == 0 {
    <EmptyState icon=EmptyState.Calendar title="暂无淘汰赛数据" description="淘汰赛对阵表将在此展示。" />
  } else {
    <div className="bracket-wrapper">
      <div className="bracket">
        {rounds->Array.mapWithIndex((r, rIdx) =>
          <div key={"r-" ++ Int.toString(rIdx)} className="bracket-column">
            <div className="bracket-column-header">
              {React.string(r.name)}
            </div>
            <div className="bracket-column-body">
              {r.matches->Array.mapWithIndex((m, mIdx) =>
                <div key={"m-" ++ Int.toString(rIdx) ++ "-" ++ Int.toString(mIdx)} className="bracket-match">
                  <div className="bracket-match-card">
                    <div className={"bracket-team" ++ (m.team1Won ? " bracket-team-won" : "")}>
                      <span className="bracket-team-name"> {React.string(m.team1Name)} </span>
                    </div>
                    <div className={"bracket-team" ++ (m.team2Won ? " bracket-team-won" : "")}>
                      <span className="bracket-team-name"> {React.string(m.team2Name)} </span>
                    </div>
                    {if m.score != "" {
                      <div className="bracket-score">
                        {React.string(m.score)}
                      </div>
                    } else {
                      React.null
                    }}
                  </div>
                </div>
              )->React.array}
            </div>
          </div>
        )->React.array}
      </div>
    </div>
  }
}
