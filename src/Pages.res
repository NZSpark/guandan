/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/

module Splash = {
  @react.component
  let make = () =>
    <div className="content-area">
      <h1> {React.string("Aotearoa掼蛋俱乐部排位系统")} </h1>
      <p> {React.string("基于瑞士移位制的掼蛋比赛管理工具。")} </p>
      <p> {React.string("计分规则参照南山杯 Aotearoa 掼蛋大赛指南（2026）及掼蛋（国家）竞赛规则（2017版）。")} </p>
      <p>
        {React.string("在侧边栏中选择掼蛋赛事开始，或选择选手/队伍管理选手和队伍。")}
      </p>
    </div>
}

module TimeCalculator = {
  let title = "计时钟"

  @react.component
  let make = () =>
    <div className="content-area">
      <h1> {React.string("计时钟")} </h1>
      <p> {React.string("此功能暂未开放。")} </p>
    </div>
}

module NotFound = {
  @react.component
  let make = () =>
    <div className="content-area">
      <h1> {React.string("404 - 页面未找到")} </h1>
      <p> {React.string("您访问的页面不存在。")} </p>
    </div>
}

module Page = {
  type t =
    | TournamentList
    | Options
    | Players
    | Tourney(Data_Id.t)
    | TourneySetup(Data_Id.t)
    | TourneyPlayers(Data_Id.t)
    | Help
    | NotFound
}

let goToPage = (setPage, page) => {
  open Page
  let p = switch page {
  | TournamentList => "/"
  | Options => "/options"
  | Players => "/players"
  | Tourney(id) => "/tourney/" ++ Data_Id.toString(id)
  | TourneySetup(id) => "/tourney/" ++ Data_Id.toString(id) ++ "/setup"
  | TourneyPlayers(id) => "/tourney/" ++ Data_Id.toString(id) ++ "/players"
  | Help => "/help"
  | NotFound => "/404"
  }
  Webapi.Dom.Window.setLocation(Webapi.Dom.window, p)
  setPage(_ => page)
}
