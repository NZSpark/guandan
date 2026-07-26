/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/

module BaseDialog = {
  @react.component
  let make = (~state as {Hooks.state: state, setFalse, _}, ~ariaLabel, ~children) =>
    <Externals.Dialog isOpen=state onDismiss=setFalse ariaLabel className="">
      <button className="button-micro" onClick={_ => setFalse()}> {React.string("完成")} </button>
      children
    </Externals.Dialog>
}

module Pairing = {
  @react.component
  let make = (~state, ~ariaLabel) =>
    <BaseDialog state ariaLabel>
      <p>
        {React.string("瑞士移位制的有效性取决于根据特定优先级仔细配对队伍。自动配对功能可自动计算理想的配对。")}
      </p>
      <p> {React.string("配对规则如下：")} </p>
      <ol>
        <li> {React.string("两支队伍在同一赛事中不应多次相遇。")} </li>
        <li> {React.string("场分相同的队伍应配对在一起。")} </li>
        <li> {React.string("同分组内，上半区的队伍应与下半区的队伍交叉配对。")} </li>
      </ol>
      <p> {React.string("规则一是最重要的规则，规则二紧随其后。您永远无法在每个轮次中对每一对队伍都完美地遵循所有这些规则，自动配对会尽最大努力遵循尽可能多的规则。")} </p>
    </BaseDialog>
}

module SwissTournament = {
  @react.component
  let make = (~state, ~ariaLabel) =>
    <BaseDialog state ariaLabel>
      <p>
        {React.string("Aotearoa掼蛋俱乐部排位系统支持三种赛制：瑞士移位制、小组循环赛和淘汰赛。瑞士移位制根据积分配对，同分队相遇且不重复对阵。")}
      </p>
      <p>
        {React.string("海选赛破同分规则: 总积分 → 对手分 → 胜场数 → 贡献分（累积小分）")}
      </p>
      <p>
        {React.string("小组赛破同分规则: 总积分 → 相互胜负 → 净积小分 → 累积小分")}
      </p>
    </BaseDialog>
}

module TieBreaks = {
  let s = x => Data.Scoring.TieBreak.toPrettyString(x)->React.string

  @react.component
  let make = (~state, ~ariaLabel) =>
    <BaseDialog state ariaLabel>
      <p> {React.string("掼蛋计分与破同分规则（参照南山杯2026附录一）：")} </p>
      <h3> {React.string("场分规则")} </h3>
      <p> {React.string("胜方得1分，打平各得0.5分，负方得0分。缺席队伍得-1分（对手自动获胜记1分）。轮空自动获胜记1分。")} </p>
      <h3> {React.string("海选赛破同分")} </h3>
      <dl>
        <dt className="title-20"> {s(TotalFieldScore)} </dt>
        <dd> {React.string("各轮场分之和。")} </dd>
        <dt className="title-20"> {s(OpponentScore)} </dt>
        <dd> {React.string("所有对手的场分之和（Buchholz 对手分）。对手越强，对手分越高。")} </dd>
        <dt className="title-20"> {s(Wins)} </dt>
        <dd> {React.string("胜场数。胜场多者优先。")} </dd>
        <dt className="title-20"> {s(CumulativeSmallScore)} </dt>
        <dd> {React.string("各轮累积小分之和。累积小分 = (己方级数-2) + 过A另加1分。")} </dd>
      </dl>
      <h3> {React.string("小组赛破同分")} </h3>
      <dl>
        <dt className="title-20"> {s(TotalFieldScore)} </dt>
        <dd> {React.string("各轮场分之和。")} </dd>
        <dt className="title-20"> {s(DirectEncounter)} </dt>
        <dd> {React.string("同分队之间的直接对决结果，胜者优先。")} </dd>
        <dt className="title-20"> {s(NetSmallScore)} </dt>
        <dd> {React.string("各轮净积小分之和。净积小分 = 己方级数 - 对方级数。")} </dd>
        <dt className="title-20"> {s(CumulativeSmallScore)} </dt>
        <dd> {React.string("各轮累积小分之和。累积小分 = (己方级数-2) + 过A另加1分。")} </dd>
      </dl>
    </BaseDialog>
}
