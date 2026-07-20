/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/
open Vitest
open Data

/* ═══════════════════════════════════════════════════════════
   Data_Match.Result 单元测试
   ═══════════════════════════════════════════════════════════ */

test("Result.makeNotSet creates unset result with level Two", t => {
  let r = Match.Result.makeNotSet()
  t->expect(r.team1Level)->Expect.toBe(Level.Two)
  t->expect(r.team2Level)->Expect.toBe(Level.Two)
  t->expect(r.winner)->Expect.toBe(None)
})

describe("Result.fieldScoreForTeam", () => {
  let team1Won = {
    Match.Result.team1Level: Level.King,
    team2Level: Level.Eight,
    winner: Some(Match.Result.Team1Won),
  }

  test("team1 gets 3.0 when Team1Won", t => {
    t->expect(Match.Result.fieldScoreForTeam(team1Won, true))->Expect.toBe(3.0)
  })

  test("team2 gets 1.0 when Team1Won", t => {
    t->expect(Match.Result.fieldScoreForTeam(team1Won, false))->Expect.toBe(1.0)
  })

  let team2Won = {
    Match.Result.team1Level: Level.Jack,
    team2Level: Level.Queen,
    winner: Some(Match.Result.Team2Won),
  }

  test("team1 gets 1.0 when Team2Won", t => {
    t->expect(Match.Result.fieldScoreForTeam(team2Won, true))->Expect.toBe(1.0)
  })

  test("team2 gets 3.0 when Team2Won", t => {
    t->expect(Match.Result.fieldScoreForTeam(team2Won, false))->Expect.toBe(3.0)
  })

  let draw = {
    Match.Result.team1Level: Level.Ten,
    team2Level: Level.Ten,
    winner: None,
  }

  test("both teams get 2.0 on draw", t => {
    t->expect(Match.Result.fieldScoreForTeam(draw, true))->Expect.toBe(2.0)
    t->expect(Match.Result.fieldScoreForTeam(draw, false))->Expect.toBe(2.0)
  })
})

describe("Result.resultForTeam", () => {
  test("returns 'W' for winner, 'L' for loser", t => {
    let r = {Match.Result.team1Level: Level.King, team2Level: Level.Eight, winner: Some(Match.Result.Team1Won)}
    t->expect(Match.Result.resultForTeam(r, true))->Expect.toBe("W")
    t->expect(Match.Result.resultForTeam(r, false))->Expect.toBe("L")
  })

  test("returns 'D' for both on draw", t => {
    let r = {Match.Result.team1Level: Level.Ten, team2Level: Level.Ten, winner: None}
    t->expect(Match.Result.resultForTeam(r, true))->Expect.toBe("D")
    t->expect(Match.Result.resultForTeam(r, false))->Expect.toBe("D")
  })
})

test("Result encode/decode roundtrip preserves data", t => {
  let r = {Match.Result.team1Level: Level.Ace, team2Level: Level.Nine, winner: Some(Match.Result.Team1Won)}
  let decoded = r->Match.Result.encode->Match.Result.decode
  t->expect(decoded.team1Level)->Expect.toBe(Level.Ace)
  t->expect(decoded.team2Level)->Expect.toBe(Level.Nine)
  switch decoded.winner {
  | Some(Match.Result.Team1Won) => () /* pass */
  | Some(Match.Result.Team2Won) => assert(false)
  | None => assert(false)
  }
})

test("Result.toString returns correct strings", t => {
  let r1 = {Match.Result.team1Level: Level.Two, team2Level: Level.Two, winner: Some(Match.Result.Team1Won)}
  let r2 = {Match.Result.team1Level: Level.Two, team2Level: Level.Two, winner: Some(Match.Result.Team2Won)}
  let r0 = {Match.Result.team1Level: Level.Two, team2Level: Level.Two, winner: None}
  t->expect(Match.Result.toString(r1))->Expect.toBe("team1won")
  t->expect(Match.Result.toString(r2))->Expect.toBe("team2won")
  t->expect(Match.Result.toString(r0))->Expect.toBe("notSet")
})

/* ═══════════════════════════════════════════════════════════
   Data_Match 测试
   ═══════════════════════════════════════════════════════════ */

test("manualPair creates match with unset result", t => {
  let team1 = TestData.tNanshan
  let team2 = TestData.tLeiting
  let m = Match.manualPair(~team1, ~team2)
  t->expect(m.team1Id)->Expect.toBe(team1.id)
  t->expect(m.team2Id)->Expect.toBe(team2.id)
  t->expect(m.result.winner)->Expect.toBe(None)
  t->expect(m.tableNumber)->Expect.toBe(None)
})

test("isBye returns true only when team is bye", t => {
  let normalMatch = Match.manualPair(~team1=TestData.tNanshan, ~team2=TestData.tLeiting)
  t->expect(Match.isBye(normalMatch))->Expect.toBe(false)

  let byeMatch = Match.manualPair(~team1=TestData.tNanshan, ~team2=Team.bye)
  t->expect(Match.isBye(byeMatch))->Expect.toBe(true)
})

test("getOpponentId returns correct opponent", t => {
  let m = Match.manualPair(~team1=TestData.tNanshan, ~team2=TestData.tFengyun)
  t->expect(Match.getOpponentId(m, TestData.tNanshan.id))->Expect.toBe(TestData.tFengyun.id)
  t->expect(Match.getOpponentId(m, TestData.tFengyun.id))->Expect.toBe(TestData.tNanshan.id)
})

test("Match encode/decode roundtrip", t => {
  let m = {
    Match.id: Data_Id.fromString("M_R1_Test___________"),
    team1Id: TestData.tNanshan.id,
    team2Id: TestData.tLeiting.id,
    result: {Match.Result.team1Level: Level.King, team2Level: Level.Eight, winner: Some(Match.Result.Team1Won)},
    tableNumber: Some(1),
  }
  let decoded = m->Match.encode->Match.decode
  t->expect(decoded.team1Id)->Expect.toBe(TestData.tNanshan.id)
  t->expect(decoded.team2Id)->Expect.toBe(TestData.tLeiting.id)
  t->expect(decoded.result.team1Level)->Expect.toBe(Level.King)
  t->expect(decoded.tableNumber)->Expect.toBe(Some(1))
})
