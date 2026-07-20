/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/
open Vitest
open Data
open! Belt
module Id = Data_Id

/* ═══════════════════════════════════════════════════════════
   Data_Level 单元测试
   ═══════════════════════════════════════════════════════════ */

describe("Level.toInt / fromInt", () => {
  test("toInt maps correctly", t => {
    t->expect(Level.toInt(Level.Two))->Expect.toBe(2)
    t->expect(Level.toInt(Level.Ten))->Expect.toBe(10)
    t->expect(Level.toInt(Level.Jack))->Expect.toBe(11)
    t->expect(Level.toInt(Level.Queen))->Expect.toBe(12)
    t->expect(Level.toInt(Level.King))->Expect.toBe(13)
    t->expect(Level.toInt(Level.Ace))->Expect.toBe(14)
  })

  test("fromInt toInt roundtrip", t => {
    for i in 2 to 14 {
      t->expect(Level.toInt(Level.fromInt(i)))->Expect.toBe(i)
    }
  })
})

describe("Level.netSmallScore", () => {
  test("positive when my team higher level", t => {
    /* King(13) vs Eight(8) → +5 */
    t->expect(Level.netSmallScore(Level.King, Level.Eight))->Expect.toBe(5)
  })

  test("negative when my team lower level", t => {
    /* Eight(8) vs King(13) → -5 */
    t->expect(Level.netSmallScore(Level.Eight, Level.King))->Expect.toBe(-5)
  })

  test("zero when same level", t => {
    t->expect(Level.netSmallScore(Level.Ten, Level.Ten))->Expect.toBe(0)
  })

  test("Ace vs basic level difference", t => {
    /* Ace(14) vs Nine(9) → +5 */
    t->expect(Level.netSmallScore(Level.Ace, Level.Nine))->Expect.toBe(5)
  })
})

describe("Level.cumulativeSmallScore", () => {
  test("returns 0 for level 2 (starting level)", t => {
    t->expect(Level.cumulativeSmallScore(Level.Two))->Expect.toBe(0)
  })

  test("returns 8 for level 10 (10-2)", t => {
    t->expect(Level.cumulativeSmallScore(Level.Ten))->Expect.toBe(8)
  })

  test("returns 11 for level K (13-2)", t => {
    t->expect(Level.cumulativeSmallScore(Level.King))->Expect.toBe(11)
  })

  test("returns 13 for Ace (14-2+1 bonus)", t => {
    t->expect(Level.cumulativeSmallScore(Level.Ace))->Expect.toBe(13)
  })
})

/* ═══════════════════════════════════════════════════════════
   Data_Scoring 单元测试
   ═══════════════════════════════════════════════════════════ */

test("FieldScore constants match 掼蛋规则", t => {
  /* 掼蛋场分：胜3/平2/负1/缺席0/轮空3 */
  t->expect(Scoring.FieldScore.win)->Expect.toBe(3.0)
  t->expect(Scoring.FieldScore.draw)->Expect.toBe(2.0)
  t->expect(Scoring.FieldScore.lose)->Expect.toBe(1.0)
  t->expect(Scoring.FieldScore.absent)->Expect.toBe(0.0)
  t->expect(Scoring.FieldScore.bye)->Expect.toBe(3.0)
})

test("Scoring.make initializes empty scoring record", t => {
  let s = Scoring.make(TestData.tNanshan.id)
  t->expect(s.teamId)->Expect.toBe(TestData.tNanshan.id)
  t->expect(s.id)->Expect.toBe(TestData.tNanshan.id)
  t->expect(s.totalFieldScore)->Expect.toBe(0.0)
  t->expect(s.totalNetSmallScore)->Expect.toBe(0)
  t->expect(s.totalCumulativeSmallScore)->Expect.toBe(0)
  t->expect(s.byeCount)->Expect.toBe(0)
})

describe("Scoring.update accumulates match results", () => {
  test("creates new entry when given None", t => {
    let result = Scoring.update(
      None,
      ~teamId=TestData.tNanshan.id,
      ~fieldScore=3.0,
      ~netSmall=5,
      ~cumSmall=11,
      ~oppId=TestData.tLeiting.id,
      ~resultStr="W",
    )
    switch result {
    | None => assert(false)
    | Some(s) =>
      t->expect(s.totalFieldScore)->Expect.toBe(3.0)
      t->expect(s.totalNetSmallScore)->Expect.toBe(5)
      t->expect(s.totalCumulativeSmallScore)->Expect.toBe(11)
      t->expect(s.byeCount)->Expect.toBe(0)
      t->expect(List.length(s.results))->Expect.toBe(1)
    }
  })

  test("accumulates second match on existing entry", t => {
    let afterWin = Scoring.update(
      None,
      ~teamId=TestData.tNanshan.id,
      ~fieldScore=3.0,
      ~netSmall=5,
      ~cumSmall=11,
      ~oppId=TestData.tLeiting.id,
      ~resultStr="W",
    )
    let afterDraw = Scoring.update(
      afterWin,
      ~teamId=TestData.tNanshan.id,
      ~fieldScore=2.0,
      ~netSmall=0,
      ~cumSmall=8,
      ~oppId=TestData.tZhongqu.id,
      ~resultStr="D",
    )
    switch afterDraw {
    | None => assert(false)
    | Some(s) =>
      t->expect(s.totalFieldScore)->Expect.toBe(5.0)
      t->expect(s.totalNetSmallScore)->Expect.toBe(5)
      t->expect(s.totalCumulativeSmallScore)->Expect.toBe(19)
      t->expect(List.length(s.results))->Expect.toBe(2)
    }
  })

  test("counts bye when opponent is bye team", t => {
    let result = Scoring.update(
      None,
      ~teamId=TestData.tNanshan.id,
      ~fieldScore=3.0,
      ~netSmall=0,
      ~cumSmall=0,
      ~oppId=Id.teamBye,
      ~resultStr="W",
    )
    switch result {
    | None => assert(false)
    | Some(s) => t->expect(s.byeCount)->Expect.toBe(1)
    }
  })
})

