/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/
open Router
open Data.Tournament

/* These can't be definined inline or the comparisons don't work. */
let dateSort = Hooks.GetDate(x => x.date)

@react.component
let make = (~windowDispatch=_ => ()) => {
  let {items: tourneys, dispatch, _} = Db.useAllTournaments()
  let (sorted, sortDispatch) = Hooks.useSortedTable(
    ~table=Data.Id.Map.valuesToArray(tourneys),
    ~column=dateSort,
    ~isDescending=true,
  )
  let (newTourneyName, setNewTourneyName) = React.useState(() => "")
  let newTourneyDialog = Hooks.useBool(false)
  let helpDialog = Hooks.useBool(false)
  React.useEffect1(() => {
    windowDispatch(Window.SetTitle("赛事列表"))
    Some(() => windowDispatch(Window.SetTitle("")))
  }, [windowDispatch])
  React.useEffect2(() => {
    sortDispatch(Hooks.SetTable(Data.Id.Map.valuesToArray(tourneys)))
    None
  }, (tourneys, sortDispatch))

  let updateNewName = event => setNewTourneyName(ReactEvent.Form.currentTarget(event)["value"])
  let makeTournament = event => {
    ReactEvent.Form.preventDefault(event)
    let id = Data.Id.random()
    dispatch(Set(id, Data.Tournament.make(~id, ~name=newTourneyName)))
    setNewTourneyName(_ => "")
    newTourneyDialog.setFalse()
  }
  let deleteTournament = (id, name) => {
    let message = `您确定要删除 "${name}" 吗？`
    if Webapi.Dom.Window.confirm(Webapi.Dom.window, message) {
      dispatch(Del(id))
    }
  }

  let formatLabel = (format: Format.t) => Format.label(format)

  <Window.Body windowDispatch>
    <div className="content-area">
      <h2 className="page-title"> {React.string("掼蛋赛事")} </h2>

      <div className="toolbar">
        <button onClick={_ => newTourneyDialog.setTrue()}>
          <Icons.Plus />
          {React.string(" 创建赛事")}
        </button>
        <button className="button-ghost" onClick={_ => helpDialog.setTrue()}>
          <Icons.Help />
          <Externals.VisuallyHidden>
            {React.string(" 赛事信息")}
          </Externals.VisuallyHidden>
        </button>
      </div>
      <HelpDialogs.SwissTournament state=helpDialog ariaLabel="赛事信息" />

      {if Array.length(sorted.table) === 0 {
        <EmptyState
          icon=EmptyState.Trophy
          title="暂无赛事"
          description="点击「创建赛事」添加您的第一场比赛。"
        />
      } else {
        <div className="tournament-list">
          {Array.map(sorted.table, ({id, date, name, format, _}) =>
            <div key={id->Data.Id.toString} className="tournament-list-card">
              <div className="tournament-list-card-name">
                <Link to_=Tournament(id)> {React.string(name)} </Link>
              </div>
              <div className="tournament-list-card-meta">
                <span className="tournament-list-card-format">
                  {React.string(formatLabel(format))}
                </span>
                <span className="tournament-list-card-date">
                  <Utils.DateFormat date />
                </span>
              </div>
              <div className="tournament-list-card-actions">
                <button
                  ariaLabel={`删除 "${name}"`}
                  className="danger button-ghost"
                  title={"删除 " ++ name}
                  onClick={_ => deleteTournament(id, name)}>
                  <Icons.Trash />
                </button>
              </div>
            </div>
          )->React.array}
        </div>
      }}

      <Externals.Dialog
        isOpen=newTourneyDialog.state
        onDismiss=newTourneyDialog.setFalse
        ariaLabel="创建新赛事"
        className="">
        <button className="button-micro" onClick={_ => newTourneyDialog.setFalse()}>
          {React.string("关闭")}
        </button>
        <form onSubmit=makeTournament>
          <fieldset>
            <legend> {React.string("创建新赛事")} </legend>
            <p>
              <label htmlFor="tourney-name"> {React.string("名称:")} </label>
              <input
                id="tourney-name"
                name="tourney-name"
                placeholder="赛事名称"
                required=true
                type_="text"
                value=newTourneyName
                onChange=updateNewName
              />
            </p>
            <p>
              <input className="button-primary" type_="submit" value="创建" />
            </p>
          </fieldset>
        </form>
      </Externals.Dialog>
    </div>
  </Window.Body>
}
