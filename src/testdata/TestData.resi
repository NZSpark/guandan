/*
  Copyright (c) 2021 John Jackson. 
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/

/* ── Players ── */
let p1: Data.Player.t
let p2: Data.Player.t
let pZhangWei: Data.Player.t
let pLiMing: Data.Player.t
let pWangFang: Data.Player.t
let pZhaoLi: Data.Player.t
let pLiuQiang: Data.Player.t
let pChenGang: Data.Player.t
let pYangYang: Data.Player.t
let pZhouJie: Data.Player.t
let pHuangMin: Data.Player.t
let pWuTing: Data.Player.t
let pSunLei: Data.Player.t
let pQianFeng: Data.Player.t
let pYanLi: Data.Player.t
let pQiaoXiu: Data.Player.t
let pFengJing: Data.Player.t
let pDongJuan: Data.Player.t

/* ── Teams ── */
let tNanshan: Data.Team.t
let tLeiting: Data.Team.t
let tDongqu: Data.Team.t
let tFengyun: Data.Team.t
let tZhongqu: Data.Team.t
let tBeian: Data.Team.t
let tQunying: Data.Team.t
let tZuanshi: Data.Team.t

/* ── Maps ── */
let players: Data.Id.Map.t<Data.Player.t>
let teams: Data.Id.Map.t<Data.Team.t>

/* ── Tournament ── */
let testTournament: Data.Tournament.t
let tournaments: Data.Id.Map.t<Data.Tournament.t>

/* ── Config ── */
let config: Data.Config.t
