/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/
open! Belt
open Data

@val external _devMode: bool = "import.meta.env.DEV"

let getDateForFile = () => {
  let date = Js.Date.make()
  [
    date->Js.Date.getFullYear->Float.toString,
    (Js.Date.getMonth(date) +. 1.0)->Numeral.make->Numeral.format("00"),
    Js.Date.getDate(date)->Numeral.make->Numeral.format("00"),
  ]->Js.Array2.joinWith("-")
}

let invalidAlert = () =>
  Webapi.Dom.Window.alert(
    Webapi.Dom.window,
    "数据无效！目前暂无法提供更详细的错误信息。",
  )

let dictToMap = dict => dict->Js.Dict.entries->Data.Id.Map.fromStringArray
let mapToDict = map => map->Data.Id.Map.toStringArray->Js.Dict.fromArray

type input_data = {
  config: Config.t,
  players: Data.Id.Map.t<Player.t>,
  teams: Data.Id.Map.t<Team.t>,
  tournaments: Data.Id.Map.t<Tournament.t>,
}

@raises(Not_found)
let decodeOptions = json => {
  let d = Js.Json.decodeObject(json)->Option.getExn
  {
    config: d->Js.Dict.get("config")->Option.getExn->Config.decode,
    players: d
    ->Js.Dict.get("players")
    ->Option.flatMap(Js.Json.decodeObject)
    ->Option.getExn
    ->dictToMap
    ->Map.map(Player.decode),
    teams: d
    ->Js.Dict.get("teams")
    ->Option.flatMap(Js.Json.decodeObject)
    ->Option.getExn
    ->dictToMap
    ->Map.map(Team.decode),
    tournaments: d
    ->Js.Dict.get("tournaments")
    ->Option.flatMap(Js.Json.decodeObject)
    ->Option.getExn
    ->dictToMap
    ->Map.map(Tournament.decode),
  }
}

let encodeOptions = data =>
  Js.Dict.fromArray([
    ("config", Config.encode(data.config)),
    ("players", Map.map(data.players, Player.encode)->mapToDict->Js.Json.object_),
    ("teams", Map.map(data.teams, Team.encode)->mapToDict->Js.Json.object_),
    ("tournaments", Map.map(data.tournaments, Tournament.encode)->mapToDict->Js.Json.object_),
  ])->Js.Json.object_

module LastBackupDate = {
  @react.component
  let make = (~date) =>
    if Js.Date.getTime(date) == 0.0 {
      React.string("从未")
    } else {
      <Utils.DateTimeFormat date />
    }
}

module GistOpts = {
  let dateFormatter = {
    DateTimeFormat.make(
      ["en-US"],
      DateTimeFormat.Options.make(
        ~day=#"2-digit",
        ~month=#"2-digit",
        ~year=#"2-digit",
        ~hour=#"2-digit",
        ~minute=#"2-digit",
        (),
      ),
    )
  }

  @val external github_app_id: string = "import.meta.env.GITHUB_APP_ID"
  @val external netlify_id: option<string> = "import.meta.env.NETLIFY_ID"

  let netlifyopts = switch netlify_id {
  | Some(site_id) => {"site_id": site_id}
  | None => Js.Obj.empty()
  }

  let savedAlert = () => Webapi.Dom.Window.alert(Webapi.Dom.window, "数据已保存。")

