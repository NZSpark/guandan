/*
  Tournament dashboard summary cards.
  Shows tournament progress, top teams, and key stats at a glance.
*/
open Data
module Id = Data_Id

type teamInfo = {
  id: Id.t,
  name: string,
  fieldScore: float,
  rank: int,
}

@react.component
let make = (
  ~data: LoadTournament.t,
  ~standings: array<Scoring.teamScores>,
  ~roundStatus: array<bool>, /* which rounds are complete */
) => {
  let {tourney, isItOver, isNewRoundReady: _, roundCount, activeTeams, getTeam, _} = data
  let {roundList, format, _} = tourney
  let currentRound = Rounds.size(roundList)
  let totalRounds = roundCount
  let progressPct = if totalRounds > 0 {
    int_of_float(float_of_int(currentRound) /. float_of_int(totalRounds) *. 100.0)
  } else {
    0
  }

  let completedRounds = roundStatus->Array.filter(x => x)->Array.length
  let hasStarted = currentRound > 0

  let topTeams: array<teamInfo> = standings->Array.slice(~start=0, ~end=min(3, Array.length(standings)))->Array.mapWithIndex((s, i) => {
    {id: s.id, name: "", fieldScore: s.fieldScore, rank: i}
  })

  /* Resolve team names */
  let topTeamsWithNames = topTeams->Array.map(t =>
    switch getTeam(t.id) {
    | Some(team) => {...t, name: team.name}
    | None => t
    }
  )

  let teamCount = Id.Map.size(activeTeams)
  let formatLabel = Tournament.Format.label(format)
  let statusText =
    if isItOver { "已结束" }
    else if hasStarted { "进行中" }
    else { "准备开始" }

  let statusClass =
    if isItOver { "dashboard-status-done" }
    else if hasStarted { "dashboard-status-active" }
    else { "dashboard-status-ready" }

  <>
    <div className="dashboard-summary">
      <div className="dashboard-card">
        <div className="dashboard-card-icon">
          <Icons.Info />
        </div>
        <div className="dashboard-card-body">
          <span className="dashboard-card-label"> {React.string("状态")} </span>
          <span className={"dashboard-card-value " ++ statusClass}>
            {React.string(statusText)}
          </span>
        </div>
      </div>
      <div className="dashboard-card">
        <div className="dashboard-card-icon">
          <Icons.Award />
        </div>
        <div className="dashboard-card-body">
          <span className="dashboard-card-label"> {React.string("赛制")} </span>
          <span className="dashboard-card-value">
            {React.string(formatLabel)}
          </span>
        </div>
      </div>
      <div className="dashboard-card">
        <div className="dashboard-card-icon">
          <Icons.Users />
        </div>
        <div className="dashboard-card-body">
          <span className="dashboard-card-label"> {React.string("队伍")} </span>
          <span className="dashboard-card-value">
            {React.string(Int.toString(teamCount) ++ " 队")}
          </span>
        </div>
      </div>
      <div className="dashboard-card">
        <div className="dashboard-card-icon">
          <Icons.Layers />
        </div>
        <div className="dashboard-card-body">
          <span className="dashboard-card-label"> {React.string("进度")} </span>
          <span className="dashboard-card-value">
            {React.string(Int.toString(completedRounds) ++ "/" ++ Int.toString(totalRounds) ++ " 轮")}
          </span>
        </div>
      </div>
      {hasStarted && !isItOver
        ? <div className="dashboard-card dashboard-progress">
            <div className="dashboard-card-body" style={width: "100%"}>
              <span className="dashboard-card-label"> {React.string("完成度")} </span>
              <div className="progress-bar">
                <div className="progress-fill" style={width: Int.toString(progressPct) ++ "%"} />
              </div>
              <span className="dashboard-card-value" style={textAlign: "right", fontSize: "var(--font-caption-20)"}>
                {React.string(Int.toString(progressPct) ++ "%")}
              </span>
            </div>
          </div>
        : React.null}
    </div>
    {if Array.length(topTeamsWithNames) > 0 && hasStarted {
      <div className="dashboard-leaders">
        <h3 style={margin: "0 0 0.5rem 0"}>
          {React.string("领跑队伍")}
        </h3>
        <div className="dashboard-leaders-grid">
          {topTeamsWithNames->Array.mapWithIndex((t, i) =>
            <div key={Id.toString(t.id)} className={"dashboard-leader-card dashboard-leader-" ++ Int.toString(i + 1)}>
              <div className="leader-rank">
                {switch i {
                | 0 => <span className="standings-medal medal-gold" style={width: "24px", height: "24px", fontSize: "12px"}> {React.string("1")} </span>
                | 1 => <span className="standings-medal medal-silver" style={width: "24px", height: "24px", fontSize: "12px"}> {React.string("2")} </span>
                | 2 => <span className="standings-medal medal-bronze" style={width: "24px", height: "24px", fontSize: "12px"}> {React.string("3")} </span>
                | _ => React.null
                }}
              </div>
              <div className="leader-name">
                <strong> {React.string(t.name)} </strong>
              </div>
              <div className="leader-score">
                <span className={t.fieldScore > 0.0 ? "score-positive" : "score-neutral"}>
                  {let fs = t.fieldScore
                   if fs == 0.0 {
                     React.string("0")
                   } else if fs > 0.0 {
                     React.string("+" ++ Js.Float.toFixedWithPrecision(fs, ~digits=1))
                   } else {
                     React.string(Js.Float.toFixedWithPrecision(fs, ~digits=1))
                   }}
                </span>
              </div>
            </div>
          )->React.array}
        </div>
      </div>
    } else {
      React.null
    }}
  </>
}
