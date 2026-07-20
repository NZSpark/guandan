/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/
module Splash: {
  @react.component
  let make: unit => React.element
}

module TimeCalculator: {
  let title: string

  @react.component
  let make: unit => React.element
}

module NotFound: {
  @react.component
  let make: unit => React.element
}

module Page: {
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

let goToPage: ((Page.t => Page.t) => unit, Page.t) => unit
