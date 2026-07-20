/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  队伍配对引擎（瑞士移位制）。
*/
type team

let id: team => Data_Id.t

type t

let teams: t => Data_Id.Map.t<team>

let maxPriority: t => float

let make: (Data_Id.Map.t<Data_Scoring.t>, Data_Id.Map.t<Data_Team.t>, Data_Id.Pair.Set.t) => t

let keep: (t, ~f: (Data_Id.t, team) => bool) => t

let calcPairIdeal: (team, team, ~maxScore: float) => float

let calcPairIdealByIds: (t, Data_Id.t, Data_Id.t) => option<float>

let setByeTeam: (array<Data_Id.t>, Data_Id.t, t) => (t, option<team>)

let pairTeams: t => array<(Data_Id.t, Data_Id.t)>
