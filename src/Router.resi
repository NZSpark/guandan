/*
  Copyright (c) 2021 John Jackson. 
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/
type t =
  | Index
  | TournamentList
  | Tournament(Data.Id.t)
  | Players
  | Options
  | NotFound

let useUrl: unit => t

module Link: {
  @react.component
  let make: (
    ~children: React.element,
    ~to_: t,
    ~onDragStart: ReactEvent.Mouse.t => unit=?,
    ~onClick: ReactEvent.Mouse.t => unit=?,
  ) => React.element
}
