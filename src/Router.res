/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/
open! Belt
let str = Data.Id.toString

type t =
  | Index
  | TournamentList
  | Tournament(Data.Id.t)
  | Players
  | Options
  | NotFound

let id = Data.Id.fromString

let fromPath = x =>
  /* The first item is always an empty string */
  switch x {
  | list{} => Index
  | list{"players"} => Players
  | list{"options"} => Options
  | list{"tourneys"} => TournamentList
  | list{"tourneys", x} => Tournament(id(x))
  | _ => NotFound
  }

let toString = x =>
  switch x {
  | Index | NotFound => "/"
  | Players => "/players"
  | Options => "/options"
  | TournamentList => "/tourneys"
  | Tournament(id) => "/tourneys/" ++ str(id)
  }

let useUrl = () => {
  let {path, _} = RescriptReactRouter.useUrl()
  fromPath(path)
}

module Link = {
  @react.component
  let make = (~children, ~to_, ~onDragStart=?, ~onClick=?) => {
    let path = useUrl()
    let href = toString(to_)
    React.cloneElement(
      <a
        href
        ?onDragStart
        onClick={event => {
          switch onClick {
          | None => ()
          | Some(f) => f(event)
          }
          if !ReactEvent.Mouse.defaultPrevented(event) {
            ReactEvent.Mouse.preventDefault(event)
            RescriptReactRouter.push(href)
          }
        }}>
        children
      </a>,
      {"aria-current": href == toString(path)},
    )
  }
}
