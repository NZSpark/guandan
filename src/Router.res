/*
  Copyright (c) 2022 John Jackson.
  Modified for 掼蛋 tournament management.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/
let str = Data.Id.toString

type t =
  | Index
  | TournamentList
  | Tournament(Data.Id.t)
  | Players
  | Options
  | NotFound

let id = Data.Id.fromString

/** 将 hash 字符串（不含#）解析为路径 segment 列表。
    例如 "/tourneys/abc" → list{"tourneys", "abc"} */
let parseHash = hash => {
  let rec arrayToList = (arr, i, acc) =>
    if i < 0 {
      acc
    } else {
      let seg = Js.Array2.unsafe_get(arr, i)
      if seg == "" {
        arrayToList(arr, i - 1, acc)
      } else {
        arrayToList(arr, i - 1, list{seg, ...acc})
      }
    }
  let parts = hash->Js.String2.split("/")
  arrayToList(parts, Js.Array2.length(parts) - 1, list{})
}

let fromPath = hash => {
  switch parseHash(hash) {
  | list{} => Index
  | list{"players"} => Players
  | list{"options"} => Options
  | list{"tourneys"} => TournamentList
  | list{"tourneys", x} => Tournament(id(x))
  | _ => NotFound
  }
}

let toString = x =>
  "#" ++ (switch x {
  | Index | NotFound => "/"
  | Players => "/players"
  | Options => "/options"
  | TournamentList => "/tourneys"
  | Tournament(id) => "/tourneys/" ++ str(id)
  })

let useUrl = () => {
  let {hash, _} = RescriptReactRouter.useUrl()
  fromPath(hash)
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
