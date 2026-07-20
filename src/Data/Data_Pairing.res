/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  队伍配对引擎（瑞士移位制）。
  去掉颜色平衡，维度: 避免已对阵 > 场分相近 > 上下半区交叉
*/
open! Belt
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
    Array.size(arr) / 2
  } catch {
  | Division_by_zero => 0
  }
  (Array.slice(arr, ~offset=0, ~len=midpoint), Array.sliceToEnd(arr, midpoint))
}

/*
 确定每支队伍所属半区及半区内排名位置。
 */
let setUpperHalves = data => {
  let dataArr = Map.valuesToArray(data)
  Map.map(data, teamData => {
    let (upperHalfIds, lowerHalfIds) =
      dataArr
      ->Array.keep(({score, _}) => score == teamData.score)
      ->Belt.SortArray.stableSortBy(descendingScore)
      ->splitInHalf
    let getIndex = Array.getIndexBy(_, x => Id.eq(x.id, teamData.id))
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

let calcMaxScore = m => Map.reduce(m, 0., (acc, _, p) => max(acc, p.score))

let make = (scoreData, teamData, avoidPairs) => {
  let avoidMap = Data_Id.Pair.Set.toMap(avoidPairs)
  let teams = Map.mapWithKey(teamData, (key, data: Data_Team.t) => {
    let teamStats = switch Map.get(scoreData, key) {
    | None => Data_Scoring.make(key)
    | Some(x) => x
    }
    let newAvoidIds = switch Map.get(avoidMap, key) {
    | None => Set.make(~id=Data_Id.id)
    | Some(x) => x
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
  let teams = Map.keep(teams, (key, team) => f(key, team))
  let maxScore = calcMaxScore(teams)
  {teams, maxScore, maxPriority: calcMaxPriority(~maxScore)}
}

let calcPairIdeal = (team1, team2, ~maxScore) =>
  if Id.eq(team1.id, team2.id) {
    0.0
  } else {
    let metBefore = List.some(team1.opponents, Id.eq(team2.id, ...))
    let mustAvoid = Set.has(team1.avoidIds, team2.id)
    let canMeet = !metBefore && !mustAvoid
    let scoreDiff = abs_float(team1.score -. team2.score)
    let halfPosDiff = Float.fromInt(abs(team1.halfPos - team2.halfPos))
    let isDiffHalf = team1.isUpperHalf != team2.isUpperHalf && team1.score == team2.score
    priority(~scoreDiff, ~maxScore, ~isDiffHalf, ~halfPosDiff, ~canMeet)
  }

let calcPairIdealByIds = ({teams, maxScore, _}, t1, t2) =>
  switch (Map.get(teams, t1), Map.get(teams, t2)) {
  | (Some(t1), Some(t2)) => Some(calcPairIdeal(t1, t2, ~maxScore))
  | _ => None
  }

let sortByScore = (data1, data2) => compare(data1.score, data2.score)

let setByeTeam = (byeQueue, teamByeId, data: t) => {
  let hasNotHadBye = p => !List.some(p.opponents, Id.eq(teamByeId, ...))
  switch mod(Map.size(data.teams), 2) {
  | exception Division_by_zero => (data, None)
  | 0 => (data, None)
  | _ =>
    let dataArr =
      data.teams
      ->Map.valuesToArray
      ->Array.keep(hasNotHadBye)
      ->SortArray.stableSortBy(sortByScore)
    let teamIdsWithoutByes = Array.map(dataArr, p => p.id)
    let hasntHadByeFn = id => Array.some(teamIdsWithoutByes, Id.eq(id, ...))
    let nextByeSignups = Array.keep(byeQueue, hasntHadByeFn)
    let dataForNextBye = switch nextByeSignups[0] {
    | Some(id) =>
      switch Map.get(data.teams, id) {
      | Some(_) as x => x
      | None => dataArr[0]
      }
    | None =>
      switch dataArr[0] {
      | Some(_) as x => x
      | None =>
        data.teams->Map.valuesToArray->SortArray.stableSortBy(sortByScore)->Array.get(0)
      }
    }
    let teams = switch dataForNextBye {
    | Some(dataForNextBye) => Map.remove(data.teams, dataForNextBye.id)
    | None => data.teams
    }
    ({...data, teams}, dataForNextBye)
  }
}

let netScore = ((team1, team2)) => team1.score +. team2.score

let sortByNetScore = (pair1, pair2) => compare(netScore(pair2), netScore(pair1))

module IdMatch = unpack(Blossom.Match.comparable(Id.compare))

let pairTeams = ({teams, maxScore, _}) => {
  Map.reduce(teams, list{}, (acc, t1Id, t1) =>
    Map.reduce(teams, acc, (acc2, t2Id, t2) => list{
      (t1Id, t2Id, calcPairIdeal(t1, t2, ~maxScore)),
      ...acc2,
    })
  )
  ->Blossom.Match.make(~id=module(IdMatch))
  ->Blossom.Match.reduce(~init=Set.make(~id=Data_Id.Pair.id), ~f=(acc, p1, p2) =>
    switch Data_Id.Pair.make(p1, p2) {
    | None => acc
    | Some(pair) => Set.add(acc, pair)
    }
  )
  ->Set.toArray
  ->Array.keepMap(pair => {
    let (t1, t2) = Data_Id.Pair.toTuple(pair)
    switch (Map.get(teams, t1), Map.get(teams, t2)) {
    | (Some(t1), Some(t2)) => Some((t1, t2))
    | _ => None
    }
  })
  ->SortArray.stableSortBy(sortByNetScore)
  ->Array.map(((t1, t2)) => (t1.id, t2.id))
}