/* ═══════════════════════════════════════════════════════════
   fromTournament 积分计算测试
   ═══════════════════════════════════════════════════════════ */

let scores: Id.Map.t<Scoring.t> =
  Scoring.fromTournament(
    ~roundList=TestData.testTournament.roundList,
    ~scoreAdjustments=Map.make(~id=Id.id),
  )

describe("Scoring.fromTournament computes correct per-team scores", () => {
  test("南山闪电: W vs 雷霆, field=3.0, net=+5, cum=11", t => {
    switch Map.get(scores, TestData.tNanshan.id) {
    | None => assert(false)
    | Some(s) =>
      t->expect(s.totalFieldScore)->Expect.toBe(3.0)
      t->expect(s.totalNetSmallScore)->Expect.toBe(5)
      t->expect(s.totalCumulativeSmallScore)->Expect.toBe(11)
    }
  })

  test("雷霆战队: L vs 南山, field=1.0, net=-5, cum=6", t => {
    switch Map.get(scores, TestData.tLeiting.id) {
    | None => assert(false)
    | Some(s) =>
      t->expect(s.totalFieldScore)->Expect.toBe(1.0)
      t->expect(s.totalNetSmallScore)->Expect.toBe(-5)
      t->expect(s.totalCumulativeSmallScore)->Expect.toBe(6)
    }
  })

  test("东区虎啸: L vs 风云, field=1.0, net=-1, cum=9", t => {
    switch Map.get(scores, TestData.tDongqu.id) {
    | None => assert(false)
    | Some(s) =>
      t->expect(s.totalFieldScore)->Expect.toBe(1.0)
      t->expect(s.totalNetSmallScore)->Expect.toBe(-1)
      t->expect(s.totalCumulativeSmallScore)->Expect.toBe(9)
    }
  })

  test("风云双雄: W vs 东区, field=3.0, net=+1, cum=10", t => {
    switch Map.get(scores, TestData.tFengyun.id) {
    | None => assert(false)
    | Some(s) =>
      t->expect(s.totalFieldScore)->Expect.toBe(3.0)
      t->expect(s.totalNetSmallScore)->Expect.toBe(1)
      t->expect(s.totalCumulativeSmallScore)->Expect.toBe(10)
    }
  })

  test("中区飞鹰: draw, field=2.0, net=0, cum=8", t => {
    switch Map.get(scores, TestData.tZhongqu.id) {
    | None => assert(false)
    | Some(s) =>
      t->expect(s.totalFieldScore)->Expect.toBe(2.0)
      t->expect(s.totalNetSmallScore)->Expect.toBe(0)
      t->expect(s.totalCumulativeSmallScore)->Expect.toBe(8)
    }
  })

  test("群英荟萃: W vs 钻石, field=3.0, net=+5(Ace 14-N9=5), cum=13(14-2+1)", t => {
    switch Map.get(scores, TestData.tQunying.id) {
    | None => assert(false)
    | Some(s) =>
      t->expect(s.totalFieldScore)->Expect.toBe(3.0)
      t->expect(s.totalNetSmallScore)->Expect.toBe(5)
      t->expect(s.totalCumulativeSmallScore)->Expect.toBe(13)
    }
  })

  test("钻石风暴: L vs 群英, field=1.0, net=-5, cum=7", t => {
    switch Map.get(scores, TestData.tZuanshi.id) {
    | None => assert(false)
    | Some(s) =>
      t->expect(s.totalFieldScore)->Expect.toBe(1.0)
      t->expect(s.totalNetSmallScore)->Expect.toBe(-5)
      t->expect(s.totalCumulativeSmallScore)->Expect.toBe(7)
    }
  })
})

/* ═══════════════════════════════════════════════════════════
   createStandingArray 排名测试
   ═══════════════════════════════════════════════════════════ */

