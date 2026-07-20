/*
  Copyright (c) 2022 John Jackson.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/
open Vitest
open JestDom
open ReactTestingLibrary
open FireEvent

let renderAsync = async x => {
  let page = render(x)
  await waitForElementToBeRemoved(() => page->queryByText(#Str("尚未添加任何锦标赛。")))
  page
}

/* I think the Reach Dialog component may have a problem with this? */
testAsync("Creating a new tournament works", async t => {
  let page = await renderAsync(<PageTournamentList />)
  page->getByText(#RegExp(%re("/添加锦标赛/i")))->click
  page
  ->getByLabelText(#RegExp(%re("/名称:/i")))
  ->change({
    "target": {
      "value": "Deep 13 Open",
    },
  })
  page->getByText(#RegExp(%re("/^创建$/i")))->click
  t->expect(page->getByLabelText(#Str("删除 “Deep 13 Open”")))->toBeInTheDocument
})

testAsync("Deleting a tournament works", async t => {
  let page = await renderAsync(<PageTournamentList />)
  page->getByLabelText(#Str("删除 “Simple Pairing”"))->click
  t->expect(page->queryByText(#RegExp(%re("/simple pairing/"))))->Expect.toBeNull
})
