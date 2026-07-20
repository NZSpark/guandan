/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/

open! Belt
module Match = Data_Match
module Id = Data_Id

module Round = {
  type t = array<Match.t>

  let fromArray = x => x

  let toArray = x => x

  let empty: t = []

  let encode = t => t->Array.map(Match.encode)->Js.Json.array

  @raises(Not_found)
  let decode = json => Js.Json.decodeArray(json)->Option.getExn->Array.map(Match.decode)

  let size = arr => Array.length(arr)

  let addMatches = (arr1, arr2) => Array.concat(arr1, arr2)

  /* flatten all of the ids from the matches to one array. */
  let getMatched = (round: t) => {
    let q = MutableQueue.make()
    Array.forEach(round, ({team1Id, team2Id, _}) => {
      MutableQueue.add(q, team1Id)
      MutableQueue.add(q, team2Id)
    })
    MutableQueue.toArray(q)
  }

  let getMatchById = (round: t, id) => Array.getBy(round, x => Id.eq(x.id, id))

  let removeMatchById = (round: t, id) => Array.keep(round, x => !Id.eq(x.id, id))

  let setMatch = (round: t, match: Data_Match.t) => {
    let round = Array.copy(round)
    round
    ->Array.getIndexBy(({Match.id: id, _}) => Id.eq(id, match.id))
    ->Option.map(x => round[x] = match)
    ->Option.flatMap(wasSuccessful => wasSuccessful ? Some(round) : None)
  }

  let moveMatch = (round, matchId, direction) =>
    switch getMatchById(round, matchId) {
    | None => None
    | Some(match_) =>
      let oldIndex = Js.Array2.indexOf(round, match_)
      let newIndex = oldIndex + direction >= 0 ? oldIndex + direction : 0
      Some(Utils.Array.swap(round, oldIndex, newIndex))
    }
}

type t = array<Round.t>

let fromArray = x => x

let toArray = x => x

let empty: t = []

let encode = t => t->Array.map(Round.encode)->Js.Json.array

@raises(Not_found)
let decode = json => Js.Json.decodeArray(json)->Option.getExn->Array.map(Round.decode)

let size = arr => Js.Array2.length(arr)

let getLastKey = rounds => Array.length(rounds) - 1

let get = (arr, i) => arr[i]

let set = (rounds, key, round) => {
  let rounds = Array.copy(rounds)
  let wasSuccessful = rounds[key] = round
  wasSuccessful ? Some(rounds) : None
}

let setMatch = (rounds, key, match_) =>
  rounds->get(key)->Option.flatMap(Round.setMatch(_, match_))->Option.flatMap(set(rounds, key, ...))

let rounds2Matches = roundList => {
  module Q = MutableQueue
  let q = Q.make()
  Array.forEach(roundList, r => r->Q.fromArray->Q.transfer(q))
  q
}

let isRoundComplete = (roundList, teams, roundId) =>
  switch roundList[roundId] {
  | Some(round) =>
    if roundId < Array.size(roundList) - 1 {
      true
    } else {
      let matched = Round.getMatched(round)
      let unmatched = Map.removeMany(teams, matched)
      let results = Array.map(round, match => match.result.winner)
      Map.size(unmatched) == 0 && !Js.Array2.includes(results, None)
    }
  | None => true
  }

let addRound = roundList => Array.concat(roundList, [[]])

let delLastRound = roundList => Js.Array.slice(roundList, ~start=0, ~end_=-1)