test("Scoring.createStandingArray ranks by fieldScore desc, then tiebreaks", t => {
  let standings: array<Scoring.teamScores> = scores->Scoring.createStandingArray(Map.make(~id=Id.id))
  /* 8 teams, sorted */
  t->expect(Array.length(standings))->Expect.toBe(8)

  /* Helper: extract teamScore by index with explicit type */
  let get = (i): Scoring.teamScores => standings[i]->Option.getExn

  /* Top 3: all 3.0, ordered by cumulativeSmallScore: 群英(13) > 南山(11) > 风云(10) */
  t->expect(get(0).id)->Expect.toBe(TestData.tQunying.id)
  t->expect(get(1).id)->Expect.toBe(TestData.tNanshan.id)
  t->expect(get(2).id)->Expect.toBe(TestData.tFengyun.id)

  /* Middle 2: both 2.0, ordered by cumulative: 中区(8) = 北岸(8), then net: 中区(0) = 北岸(0) */
  t->expect(get(3).fieldScore)->Expect.toBe(2.0)
  t->expect(get(4).fieldScore)->Expect.toBe(2.0)

  /* Bottom 3: all 1.0, ordered by cumulative: 东区(9) > 钻石(7) > 雷霆(6) */
  t->expect(get(5).id)->Expect.toBe(TestData.tDongqu.id)
  t->expect(get(6).id)->Expect.toBe(TestData.tZuanshi.id)
  t->expect(get(7).id)->Expect.toBe(TestData.tLeiting.id)
})

/* ═══════════════════════════════════════════════════════════
   createStandingTree 分级测试
   ═══════════════════════════════════════════════════════════ */

test("Scoring.createStandingTree groups teams with equal scores", t => {
  let standingsArr = scores->Scoring.createStandingArray(Map.make(~id=Id.id))
  let tree = Scoring.createStandingTree(standingsArr, ~tieBreaks=Scoring.defaultTieBreaks)

  /* Tree should have separate groups for different score levels */
  /* 3.0 group: 3 teams */
  /* 2.0 group: 2 teams (same cum+net, drawn each other → same group) */
  /* 1.0 group: 3 teams (different cum, separate groups) */

  switch tree {
  | list{first, second, third, fourth, fifth, sixth, ..._} =>
    /* 3.0 teams all separate (different cum scores) */
    t->expect(List.length(first))->Expect.toBe(1)
    t->expect(List.length(second))->Expect.toBe(1)
    t->expect(List.length(third))->Expect.toBe(1)

    /* 2.0 teams: same field+net+cum → same group */
    t->expect(List.length(fourth))->Expect.toBe(2)

    /* 1.0 teams: different cum → separate groups */
    t->expect(List.length(fifth))->Expect.toBe(1)
    t->expect(List.length(sixth))->Expect.toBe(1)

  | _ => assert(false)
  }
})

/* ═══════════════════════════════════════════════════════════
   TieBreak 测试
   ═══════════════════════════════════════════════════════════ */

test("TieBreak.toString returns correct strings", t => {
  t->expect(Scoring.TieBreak.toString(Scoring.TieBreak.TotalFieldScore))->Expect.toBe("totalFieldScore")
  t->expect(Scoring.TieBreak.toString(Scoring.TieBreak.DirectEncounter))->Expect.toBe("directEncounter")
  t->expect(Scoring.TieBreak.toString(Scoring.TieBreak.NetSmallScore))->Expect.toBe("netSmallScore")
  t->expect(Scoring.TieBreak.toString(Scoring.TieBreak.CumulativeSmallScore))->Expect.toBe("cumulativeSmallScore")
})

test("TieBreak.encode/decode roundtrip", t => {
  let breaks = [Scoring.TieBreak.TotalFieldScore, Scoring.TieBreak.DirectEncounter, Scoring.TieBreak.NetSmallScore, Scoring.TieBreak.CumulativeSmallScore]
  Array.forEach(breaks, b => {
    t->expect(b->Scoring.TieBreak.encode->Scoring.TieBreak.decode)->Expect.toBe(b)
  })
})

test("defaultTieBreaks has correct priority order", t => {
  let breaks = Scoring.defaultTieBreaks
  t->expect(breaks[0]->Option.getExn)->Expect.toBe(Scoring.TieBreak.TotalFieldScore)
  t->expect(breaks[1]->Option.getExn)->Expect.toBe(Scoring.TieBreak.DirectEncounter)
  t->expect(breaks[2]->Option.getExn)->Expect.toBe(Scoring.TieBreak.NetSmallScore)
  t->expect(breaks[3]->Option.getExn)->Expect.toBe(Scoring.TieBreak.CumulativeSmallScore)
})

/* ═══════════════════════════════════════════════════════════
   oppResultsToSumById 测试
   ═══════════════════════════════════════════════════════════ */

test("oppResultsToSumById returns sum of field scores vs opponent", t => {
  let s = Scoring.make(TestData.tNanshan.id)
  /* Add two results vs same opponent */
  let after = Scoring.update(
    Some(s),
    ~teamId=TestData.tNanshan.id,
    ~fieldScore=3.0,
    ~netSmall=5,
    ~cumSmall=11,
    ~oppId=TestData.tLeiting.id,
    ~resultStr="W",
  )
  switch after {
  | None => assert(false)
  | Some(sc) =>
    /* One W vs 雷霆 = 3.0 */
    let sum = Scoring.oppResultsToSumById(sc, TestData.tLeiting.id)
    t->expect(sum)->Expect.toBe(Some(3.0))
  }
})
