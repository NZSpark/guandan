/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/
open! Belt
open Data
module Id = Data.Id
let id = Id.fromString

/* ═══════════════════════════════════════════════════════════
   测试选手（参照 attendence.csv 格式）
   ═══════════════════════════════════════════════════════════ */

let pZhangWei: Player.t = {id: "P_Zhang_Wei________"->id, firstName: "张伟", lastName: "", gender: "男"}
let pLiMing: Player.t = {id: "P_Li_Ming__________"->id, firstName: "李明", lastName: "", gender: "男"}
let pWangFang: Player.t = {id: "P_Wang_Fang________"->id, firstName: "王芳", lastName: "", gender: "女"}
let pZhaoLi: Player.t = {id: "P_Zhao_Li__________"->id, firstName: "赵丽", lastName: "", gender: "女"}
let pLiuQiang: Player.t = {id: "P_Liu_Qiang________"->id, firstName: "刘强", lastName: "", gender: "男"}
let pChenGang: Player.t = {id: "P_Chen_Gang________"->id, firstName: "陈刚", lastName: "", gender: "男"}
let pYangYang: Player.t = {id: "P_Yang_Yang________"->id, firstName: "杨洋", lastName: "", gender: "男"}
let pZhouJie: Player.t = {id: "P_Zhou_Jie_________"->id, firstName: "周杰", lastName: "", gender: "男"}
let pHuangMin: Player.t = {id: "P_Huang_Min________"->id, firstName: "黄敏", lastName: "", gender: "女"}
let pWuTing: Player.t = {id: "P_Wu_Ting__________"->id, firstName: "吴婷", lastName: "", gender: "女"}
let pSunLei: Player.t = {id: "P_Sun_Lei__________"->id, firstName: "孙磊", lastName: "", gender: "男"}
let pQianFeng: Player.t = {id: "P_Qian_Feng________"->id, firstName: "钱峰", lastName: "", gender: "男"}
let pYanLi: Player.t = {id: "P_Yan_Li___________"->id, firstName: "颜丽", lastName: "", gender: "女"}
let pQiaoXiu: Player.t = {id: "P_Qiao_Xiu_________"->id, firstName: "乔秀", lastName: "", gender: "女"}
let pFengJing: Player.t = {id: "P_Feng_Jing________"->id, firstName: "冯静", lastName: "", gender: "女"}
let pDongJuan: Player.t = {id: "P_Dong_Juan________"->id, firstName: "董娟", lastName: "", gender: "女"}

/* 保留 p1/p2 用于简单测试 */
let p1: Player.t = {id: "Test_Player_1______"->id, firstName: "Test", lastName: "One", gender: "男"}
let p2: Player.t = {id: "Test_Player_2______"->id, firstName: "Test", lastName: "Two", gender: "女"}

/* ═══════════════════════════════════════════════════════════
   测试队伍（8 队含 6 个俱乐部）
   ═══════════════════════════════════════════════════════════ */

let tNanshan: Team.t = {
  id: "T_NanShan_ShanDian_"->id, name: "南山闪电",
  player1Id: pZhangWei.id, player2Id: pLiMing.id,
  isBye: false, club: "南山掼蛋俱乐部", initialScore: 0.0,
}
let tLeiting: Team.t = {
  id: "T_LeiTing_ZhanDui__"->id, name: "雷霆战队",
  player1Id: pWangFang.id, player2Id: pZhaoLi.id,
  isBye: false, club: "奥克兰掼协", initialScore: 0.0,
}
let tDongqu: Team.t = {
  id: "T_DongQu_HuXiao____"->id, name: "东区虎啸",
  player1Id: pLiuQiang.id, player2Id: pChenGang.id,
  isBye: false, club: "东区华人联谊会", initialScore: 0.0,
}
let tFengyun: Team.t = {
  id: "T_FengYun_ShuangXio"->id, name: "风云双雄",
  player1Id: pYangYang.id, player2Id: pZhouJie.id,
  isBye: false, club: "风云掼蛋社", initialScore: 0.0,
}
let tZhongqu: Team.t = {
  id: "T_ZhongQu_FeiYing__"->id, name: "中区飞鹰",
  player1Id: pHuangMin.id, player2Id: pWuTing.id,
  isBye: false, club: "中区康养中心", initialScore: 0.0,
}
let tBeian: Team.t = {
  id: "T_BeiAn_LongTeng___"->id, name: "北岸龙腾",
  player1Id: pSunLei.id, player2Id: pQianFeng.id,
  isBye: false, club: "北岸华人协会", initialScore: 0.0,
}
let tQunying: Team.t = {
  id: "T_QunYing_HuiCui___"->id, name: "群英荟萃",
  player1Id: pYanLi.id, player2Id: pQiaoXiu.id,
  isBye: false, club: "", initialScore: 0.0,
}
let tZuanshi: Team.t = {
  id: "T_ZuanShi_FengBao__"->id, name: "钻石风暴",
  player1Id: pFengJing.id, player2Id: pDongJuan.id,
  isBye: false, club: "", initialScore: 0.0,
}

