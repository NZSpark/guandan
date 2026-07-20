/*
  Copyright (c) 2022 John Jackson.
  Redesigned for 掼蛋 tournament management.

  选手与队伍统一管理页面：队伍与选手一体处理，
  姓名字段不拆分，支持积分管理与CSV导入。
*/
open! Belt
open Data
module Id = Data_Id

@react.component
let make = (~windowDispatch: Window.action => unit) => {
  let {items: players, dispatch: playersDispatch, loaded: playersLoaded} = Db.useAllPlayers()
  let {items: teams, dispatch: teamsDispatch, loaded: teamsLoaded} = Db.useAllTeams()
  let {items: tournaments, dispatch: tourneysDispatch, _} = Db.useAllTournaments()

  React.useEffect1(() => {
    windowDispatch(Window.SetTitle("选手与队伍管理"))
    Some(() => windowDispatch(Window.SetTitle("")))
  }, [windowDispatch])

  /* --- Team form state --- */
  let (teamName, setTeamName) = React.useState(() => "")
  let (player1Name, setPlayer1Name) = React.useState(() => "")
  let (player1Gender, setPlayer1Gender) = React.useState(() => "男")
  let (player2Name, setPlayer2Name) = React.useState(() => "")
  let (player2Gender, setPlayer2Gender) = React.useState(() => "男")
  let (club, setClub) = React.useState(() => "")
  let (score, setScore) = React.useState(() => "0")
  let (teamError, setTeamError) = React.useState(() => "")

  /* --- CSV import state --- */
  let (importMsg, setImportMsg) = React.useState(() => "")
  let importCsvRef = React.useRef(Js.Nullable.null)

  /* Handle CSV file selection and import */
  let handleCsvFile = event => {
    module FR = Externals.FileReader
    ReactEvent.Form.preventDefault(event)
    setImportMsg(_ => "正在解析...")
    let reader = FR.make()
    let onload = ev => {
      ignore(ev)
      let data = ev["target"]["result"]
      try {
        let (newPlayers, newTeams) = Data_CSV.importData(data)
        let numPlayers = Map.size(newPlayers)
        let numTeams = Map.size(newTeams)
        if numPlayers == 0 || numTeams == 0 {
          setImportMsg(_ => "CSV解析失败：未找到有效数据。请检查文件格式。")
        } else {
          /* Merge with existing data (keep existing, add new) */
          let mergedPlayers = Map.merge(newPlayers, players, (_key, optNew, optOld) =>
            switch (optOld, optNew) {
            | (Some(existing), _) => Some(existing)
            | (None, Some(new_)) => Some(new_)
            | (None, None) => None
            }
          )
          let mergedTeams = Map.merge(newTeams, teams, (_key, optNew, optOld) =>
            switch (optOld, optNew) {
            | (Some(existing), _) => Some(existing)
            | (None, Some(new_)) => Some(new_)
            | (None, None) => None
            }
          )
          playersDispatch(SetAll(mergedPlayers))
          teamsDispatch(SetAll(mergedTeams))
          /* Auto-create default tournament if none exists */
          let baseMsg = "成功导入 " ++ Belt.Int.toString(numPlayers) ++ " 名选手，" ++ Belt.Int.toString(numTeams) ++ " 支队伍。"
          if Map.size(tournaments) == 0 {
            let defaultId = Id.random()
            tourneysDispatch(Set(defaultId, Data.Tournament.make(~id=defaultId, ~name="南山杯2026掼蛋大赛")))
            setImportMsg(_ => baseMsg ++ " 已自动创建赛事「南山杯2026掼蛋大赛」。")
          } else {
            setImportMsg(_ => baseMsg)
          }
        }
      } catch {
      | _ => setImportMsg(_ => "CSV解析失败：文件格式不正确。")
      }
    }
    FR.setOnLoad(reader, onload)
    FR.readAsText(
      reader,
      ReactEvent.Form.currentTarget(event)["files"]->Array.get(0)->Option.getWithDefault(""),
    )
    /* Reset file input so the same file can be re-imported */
    switch Js.Nullable.toOption(importCsvRef.current) {
    | Some(el) => (el: Js.t<'a>)["value"] = ""
    | None => ()
    }
  }

  let addTeam = () => {
    if teamName == "" {
      setTeamError(_ => "队伍名称不能为空")
    } else if player1Name == "" || player2Name == "" {
      setTeamError(_ => "队员姓名不能为空")
    } else if player1Name == player2Name {
      setTeamError(_ => "两名队员姓名不能相同")
    } else {
      let teamId = Id.random()
      let p1Id = Id.random()
      let p2Id = Id.random()
      let p1: Data_Player.t = {id: p1Id, firstName: player1Name, lastName: "", gender: player1Gender}
      let p2: Data_Player.t = {id: p2Id, firstName: player2Name, lastName: "", gender: player2Gender}

      let scoreFloat = Belt.Float.fromString(score)->Belt.Option.getWithDefault(0.0)

      playersDispatch(Set(p1Id, p1))
      playersDispatch(Set(p2Id, p2))
      teamsDispatch(Set(teamId, {
        id: teamId,
        name: teamName,
        player1Id: p1Id,
        player2Id: p2Id,
        isBye: false,
        club,
        initialScore: scoreFloat,
      }))
      setTeamName(_ => "")
      setPlayer1Name(_ => "")
      setPlayer1Gender(_ => "男")
      setPlayer2Name(_ => "")
      setPlayer2Gender(_ => "男")
      setClub(_ => "")
      setScore(_ => "0")
      setTeamError(_ => "")
    }
  }

  let delTeam = (id: Id.t) => {
    /* Also delete associated players */
    let team = Map.get(teams, id)
    switch team {
    | Some(t) =>
      playersDispatch(Del(t.player1Id))
      playersDispatch(Del(t.player2Id))
      teamsDispatch(Del(id))
    | None => teamsDispatch(Del(id))
    }
  }

  /* Sort teams by score descending, then by name */
  let teamList = teams
    ->Map.valuesToArray
    ->SortArray.stableSortBy((a, b) =>
      switch compare(b.initialScore, a.initialScore) {
      | 0 => Team.compareName(a, b)
      | x => x
      }
    )

  let isLoaded = playersLoaded && teamsLoaded
  Hooks.useLoadingCursorUntil(isLoaded)

  <Window.Body windowDispatch>
    <div className="content-area">
    <h1> {React.string("选手与队伍管理")} </h1>

    // Toolbar
    <div style={marginBottom: "1rem"}>
      <input
        style={display: "none"}
        type_="file"
        accept=".csv"
        ref={importCsvRef->Obj.magic}
        onChange=handleCsvFile
      />
      <button
        className="button button-primary"
        onClick={_ => {
          switch Js.Nullable.toOption(importCsvRef.current) {
          | Some(el) => (el: Js.t<'a>)["click"]()
          | None => ()
          }
        }}>
        {React.string("导入CSV")}
      </button>
    </div>

    // Import message
    {importMsg != ""
      ? {
        let isError = Js.String2.includes(importMsg, "失败")
        <div
          style={
            padding: "0.5rem 1rem",
            marginBottom: "1rem",
            borderRadius: "4px",
            backgroundColor: isError ? "#fee" : "#efe",
            color: isError ? "#c00" : "#060",
          }>
          {React.string(importMsg)}
        </div>
      }
      : React.null}

    {if !isLoaded {
      <p> {React.string("加载中...")} </p>
    } else {
      <>
        // Add team form
        <h2> {React.string("添加队伍")} </h2>
        <div className="form-group" style={display: "flex", flexWrap: "wrap", gap: "0.5rem", alignItems: "flex-end"}>
          <div>
            <label style={display: "block", fontSize: "0.8rem", marginBottom: "0.15rem"}>
              {React.string("队伍名称")}
            </label>
            <input
              type_="text"
              placeholder="队伍名称"
              value=teamName
              onChange={e => setTeamName(_ => ReactEvent.Form.target(e)["value"])}
            />
          </div>
          <div>
            <label style={display: "block", fontSize: "0.8rem", marginBottom: "0.15rem"}>
              {React.string("队员1")}
            </label>
            <div style={display: "flex", gap: "0.25rem"}>
              <input
                type_="text"
                placeholder="姓名"
                value=player1Name
                onChange={e => setPlayer1Name(_ => ReactEvent.Form.target(e)["value"])}
                style={width: "7rem"}
              />
              <select
                value=player1Gender
                onChange={e => setPlayer1Gender(_ => ReactEvent.Form.target(e)["value"])}
                style={width: "4rem"}>
                <option value="男"> {React.string("男")} </option>
                <option value="女"> {React.string("女")} </option>
              </select>
            </div>
          </div>
          <div>
            <label style={display: "block", fontSize: "0.8rem", marginBottom: "0.15rem"}>
              {React.string("队员2")}
            </label>
            <div style={display: "flex", gap: "0.25rem"}>
              <input
                type_="text"
                placeholder="姓名"
                value=player2Name
                onChange={e => setPlayer2Name(_ => ReactEvent.Form.target(e)["value"])}
                style={width: "7rem"}
              />
              <select
                value=player2Gender
                onChange={e => setPlayer2Gender(_ => ReactEvent.Form.target(e)["value"])}
                style={width: "4rem"}>
                <option value="男"> {React.string("男")} </option>
                <option value="女"> {React.string("女")} </option>
              </select>
            </div>
          </div>
          <div>
            <label style={display: "block", fontSize: "0.8rem", marginBottom: "0.15rem"}>
              {React.string("俱乐部")}
            </label>
            <input
              type_="text"
              placeholder="可选"
              value=club
              onChange={e => setClub(_ => ReactEvent.Form.target(e)["value"])}
              style={width: "9rem"}
            />
          </div>
          <div>
            <label style={display: "block", fontSize: "0.8rem", marginBottom: "0.15rem"}>
              {React.string("当前积分")}
            </label>
            <input
              type_="number"
              placeholder="0"
              value=score
              onChange={e => setScore(_ => ReactEvent.Form.target(e)["value"])}
              style={width: "5rem"}
            />
          </div>
          <div>
            <button className="button button-primary" onClick={_ => addTeam()}>
              {React.string("添加队伍")}
            </button>
          </div>
        </div>
        {if teamError != "" {
          <p style={color: "red", marginTop: "0.25rem"}> {React.string(teamError)} </p>
        } else {
          React.null
        }}

        // Team list
        <h2> {React.string("队伍列表")} ({React.int(Map.size(teams))}) </h2>
        {if Array.length(teamList) == 0 {
          <p> {React.string("暂无队伍，请通过表单添加或导入CSV文件。")} </p>
        } else {
          <table className="table">
            <thead>
              <tr>
                <th> {React.string("队伍名称")} </th>
                <th> {React.string("队员1")} </th>
                <th> {React.string("队员2")} </th>
                <th> {React.string("所属俱乐部")} </th>
                <th> {React.string("当前积分")} </th>
                <th> {React.string("操作")} </th>
              </tr>
            </thead>
            <tbody>
              {teamList->Array.map(t => {
                let p1 = Player.getMaybe(players, t.player1Id)
                let p2 = Player.getMaybe(players, t.player2Id)
                <tr key={Id.toString(t.id)}>
                  <td> <strong> {React.string(t.name)} </strong> </td>
                  <td> {React.string(Player.fullName(p1) ++ (p1.gender != "" ? "（" ++ p1.gender ++ "）" : ""))} </td>
                  <td> {React.string(Player.fullName(p2) ++ (p2.gender != "" ? "（" ++ p2.gender ++ "）" : ""))} </td>
                  <td> {React.string(t.club != "" ? t.club : "-")} </td>
                  <td> {React.string(Js.Float.toString(t.initialScore))} </td>
                  <td>
                    <button className="button-micro button-danger" onClick={_ => delTeam(t.id)}>
                      {React.string("删除")}
                    </button>
                  </td>
                </tr>
              })->React.array}
            </tbody>
          </table>
        }}
      </>
    }}
    </div>
  </Window.Body>
}
