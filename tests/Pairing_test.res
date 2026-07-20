/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/
open! Belt
open Vitest
open Data
module Id = Data_Id

/* Helper: build Pairing.t from tournament data */
let loadPairData = tourney => {
  let {Tournament.teamIds, roundList, _} = tourney
  let teamData = Map.reduce(TestData.teams, Map.make(~id=Id.id), (acc, key, team) =>
    if Set.has(teamIds, key) {
      Map.set(acc, key, team)
    } else {
      acc
    }
  )
  let scoreData = Scoring.fromTournament(~roundList, ~scoreAdjustments=Map.make(~id=Id.id))
  Pairing.make(scoreData, teamData, Config.default.avoidTeamPairs)
}

/* ═══════════════════════════════════════════════════════════
   Pairing 构造测试
   ═══════════════════════════════════════════════════════════ */

test("Pairing.make creates data for all 8 teams", t => {
  let data = loadPairData(TestData.testTournament)
  t->expect(Map.size(Pairing.teams(data)))->Expect.toBe(8)
})

/* ═══════════════════════════════════════════════════════════
   Priority 测试
   ═══════════════════════════════════════════════════════════ */

test("Self-pairing has 0 priority", t => {
  let data = loadPairData(TestData.testTournament)
  let teamId = TestData.tNanshan.id
  t->expect(Pairing.calcPairIdealByIds(data, teamId, teamId))->Expect.toBe(Some(0.0))
})

test("Teams that already played have lower priority", t => {
  let data = loadPairData(TestData.testTournament)
  /* 南山闪电(已对阵雷霆战队) vs 东区虎啸(未对阵) */
  let priRepeated = Pairing.calcPairIdealByIds(data, TestData.tNanshan.id, TestData.tLeiting.id)
  let priNew = Pairing.calcPairIdealByIds(data, TestData.tNanshan.id, TestData.tDongqu.id)

  switch (priRepeated, priNew) {
  | (Some(pr), Some(pn)) =>
    /* Already-matched pair should have lower or equal priority */
    t->expect(pr <= pn)->Expect.toBe(true)
  | _ => assert(false)
  }
})

test("calcPairIdealByIds for non-existent team returns None", t => {
  let data = loadPairData(TestData.testTournament)
  let result = Pairing.calcPairIdealByIds(data, TestData.tNanshan.id, Id.fromString("NONEXISTENT__________"))
  t->expect(result)->Expect.toBe(None)
})

/* ═══════════════════════════════════════════════════════════
   setByeTeam 测试
   ═══════════════════════════════════════════════════════════ */

test("setByeTeam returns no bye for even number of teams", t => {
  let data = loadPairData(TestData.testTournament)
  t->expect(Map.size(Pairing.teams(data)))->Expect.toBe(8)
  let (_newData, bye) = Pairing.setByeTeam([], Id.teamBye, data)
  t->expect(bye)->Expect.toBe(None)
})

/* ═══════════════════════════════════════════════════════════
   pairTeams 测试
   ═══════════════════════════════════════════════════════════ */

test("pairTeams produces 4 matches for 8 teams", t => {
  let data = loadPairData(TestData.testTournament)
  let matches = Pairing.pairTeams(data)
  t->expect(Array.length(matches))->Expect.toBe(4)
})

test("pairTeams returns valid team ID pairs", t => {
  let data = loadPairData(TestData.testTournament)
  let matches = Pairing.pairTeams(data)
  /* All matches should be pairs of different team IDs */
  Array.forEach(matches, ((t1Id, t2Id)) => {
    t->expect(Id.eq(t1Id, t2Id))->Expect.toBe(false)
  })
})

test("pairTeams covers each team exactly once", t => {
  let data = loadPairData(TestData.testTournament)
  let matches = Pairing.pairTeams(data)

  let seen: MutableSet.t<Id.t, Id.identity> = MutableSet.make(~id=Id.id)
  Array.forEach(matches, ((t1Id, t2Id)) => {
    MutableSet.add(seen, t1Id) |> ignore
    MutableSet.add(seen, t2Id) |> ignore
  })
  /* 8 teams should all appear once */
  t->expect(MutableSet.size(seen))->Expect.toBe(8)
})