/* ── Player map ── */
let players: Id.Map.t<Player.t> =
  Map.fromArray(~id=Id.id, [
    (pZhangWei.id, pZhangWei), (pLiMing.id, pLiMing),
    (pWangFang.id, pWangFang), (pZhaoLi.id, pZhaoLi),
    (pLiuQiang.id, pLiuQiang), (pChenGang.id, pChenGang),
    (pYangYang.id, pYangYang), (pZhouJie.id, pZhouJie),
    (pHuangMin.id, pHuangMin), (pWuTing.id, pWuTing),
    (pSunLei.id, pSunLei), (pQianFeng.id, pQianFeng),
    (pYanLi.id, pYanLi), (pQiaoXiu.id, pQiaoXiu),
    (pFengJing.id, pFengJing), (pDongJuan.id, pDongJuan),
    (p1.id, p1), (p2.id, p2),
  ])

/* ── Team map ── */
let teams: Id.Map.t<Team.t> =
  Map.fromArray(~id=Id.id, [
    (tNanshan.id, tNanshan), (tLeiting.id, tLeiting),
    (tDongqu.id, tDongqu), (tFengyun.id, tFengyun),
    (tZhongqu.id, tZhongqu), (tBeian.id, tBeian),
    (tQunying.id, tQunying), (tZuanshi.id, tZuanshi),
  ])

/* ═══════════════════════════════════════════════════════════
   测试比赛结果
   ═══════════════════════════════════════════════════════════ */

/* 南山闪电(K=13) 胜 雷霆战队(8) → 场分3:1, net=+5/-5, cum=11/6 */
let matchR1_001: Match.t = {
  id: "Match_R1_001________"->id,
  team1Id: tNanshan.id, team2Id: tLeiting.id,
  result: {team1Level: Level.King, team2Level: Level.Eight, winner: Some(Match.Result.Team1Won)},
  tableNumber: Some(1),
}
/* 风云双雄(Q=12) 胜 东区虎啸(J=11) → 场分1:3, net=-1/+1, cum=9/10 */
let matchR1_002: Match.t = {
  id: "Match_R1_002________"->id,
  team1Id: tDongqu.id, team2Id: tFengyun.id,
  result: {team1Level: Level.Jack, team2Level: Level.Queen, winner: Some(Match.Result.Team2Won)},
  tableNumber: Some(2),
}
/* 中区飞鹰(10) 平 北岸龙腾(10) → 场分2:2, net=0, cum=8/8 */
let matchR1_003: Match.t = {
  id: "Match_R1_003________"->id,
  team1Id: tZhongqu.id, team2Id: tBeian.id,
  result: {team1Level: Level.Ten, team2Level: Level.Ten, winner: None},
  tableNumber: Some(3),
}
/* 群英荟萃(A=14) 胜 钻石风暴(9) → 场分3:1, net=+5/-5, cum=13/7 */
let matchR1_004: Match.t = {
  id: "Match_R1_004________"->id,
  team1Id: tQunying.id, team2Id: tZuanshi.id,
  result: {team1Level: Level.Ace, team2Level: Level.Nine, winner: Some(Match.Result.Team1Won)},
  tableNumber: Some(4),
}

let round1: Data_Rounds.Round.t = Data_Rounds.Round.fromArray([
  matchR1_001, matchR1_002, matchR1_003, matchR1_004,
])

/* ═══════════════════════════════════════════════════════════
   测试锦标赛：「掼蛋测试赛」
   第1轮4场比赛，覆盖胜/平/负 + 多种等级
   预期排名（场分 → 累积小分）：
     1. 群英荟萃 3.0 (cum=13, Ace)
     2. 南山闪电 3.0 (cum=11, King)
     3. 风云双雄 3.0 (cum=10, Queen)
     4. 中区飞鹰 2.0 (cum=8, Ten)
     5. 北岸龙腾 2.0 (cum=8, Ten, draw vs 中区)
     6. 东区虎啸 1.0 (cum=9, Jack)
     7. 钻石风暴 1.0 (cum=7, Nine)
     8. 雷霆战队 1.0 (cum=6, Eight)
   ═══════════════════════════════════════════════════════════ */

let testTournament: Tournament.t = {
  id: "Test_Guandan_Tourn_"->id,
  name: "掼蛋测试赛",
  format: Tournament.Format.default,
  date: Js.Date.fromString("2026-01-01T00:00:00.000Z"),
  teamIds: Set.fromArray(~id=Id.id, [
    tNanshan.id, tLeiting.id, tDongqu.id, tFengyun.id,
    tZhongqu.id, tBeian.id, tQunying.id, tZuanshi.id,
  ]),
  byeQueue: [],
  tieBreaks: Scoring.defaultTieBreaks,
  roundList: Data_Rounds.fromArray([round1]),
}

/* ── Config ── */
let config = Config.default
let tournaments: Id.Map.t<Tournament.t> =
  Map.fromArray(~id=Id.id, [(testTournament.id, testTournament)])
