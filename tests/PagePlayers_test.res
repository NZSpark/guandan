/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/
open Vitest
open JestDom
open ReactTestingLibrary

open! Belt

module TestPlayersPage = {
  @react.component
  let make = () => {
    let {Db.items: _, loaded, _} = Db.useAllPlayers()
    let {Db.items: _, loaded: teamsLoaded, _} = Db.useAllTeams()
    if loaded && teamsLoaded {
      <PagePlayers windowDispatch={_ => ()} />
    } else {
      <div> {React.string("加载中...")} </div>
    }
  }
}

let renderAsync = async x => {
  let page = render(x)
  await waitForElementToBeRemoved(() => page->queryByText(#Str("加载中...")))
  page
}

describe("The players page renders", () => {
  testAsync("Page renders without error", async _t => {
    let _page = await renderAsync(<TestPlayersPage />)
    ()
  })
})
