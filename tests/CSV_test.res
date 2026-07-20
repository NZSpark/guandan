/*
  Copyright (c) 2022 John Jackson.
  CSV import tests for 掼蛋 tournament management.
*/
open! Belt
open Vitest

/* Helper: a minimal CSV snippet matching the attendance.csv format */
let sampleCSV = "队伍名称,队员1,性别1,队员2,性别2,所属俱乐部/社团,当前积分\n南山闪电,张伟,男,李明,男,南山掼蛋俱乐部,0\n雷霆战队,王芳,女,赵丽,女,奥克兰掼协,0\n碧海蓝天,高雪,女,罗丽,女,,0\n"

test("Data_CSV.parse skips header row", t => {
  let rows = Data_CSV.parse(sampleCSV)
  t->expect(Array.length(rows))->Expect.toBe(3)
})

let getRow = (rows: array<Data_CSV.row>, i: int): Data_CSV.row => rows[i]->Option.getExn

test("Data_CSV.parse extracts team name", t => {
  let rows = Data_CSV.parse(sampleCSV)
  let r = getRow(rows, 0)
  t->expect(r.teamName)->Expect.toBe("南山闪电")
})

test("Data_CSV.parse extracts player names", t => {
  let rows = Data_CSV.parse(sampleCSV)
  let r = getRow(rows, 0)
  t->expect(r.player1Name)->Expect.toBe("张伟")
  t->expect(r.player2Name)->Expect.toBe("李明")
})

test("Data_CSV.parse extracts genders", t => {
  let rows = Data_CSV.parse(sampleCSV)
  let r = getRow(rows, 0)
  t->expect(r.player1Gender)->Expect.toBe("男")
  t->expect(r.player2Gender)->Expect.toBe("男")
})

test("Data_CSV.parse handles empty club field", t => {
  let rows = Data_CSV.parse(sampleCSV)
  let r = getRow(rows, 2)
  t->expect(r.club)->Expect.toBe("")
  t->expect(r.teamName)->Expect.toBe("碧海蓝天")
})

test("Data_CSV.importData creates players and teams", t => {
  let (players, teams) = Data_CSV.importData(sampleCSV)
  t->expect(Map.size(players))->Expect.toBe(6)
  t->expect(Map.size(teams))->Expect.toBe(3)
})

test("Data_CSV.importData stores full name in firstName", t => {
  let csv = "队伍名称,队员1,性别,队员2,性别,所属俱乐部/社团,当前积分\n测试,张伟,男,李明,男,,0\n"
  let (players, _teams) = Data_CSV.importData(csv)
  let names: array<string> = Map.valuesToArray(players)
    ->Array.map(p => p.firstName)
    ->SortArray.stableSortBy((a, b) => compare(a, b))
  /* Map iteration order is nondeterministic, check sorted names */
  t->expect(names[0]->Option.getExn)->Expect.toBe("张伟")
  t->expect(names[1]->Option.getExn)->Expect.toBe("李明")
})

test("Data_CSV.parse handles BOM prefix", t => {
  let withBom = "\uFEFF队伍名称,队员1,性别1,队员2,性别2,所属俱乐部/社团,当前积分\n南山闪电,张伟,男,李明,男,,0\n"
  let rows = Data_CSV.parse(withBom)
  t->expect(Array.length(rows))->Expect.toBe(1)
  t->expect(getRow(rows, 0).teamName)->Expect.toBe("南山闪电")
})

test("Data_CSV.parse ignores empty trailing line", t => {
  let withTrailing = "队伍名称,队员1,性别1,队员2,性别2,所属俱乐部/社团,当前积分\n南山闪电,张伟,男,李明,男,,0\n\n"
  let rows = Data_CSV.parse(withTrailing)
  t->expect(Array.length(rows))->Expect.toBe(1)
})

test("Data_CSV.importData assigns club to teams", t => {
  let (_players, teams) = Data_CSV.importData(sampleCSV)
  let allClubs: array<string> = Map.valuesToArray(teams)
    ->Array.map(t => t.club)
    ->SortArray.stableSortBy((a, b) => compare(a, b))
  /* Check all 3 clubs are present (order: "" < "南山掼蛋俱乐部" < "奥克兰掼协" in UTF-8) */
  t->expect(allClubs[0]->Option.getExn)->Expect.toBe("")
  t->expect(allClubs[1]->Option.getExn)->Expect.toBe("南山掼蛋俱乐部")
  t->expect(allClubs[2]->Option.getExn)->Expect.toBe("奥克兰掼协")
})
