/*
  Copyright (c) 2022 John Jackson.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/
open! Belt
open Router

let global_title = "Aotearoa掼蛋俱乐部排位系统"

let formatTitle = x =>
  switch x {
  | "" => global_title
  | title => title ++ " - " ++ global_title
  }

type windowState = {
  isDialogOpen: bool,
  isMobileSidebarOpen: bool,
  title: string,
}

let initialWinState = {isDialogOpen: false, isMobileSidebarOpen: false, title: ""}

type action =
  | SetDialog(bool)
  | SetSidebar(bool)
  | SetTitle(string)

let windowReducer = (state, action) =>
  switch action {
  | SetTitle(title) =>
    Webapi.Dom.document
    ->Webapi.Dom.Document.asHtmlDocument
    ->Option.forEach(Webapi.Dom.HtmlDocument.setTitle(_, formatTitle(title)))
    {...state, title}
  | SetDialog(isDialogOpen) => {...state, isDialogOpen}
  | SetSidebar(isMobileSidebarOpen) => {...state, isMobileSidebarOpen}
  }

module About = {
  @val
  external gitModified: string = "__LAST_COMMIT_DATE__"
  @react.component
  let make = () =>
    <article className="win__about">
      <div style={{flex: "0 0 48%", textAlign: "center"}}>
        <img src=Utils.WebpackAssets.logo height="196" width="196" alt="" />
      </div>
      <div style={{flex: "0 0 48%"}}>
        <h1 className="title" style={{textAlign: "left"}}> {React.string("Aotearoa掼蛋俱乐部排位系统")} </h1>
        <p> {React.string(`最后更新于 ${gitModified}。`)} </p>
        <p> {React.string("基于 Swiss-system 瑞士移位制。")} </p>
        <p> {React.string("计分规则参照南山杯 Aotearoa 掼蛋大赛指南（2026）及《掼蛋（国家）竞赛规则（2017版）》。")} </p>
        <p> {React.string("AotearoaGuandan 是免费软件。")} </p>
      </div>
    </article>
}

module TitleBar = {
  let toolbarClasses = "win__titlebar-button button-ghost button-ghost-large"
  @react.component
  let make = (~isMobileSidebarOpen, ~title, ~dispatch) =>
    <header className="app__header">
      <button
        className={`mobile-only ${toolbarClasses}`}
        onClick={_ => dispatch(SetSidebar(!isMobileSidebarOpen))}>
        <Icons.Menu />
        <Externals.VisuallyHidden> {React.string("切换侧边栏")} </Externals.VisuallyHidden>
      </button>
      <div
        className="body-20"
        style={{
          left: "0",
          marginLeft: "auto",
          marginRight: "auto",
          position: "absolute",
          right: "0",
          textAlign: "center",
          width: "50%",
          whiteSpace: "nowrap",
          overflow: "hidden",
        }}>
        {title->formatTitle->React.string}
      </div>
      <button className=toolbarClasses onClick={_ => dispatch(SetDialog(true))}>
        <Icons.Help />
        <Externals.VisuallyHidden> {React.string("关于 AotearoaGuandan")} </Externals.VisuallyHidden>
      </button>
    </header>
}

@react.component
let make = (~children, ~className) => {
  let (state, dispatch) = React.useReducer(windowReducer, initialWinState)
  let {isMobileSidebarOpen, isDialogOpen, title} = state
  <div
    className={`${className} ${isMobileSidebarOpen
        ? "mobile-sidebar-open"
        : "mobile-sidebar-closed"}`}>
    <TitleBar isMobileSidebarOpen title dispatch />
    {children(dispatch)}
    <Externals.Dialog
      isOpen=isDialogOpen
      onDismiss={() => dispatch(SetDialog(false))}
      className="win__about-dialog"
      ariaLabel="关于 AotearoaGuandan">
      <button className="button-micro" onClick={_ => dispatch(SetDialog(false))}>
        {React.string("关闭")}
      </button>
      <About />
    </Externals.Dialog>
  </div>
}

let noDraggy = e => ReactEvent.Mouse.preventDefault(e)

module DefaultSidebar = {
  @react.component
  let make = (~dispatch) =>
    <nav>
      <ul style={{margin: "0"}}>
        <li>
          <Link to_=Index onDragStart=noDraggy onClick={_ => dispatch(SetSidebar(false))}>
            <Icons.Home />
            <span className="sidebar__hide-on-close">
              {React.string(HtmlEntities.nbsp ++ "首页")}
            </span>
          </Link>
        </li>
        <li>
          <Link to_=TournamentList onDragStart=noDraggy onClick={_ => dispatch(SetSidebar(false))}>
            <Icons.Award />
            <span className="sidebar__hide-on-close">
              {React.string(HtmlEntities.nbsp ++ "掼蛋赛事")}
            </span>
          </Link>
        </li>
        <li>
          <Link to_=Players onDragStart=noDraggy onClick={_ => dispatch(SetSidebar(false))}>
            <Icons.Users />
            <span className="sidebar__hide-on-close">
              {React.string(HtmlEntities.nbsp ++ "选手/队伍")}
            </span>
          </Link>
        </li>
        <li>
          <Link to_=Options onDragStart=noDraggy onClick={_ => dispatch(SetSidebar(false))}>
            <Icons.Settings />
            <span className="sidebar__hide-on-close">
              {React.string(HtmlEntities.nbsp ++ "选项")}
            </span>
          </Link>
        </li>
      </ul>
    </nav>
}

let sidebarCallback = dispatch => <DefaultSidebar dispatch />

module Body = {
  @react.component
  let make = (~children, ~windowDispatch, ~footerFunc=?, ~sidebarFunc=sidebarCallback) =>
    <div className={`winBody ${footerFunc != None ? "winBody-hasFooter" : ""}`}>
      <div className="win__sidebar"> {sidebarFunc(windowDispatch)} </div>
      <div className="win__content"> children </div>
      {switch footerFunc {
      | Some(footer) => <footer className="win__footer"> {footer()} </footer>
      | None => React.null
      }}
    </div>
}
