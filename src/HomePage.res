/*
  HomePage — landing page for the Aotearoa Guandan system.
  Hero section with poker card decoration, quick action cards,
  recent tournaments, and feature highlights.
*/

@react.component
let make = (~windowDispatch) => {
  let {items: tourneys, _} = Db.useAllTournaments()

  React.useEffect0(() => {
    windowDispatch(Window.SetTitle("首页"))
    Some(() => windowDispatch(Window.SetTitle("")))
  })

  let sortedArr = tourneys->Data.Id.Map.valuesToArray->Js.Array2.copy
  let _ = sortedArr->Js.Array2.sortInPlaceWith((a: Data.Tournament.t, b: Data.Tournament.t) =>
    compare(b.date->Js.Date.getTime, a.date->Js.Date.getTime)
  )
  let recent5 = sortedArr->Js.Array2.slice(~start=0, ~end_=min(5, Js.Array2.length(sortedArr)))
  let hasRecent = Js.Array2.length(recent5) > 0

  let push = (url: string) => RescriptReactRouter.push(url)
  let tourneyListUrl = "/tourneys"
  let playersUrl = "/players"
  let optionsUrl = "/options"

  <div className="homepage">
    <section className="hero">
      <div className="hero-decor">
        <img src=Utils.WebpackAssets.aotearoaLogo alt="Aotearoa 掼蛋" width="96" height="96" />
      </div>
      <h1 className="hero-title"> {React.string("Aotearoa 掼蛋俱乐部排位系统")} </h1>
      <p className="hero-subtitle">
        {React.string("基于 ")}
        <strong> {React.string("瑞士移位制")} </strong>
        {React.string(" 的专业掼蛋比赛管理工具")}
      </p>
    </section>

    <section className="quick-actions">
      <a className="quick-action-card" href=tourneyListUrl
        onClick={e => {
          ReactEvent.Mouse.preventDefault(e)
          push(tourneyListUrl)
        }}>
        <div className="quick-action-icon quick-action-icon--tournament">
          <Icons.Award />
        </div>
        <span className="quick-action-label"> {React.string("赛事管理")} </span>
        <span className="quick-action-desc"> {React.string("创建和管理比赛")} </span>
      </a>
      <a className="quick-action-card" href=playersUrl
        onClick={e => {
          ReactEvent.Mouse.preventDefault(e)
          push(playersUrl)
        }}>
        <div className="quick-action-icon quick-action-icon--players">
          <Icons.Users />
        </div>
        <span className="quick-action-label"> {React.string("选手/队伍")} </span>
        <span className="quick-action-desc"> {React.string("管理选手和队伍信息")} </span>
      </a>
      <a className="quick-action-card" href=optionsUrl
        onClick={e => {
          ReactEvent.Mouse.preventDefault(e)
          push(optionsUrl)
        }}>
        <div className="quick-action-icon quick-action-icon--settings">
          <Icons.Settings />
        </div>
        <span className="quick-action-label"> {React.string("系统设置")} </span>
        <span className="quick-action-desc"> {React.string("配置比赛规则")} </span>
      </a>
    </section>

    {if hasRecent {
      <section className="homepage-section">
        <div className="homepage-section-header">
          <h2> {React.string("最近赛事")} </h2>
          <a className="homepage-section-link" href=tourneyListUrl
            onClick={e => {
              ReactEvent.Mouse.preventDefault(e)
              push(tourneyListUrl)
            }}>
            {React.string("查看全部 →")}
          </a>
        </div>
        <div className="recent-list">
          {recent5->Js.Array2.map(t => {
            let formatLabel = Data.Tournament.Format.label(t.format)
            let detailUrl = "/tourneys/" ++ Data.Id.toString(t.id)
            <a key={t.id->Data.Id.toString} className="recent-card"
              href=detailUrl
              onClick={e => {
                ReactEvent.Mouse.preventDefault(e)
                push(detailUrl)
              }}>
              <div className="recent-card-icon"> <Icons.Award /> </div>
              <div className="recent-card-body">
                <div className="recent-card-name"> {React.string(t.name)} </div>
                <div className="recent-card-meta">
                  <span> {React.string(formatLabel)} </span>
                  <span> {React.string(" · ")} </span>
                  <Utils.DateFormat date={t.date} />
                </div>
              </div>
            </a>
          })->React.array}
        </div>
      </section>
    } else {
      React.null
    }}

    {if !hasRecent {
      <section className="homepage-section">
        <div className="homepage-section-header">
          <h2> {React.string("最近赛事")} </h2>
        </div>
        <div className="recent-empty">
          {React.string("还没有赛事，点击上方「赛事管理」创建第一场比赛吧")}
        </div>
      </section>
    } else {
      React.null
    }}

    <section className="homepage-section">
      <div className="homepage-section-header">
        <h2> {React.string("核心功能")} </h2>
      </div>
      <div className="features-grid">
        <div className="feature-item">
          <div className="feature-icon"> <Icons.Repeat /> </div>
          <div className="feature-label"> {React.string("瑞士移位制")} </div>
          <div className="feature-desc"> {React.string("自动配对，公平竞技")} </div>
        </div>
        <div className="feature-item">
          <div className="feature-icon"> <Icons.List /> </div>
          <div className="feature-label"> {React.string("实时积分榜")} </div>
          <div className="feature-desc"> {React.string("场分与级差分一目了然")} </div>
        </div>
        <div className="feature-item">
          <div className="feature-icon"> <Icons.Download /> </div>
          <div className="feature-label"> {React.string("数据导出")} </div>
          <div className="feature-desc"> {React.string("CSV 报表一键导出")} </div>
        </div>
        <div className="feature-item">
          <div className="feature-icon"> <Icons.Clock /> </div>
          <div className="feature-label"> {React.string("完整记录")} </div>
          <div className="feature-desc"> {React.string("每轮每局可追溯")} </div>
        </div>
      </div>
    </section>
  </div>
}