  @react.component
  let make = (~exportData, ~configDispatch: Db.actionConfig => unit, ~loadJson) => {
    let (auth, authDispatch) = Db.useAuth()
    let minify = Hooks.useBool(true)
    let (gists, setGists) = React.useState(() => [])
    let cancelAllEffects = ref(false)

    let handleAuthError = e => {
      Js.Console.error(e)
      if !cancelAllEffects.contents {
        authDispatch(Reset)
      }
      Promise.resolve()
    }

    let loadGistList = (auth: Data.Auth.t) =>
      switch auth.github_token {
      | "" => Promise.resolve(setGists(_ => []))
      | token =>
        Octokit.Gist.list(~token)
        ->Promise.thenResolve((data: array<Octokit.Gist.file>) => {
          if !cancelAllEffects.contents {
            setGists(_ => data)
            if !Array.some(data, x => x.id == auth.github_gist_id) {
              authDispatch(RemoveGistId)
            }
          }
        })
        ->Promise.catch(handleAuthError)
      }

    React.useEffect1(() => {
      loadGistList(auth)->ignore
      Some(() => cancelAllEffects := true)
    }, [auth.github_token])

    <div>
      <h3> {"备份到 GitHub"->React.string} </h3>
      <p className="caption-30">
        {"使用 GitHub 账号，您可以将数据保存到 "->React.string}
        <a href="https://gist.github.com/">
          {"Gist "->React.string}
          <Icons.ExternalLink />
        </a>
        {`。注意，Gist 可以设为${HtmlEntities.ldquo}私密${HtmlEntities.rdquo}，但始终是公开可访问的。更多信息，请`->React.string}
        <a href="https://docs.github.com/en/github/writing-on-github/creating-gists">
          {"参阅 GitHub 上的 Gist 文档 "->React.string}
          <Icons.ExternalLink />
        </a>
        {"。"->React.string}
      </p>
      <p>
        {switch auth.github_token {
        | "" =>
          <button
            onClick={e => {
              ReactEvent.Mouse.preventDefault(e)
              NetlifyAuth.make(netlifyopts)->NetlifyAuth.authenticate(
                {"provider": #github, "scope": "gist"},
                (err, data) =>
                  switch (Js.Nullable.toOption(err), data) {
                  | (_, Some({token})) =>
                    if !cancelAllEffects.contents {
                      authDispatch(SetGitHubToken(token))
                    }
                  | (Some(err), _) => Js.Console.error(err)
                  | (None, None) => Js.Console.error("Something wrong happened.")
                  },
              )
            }}>
            {"使用 GitHub 登录"->React.string}
          </button>
        | _ =>
          <a href={"https://github.com/settings/connections/applications/" ++ github_app_id}>
            {"更改或取消 GitHub 授权 "->React.string}
            <Icons.ExternalLink />
          </a>
        }}
      </p>
      {switch auth.github_token {
      | "" => React.null
      | github_token =>
        <div>
            <button
            onClick={_ => {
              Octokit.Gist.create(
                ~token=github_token,
                ~data=encodeOptions(exportData),
                ~minify=minify.state,
              )
              ->Promise.thenResolve((newGist: Octokit.response<_, _>) => {
                if !cancelAllEffects.contents {
                  authDispatch(SetGistId(newGist.data["id"]))
                  configDispatch(SetLastBackup(Js.Date.make()))
                }
                savedAlert()
              })
              ->Promise.then(() => loadGistList(auth))
              ->Promise.catch(e => {
                Webapi.Dom.Window.alert(
                  Webapi.Dom.window,
                  "备份失败。请检查您的 GitHub 凭据。",
                )
                handleAuthError(e)
              })
              ->ignore
            }}>
            {"创建新的 Gist"->React.string}
          </button>
          <p className="caption-30"> {"或选择已有的 Gist。"->React.string} </p>
          <select
            value={auth.github_gist_id}
            onBlur={e => {
              let id = ReactEvent.Focus.currentTarget(e)["value"]
              authDispatch(SetGistId(id))
            }}
            onChange={e => {
              let id = ReactEvent.Form.currentTarget(e)["value"]
              authDispatch(SetGistId(id))
            }}>
            <option value=""> {"未选择 Gist。"->React.string} </option>
            {gists
            ->Array.map(({name, id, updated_at}) =>
              <option key=id value=id>
                {name->React.string}
                {" | 更新于 "->React.string}
                {DateTimeFormat.format(dateFormatter, updated_at)->React.string}
              </option>
            )
            ->React.array}
          </select>
          <p>
            <button
              onClick={_ => {
                switch auth.github_gist_id {
                | "" => Js.Console.error("Gist ID is blank.")
                | id =>
                  Octokit.Gist.write(
                    ~id,
                    ~token=github_token,
                    ~data=encodeOptions(exportData),
                    ~minify=minify.state,
                  )
                  ->Promise.thenResolve(_ => {
                    if !cancelAllEffects.contents {
                      configDispatch(SetLastBackup(Js.Date.make()))
                    }
                    savedAlert()
                  })
                  ->Promise.then(() => loadGistList(auth))
                  ->Promise.catch(e => {
                    Webapi.Dom.Window.alert(
                      Webapi.Dom.window,
                      "备份失败。请检查您的 GitHub 凭据或尝试其他 Gist。",
                    )
                    handleAuthError(e)
                  })
                  ->ignore
                }
              }}
              disabled={auth.github_gist_id == ""}>
              {"备份到此 Gist"->React.string}
            </button>
            {" "->React.string}
            <button
              onClick={_ => {
                switch auth.github_gist_id {
                | "" => Js.Console.error("Gist ID is blank.")
                | id =>
                  Octokit.Gist.read(~id, ~token=github_token)
                  ->Promise.thenResolve(result => {
                    loadJson(result)
                  })
                  ->Promise.catch(e => {
                    invalidAlert()
                    handleAuthError(e)
                  })
                  ->ignore
                }
              }}
              disabled={auth.github_gist_id == ""}>
              {"从此 Gist 加载"->React.string}
            </button>
          </p>
          <p className="caption-30">
            <label>
              <input
                type_="checkbox"
                checked=minify.state
                onChange={_ =>
                  switch minify.state {
                  | true => minify.setFalse()
                  | false => minify.setTrue()
                  }}
              />
              {" 压缩输出。"->React.string}
            </label>
          </p>
        </div>
      }}
    </div>
  }
}

@react.component
let make = (~windowDispatch=_ => ()) => {
  let {items: tournaments, dispatch: tourneysDispatch, _} = Db.useAllTournaments()
  let {items: players, dispatch: playersDispatch, _} = Db.useAllPlayers()
  let {items: teams, dispatch: teamsDispatch, _} = Db.useAllTeams()
  let (text, setText) = React.useState(() => "")
  let (config, configDispatch) = Db.useConfig()

  React.useEffect1(() => {
    windowDispatch(Window.SetTitle("选项"))
    Some(() => windowDispatch(SetTitle("")))
  }, [windowDispatch])

  /* memoize this so the `useEffect` hook syncs with the correct states */
  let exportData = React.useMemo4(
    () => {config, players, teams, tournaments},
    (config, tournaments, players, teams),
  )
  let exportDataURI = exportData->encodeOptions->Js.Json.stringify->Js.Global.encodeURIComponent
  React.useEffect2(() => {
    let encoded = encodeOptions(exportData)
    let json = Js.Json.stringifyWithSpace(encoded, 2)
    setText(_ => json)
    None
  }, (exportData, setText))

  let loadData = (~tournaments, ~players, ~teams, ~config) => {
    tourneysDispatch(SetAll(tournaments))
    configDispatch(SetState(config))
    playersDispatch(SetAll(players))
    teamsDispatch(SetAll(teams))
    Webapi.Dom.Window.alert(Webapi.Dom.window, "数据已加载。")
  }

  let loadJson = json =>
    try {
      let {config, players, teams, tournaments} = json->Js.Json.parseExn->decodeOptions
      loadData(~tournaments, ~players, ~teams, ~config)
    } catch {
    | e =>
      Js.Console.error(e)
      invalidAlert()
    }

  let handleText = event => {
    ReactEvent.Form.preventDefault(event)
    loadJson(text)
  }

  let handleFile = event => {
    module FileReader = Externals.FileReader
    ReactEvent.Form.preventDefault(event)
    let reader = FileReader.make()

    let onload = ev => {
      ignore(ev)
      let data = ev["target"]["result"]
      try {
        let {config, players, teams, tournaments} = data->Js.Json.parseExn->decodeOptions
        loadData(~tournaments, ~players, ~teams, ~config)
      } catch {
      | e =>
        Js.Console.error(e)
        invalidAlert()
      }
    }
    FileReader.setOnLoad(reader, onload)
    FileReader.readAsText(
      reader,
      ReactEvent.Form.currentTarget(event)["files"]->Array.get(0)->Option.getWithDefault(""),
    )
    /* so the filename won't linger onscreen */
    ReactEvent.Form.currentTarget(event)->Object.set("value", "")
  }

  let handleTextChange = event => {
    let newText = ReactEvent.Form.currentTarget(event)["value"]
    setText(_ => newText)
  }

  <Window.Body windowDispatch>
    <div className="content-area">
      <h2> {React.string("数据管理")} </h2>
      <p className="caption-20">
        {React.string("上次导出：")}
        <LastBackupDate date=config.lastBackup />
      </p>
      <GistOpts configDispatch exportData loadJson />
      <h3> {"本地备份"->React.string} </h3>
      <p>
        <a
          download={"guandan-" ++ (getDateForFile() ++ ".json")}
          href={"data:application/json," ++ exportDataURI}
          onClick={_ => configDispatch(SetLastBackup(Js.Date.make()))}>
          <Icons.Download />
          {React.string(" 导出数据到文件。")}
        </a>
      </p>
      <label htmlFor="file"> {React.string("从文件加载数据：")} </label>
      <input id="file" name="file" type_="file" onChange=handleFile />
      <h2> {React.string("高级：手动编辑数据")} </h2>
      <form onSubmit=handleText>
        <textarea
          className="pages__text-json"
          cols=50
          name="playerdata"
          rows=25
          spellCheck=false
          value=text
          onChange=handleTextChange
        />
        <p>
          <input type_="submit" value="加载" />
        </p>
      </form>
    </div>
  </Window.Body>
}
