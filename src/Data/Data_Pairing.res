/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  队伍配对引擎（瑞士移位制）。
  去掉颜色平衡，维度: 避免已对阵 > 避免同俱乐部 > 场分相近 > 上下半区交叉
*/
module Id = Data_Id

@deriving(accessors)
type team = {
  id: Id.t,
  avoidIds: Id.Set.t,
  halfPos: int,
  isUpperHalf: bool,
  opponents: list<Id.t>,
  score: float,
}

@deriving(accessors)
type t = {
  teams: Id.Map.t<team>,
  maxScore: float,
  maxPriority: float,
}

let descendingScore = Utils.descend(compare, x => x.score, ...)

let splitInHalf = arr => {
  let midpoint = try {
    Array.length(arr) / 2
  } catch {
  | Division_by_zero => 0
  }
  (Array.slice(arr, ~start=0, ~end=midpoint), Array.sliceToEnd(arr, ~start=midpoint))
}

/*
 确定每支队伍所属半区及半区内排名位置。
 */
let setUpperHalves = data => {
  let dataArr = Id.Map.valuesToArray(data)
  Id.Map.map(data, teamData => {
    let (upperHalfIds, lowerHalfIds) =
      dataArr
      ->Array.filter(({score, _}) => score == teamData.score)
      ->Utils.Array.toSortedByInt(descendingScore)
      ->splitInHalf
    let getIndex = Array.findIndexOpt(_, x => Id.eq(x.id, teamData.id))
    let (halfPos, isUpperHalf) = switch (getIndex(upperHalfIds), getIndex(lowerHalfIds)) {
    | (Some(index), Some(_))
    | (Some(index), None) => (index, true)
    | (None, Some(index)) => (index, false)
    | (None, None) => (0, false)
    }
    {...teamData, halfPos, isUpperHalf}
  })
}

/*
 配对优先级: 避免已对阵 > 场分相近 > 上下半区交叉
 */
let priority = (~isDiffHalf, ~halfPosDiff, ~scoreDiff, ~canMeet, ~maxScore) => {
  let halves = isDiffHalf ? 4. /. (halfPosDiff +. 1.) : 0.
  let scores = maxScore *. 16. -. scoreDiff *. 16.
  let canMeet = canMeet ? 32. *. maxScore : 0.
  halves +. scores +. canMeet
}

let calcMaxPriority = priority(~isDiffHalf=true, ~halfPosDiff=0., ~scoreDiff=0., ~canMeet=true, ...)

let calcMaxScore = m => Id.Map.reduce(m, 0., (acc, _, p) => max(acc, p.score))

let make = (scoreData, teamData, avoidPairs, ~avoidClubs=false) => {
  let avoidMap = Data_Id.Pair.Set.toMap(avoidPairs)
  /* Build a club->teamId index for club avoidance */
  let clubTeams: Js.Dict.t<list<Id.t>> = if avoidClubs {
    let dict = Js.Dict.empty()
    let allTeams = Id.Map.toArray(teamData)
    Array.forEach(allTeams, ((_, team: Data_Team.t)) => {
      if team.club != "" {
        switch Js.Dict.get(dict, team.club) {
        | Some(ids) => Js.Dict.set(dict, team.club, list{team.id, ...ids})
        | None => Js.Dict.set(dict, team.club, list{team.id})
        }
      }
    })
    dict
  } else {
    Js.Dict.empty()
  }
  let clubMates = id => {
    if !avoidClubs {
      Id.Set.make()
    } else {
      switch Id.Map.get(teamData, id) {
      | Some(team) if team.club != "" =>
        switch Js.Dict.get(clubTeams, team.club) {
        | Some(mates) => mates->List.filter(mateId => !Id.eq(mateId, id))->List.toArray->Id.Set.fromArray
        | None => Id.Set.make()
        }
      | _ => Id.Set.make()
      }
    }
  }
  let teams = Id.Map.mapWithKey(teamData, (key, data: Data_Team.t) => {
    let teamStats = switch Id.Map.get(scoreData, key) {
    | None => Data_Scoring.make(key)
    | Some(x) => x
    }
    let newAvoidIds = switch Id.Map.get(avoidMap, key) {
    | None => clubMates(key)
    | Some(x) => Id.Set.union(x, clubMates(key))
    }
    {
      avoidIds: newAvoidIds,
      halfPos: 0,
      id: data.id,
      isUpperHalf: false,
      opponents: teamStats.opponentResults->List.map(((id, _)) => id),
      score: teamStats.totalFieldScore,
    }
  })->setUpperHalves
  let maxScore = calcMaxScore(teams)
  {teams, maxScore, maxPriority: calcMaxPriority(~maxScore)}
}

