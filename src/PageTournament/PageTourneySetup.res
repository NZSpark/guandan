/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0.
*/
open! Belt
open Data

@react.component
let make = (~tourney: Tournament.t, ~setTourney: Tournament.t => unit, ~goToPage: Pages.Page.t => unit) => {
  let changeName = e => {
    let newName = ReactEvent.Form.target(e)["value"]
    setTourney({...tourney, name: newName})
  }

  let changeFormat = e => {
    let value = ReactEvent.Form.target(e)["value"]
    let newFormat = Tournament.Format.fromString(value)
    setTourney({...tourney, format: newFormat})
  }

  /* 显示当前赛制的额外选项 */
  let formatSpecificOptions = switch tourney.format {
  | Tournament.Format.Swiss => React.null
  | Tournament.Format.GroupStage({groupCount}) =>
    <div className="form-group">
      <label> {React.string("分组数")} </label>
      <small>
        {React.string("当前 " ++ Int.toString(groupCount) ++ " 组。" ++
          "可通过格式字符串调整（group:分组数）。")}
      </small>
    </div>
  | Tournament.Format.Knockout({teamCount}) =>
    <div className="form-group">
      <label> {React.string("淘汰赛规模")} </label>
      <small>
        {React.string("当前 " ++ Int.toString(teamCount) ++ " 强淘汰赛。" ++
          "可通过格式字符串调整（knockout:队伍数）。")}
      </small>
    </div>
  }

  /* 赛制说明 */
  let formatDescription = switch tourney.format {
  | Tournament.Format.Swiss =>
    React.string("每轮按积分高低配对，同分相遇。适合人数较多的海选赛。")
  | Tournament.Format.GroupStage(_) =>
    React.string("蛇形分组，组内单循环。每组4队较理想。适合中等规模的赛事。")
  | Tournament.Format.Knockout(_) =>
    React.string("种子排位，标准对阵表。单败淘汰制。适合决赛阶段。")
  }

  <>
    <h2> {React.string("赛事设置")} </h2>
    <form onSubmit={e => {
      ReactEvent.Form.preventDefault(e)
      goToPage(Pages.Page.TourneyPlayers(tourney.id))
    }}>
      <div className="form-group">
        <label htmlFor="tourneyName"> {React.string("赛事名称")} </label>
        <input
          id="tourneyName"
          type_="text"
          value={tourney.name}
          onChange={changeName}
          placeholder="输入赛事名称..."
          required=true
        />
      </div>
      <div className="form-group">
        <label htmlFor="tourneyFormat"> {React.string("赛制")} </label>
        <select
          id="tourneyFormat"
          value={tourney.format->Tournament.Format.toString}
          onChange={changeFormat}
          className="form-select">
          <option value="swiss"> {React.string("瑞士移位制（海选）")} </option>
          <option value="group"> {React.string("小组赛（单循环）")} </option>
          <option value="knockout"> {React.string("淘汰赛")} </option>
        </select>
        <small> {formatDescription} </small>
      </div>
      {formatSpecificOptions}
      <div className="form-group">
        <label> {React.string("破同分规则")} </label>
        <p> {React.string("总积分 → 相互胜负 → 净积小分 → 累积小分")} </p>
        <small> {React.string("参照南山杯2026附录一。")} </small>
      </div>
      <div className="form-group">
        <label> {React.string("场分规则")} </label>
        <p> {React.string("胜 3 分 / 平 2 分 / 负 1 分 / 轮空 3 分")} </p>
      </div>
      <button type_="submit" className="button button-primary" disabled={tourney.name == ""}>
        {React.string("下一步：添加参赛队伍")}
      </button>
    </form>
  </>
}
