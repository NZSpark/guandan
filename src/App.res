/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/
@react.component
let make = () => {
  let url = Router.useUrl()
  <Window className="app">
    {windowDispatch =>
      <main className="app__main">
        {switch url {
        | Index =>
          <Window.Body windowDispatch>
            <Pages.Splash />
          </Window.Body>
        | TournamentList => <PageTournamentList windowDispatch />
        | Tournament(id) =>
          <Window.Body windowDispatch>
            <PageTourney tourneyId=id windowDispatch />
          </Window.Body>
        | Players => <PagePlayers windowDispatch />
        | Options => <PageOptions windowDispatch />
        | NotFound =>
          <Window.Body windowDispatch>
            <Pages.NotFound />
          </Window.Body>
        }}
      </main>}
  </Window>
}

Db.init()