let keep = ({teams, _}, ~f) => {
  let teams = Id.Map.keep(teams, (key, team) => f(key, team))
  let maxScore = calcMaxScore(teams)
  {teams, maxScore, maxPriority: calcMaxPriority(~maxScore)}
}

let calcPairIdeal = (team1, team2, ~maxScore) =>
  if Id.eq(team1.id, team2.id) {
    0.0
  } else {
    let metBefore = List.some(team1.opponents, Id.eq(team2.id, ...))
    let mustAvoid = Id.Set.has(team1.avoidIds, team2.id)
    let canMeet = !metBefore && !mustAvoid
    let scoreDiff = abs_float(team1.score -. team2.score)
    let halfPosDiff = Float.fromInt(abs(team1.halfPos - team2.halfPos))
    let isDiffHalf = team1.isUpperHalf != team2.isUpperHalf && team1.score == team2.score
    priority(~scoreDiff, ~maxScore, ~isDiffHalf, ~halfPosDiff, ~canMeet)
  }

let calcPairIdealByIds = ({teams, maxScore, _}, t1, t2) =>
  switch (Id.Map.get(teams, t1), Id.Map.get(teams, t2)) {
  | (Some(t1), Some(t2)) => Some(calcPairIdeal(t1, t2, ~maxScore))
  | _ => None
  }

let sortByScore = (data1, data2) => compare(data1.score, data2.score)

let setByeTeam = (byeQueue, teamByeId, data: t) => {
  let hasNotHadBye = p => !List.some(p.opponents, Id.eq(teamByeId, ...))
  switch mod(Id.Map.size(data.teams), 2) {
  | exception Division_by_zero => (data, None)
  | 0 => (data, None)
  | _ =>
    let dataArr =
      data.teams
      ->Id.Map.valuesToArray
      ->Array.filter(hasNotHadBye)
      ->Utils.Array.toSortedByInt(sortByScore)
    let teamIdsWithoutByes = Array.map(dataArr, p => p.id)
    let hasntHadByeFn = id => Array.some(teamIdsWithoutByes, Id.eq(id, ...))
    let nextByeSignups = Array.filter(byeQueue, hasntHadByeFn)
    let dataForNextBye = switch nextByeSignups[0] {
    | Some(id) =>
      switch Id.Map.get(data.teams, id) {
      | Some(_) as x => x
      | None => dataArr[0]
      }
    | None =>
      switch dataArr[0] {
      | Some(_) as x => x
      | None =>
        data.teams->Id.Map.valuesToArray->Utils.Array.toSortedByInt(sortByScore)->Array.get(0)
      }
    }
    let teams = switch dataForNextBye {
    | Some(dataForNextBye) => Id.Map.remove(data.teams, dataForNextBye.id)
    | None => data.teams
    }
    ({...data, teams}, dataForNextBye)
  }
}

let netScore = ((team1, team2)) => team1.score +. team2.score

let sortByNetScore = (pair1, pair2) => compare(netScore(pair2), netScore(pair1))

module IdMatch = unpack(Blossom.Match.comparable(Id.compare))

let pairTeams = ({teams, maxScore, _}) => {
  Id.Map.reduce(teams, list{}, (acc, t1Id, t1) =>
    Id.Map.reduce(teams, acc, (acc2, t2Id, t2) => list{
      (t1Id, t2Id, calcPairIdeal(t1, t2, ~maxScore)),
      ...acc2,
    })
  )
  ->Blossom.Match.make(~id=module(IdMatch))
  ->Blossom.Match.reduce(~init=Data_Id.Pair.Set.make(), ~f=(acc, p1, p2) =>
    switch Data_Id.Pair.make(p1, p2) {
    | None => acc
    | Some(pair) => Belt.Set.add(acc, pair)
    }
  )
  ->Data_Id.Pair.Set.toArray
  ->Array.filterMap(pair => {
    let (t1, t2) = Data_Id.Pair.toTuple(pair)
    switch (Id.Map.get(teams, t1), Id.Map.get(teams, t2)) {
    | (Some(t1), Some(t2)) => Some((t1, t2))
    | _ => None
    }
  })
  ->Utils.Array.toSortedByInt(sortByNetScore)
  ->Array.map(((t1, t2)) => (t1.id, t2.id))
}
