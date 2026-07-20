/*
  Copyright (c) 2022 John Jackson.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/
open Vitest
open JestDom
open ReactTestingLibrary

/* Date rendering depends on the system locale/timezone in JSDOM.
   Test that the time element renders with the correct datetime attribute. */
let date = Js.Date.fromString("2000-01-01T12:00:00.000Z")

/* Small inline external to query a time element from a container */
@send external querySelector: (Dom.element, string) => Js.Null.t<Dom.element> = "querySelector"

let getTimeElement = container => {
  let el = container->querySelector("time")
  switch el->Js.Null.toOption {
  | None => assert(false)
  | Some(el) => el
  }
}

test("Date format component works", t => {
  let page = render(<Utils.DateFormat date />)
  let timeEl = getTimeElement(page->container)
  t->expect(timeEl)->toHaveAttribute("datetime", "2000-01-01T12:00:00.000Z")
})

test("Date + time format component works", t => {
  let page = render(<Utils.DateTimeFormat date timeZone="America/New_York" />)
  let timeEl = getTimeElement(page->container)
  t->expect(timeEl)->toHaveAttribute("datetime", "2000-01-01T12:00:00.000Z")
})
