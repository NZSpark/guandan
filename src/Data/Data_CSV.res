/*
  Copyright (c) 2022 John Jackson.
  CSV import for 掼蛋 tournament management.

  Parses CSV format:
  队伍名称,队员1,性别,队员2,性别,所属俱乐部/社团,当前积分
*/
open! Belt
module Id = Data_Id

type row = {
  teamName: string,
  player1Name: string,
  player1Gender: string,
  player2Name: string,
  player2Gender: string,
  club: string,
  score: float,
}

/** Get a field at index, trimming whitespace. Returns "" if out of bounds. */
let getField = (parts: array<string>, i: int): string => {
  let val: option<string> = parts[i]
  switch val {
  | Some(s) => Js.String2.trim(s)
  | None => ""
  }
}

/** Parse a single CSV line. Returns None for empty/malformed lines. */
let parseLine = (line: string): option<row> => {
  let parts = Js.String2.split(line, ",")
  let len = Js.Array2.length(parts)
  if len >= 6 {
    let scoreStr = getField(parts, 6)
    let score = Belt.Float.fromString(scoreStr)->Belt.Option.getWithDefault(0.0)
    Some({
      teamName: getField(parts, 0),
      player1Name: getField(parts, 1),
      player1Gender: getField(parts, 2),
      player2Name: getField(parts, 3),
      player2Gender: getField(parts, 4),
      club: getField(parts, 5),
      score,
    })
  } else {
    None
  }
}

/** Parse CSV text. Skips BOM, header row, and empty lines. */
let parse = (text: string): array<row> => {
  /* Strip UTF-8 BOM */
  let cleaned = if Js.String2.startsWith(text, "\uFEFF") {
    Js.String2.sliceToEnd(text, ~from=1)
  } else {
    text
  }

  Js.String2.split(cleaned, "\n")
  ->Js.Array2.filter(line => {
    let trimmed = Js.String2.trim(line)
    trimmed != "" && !Js.String2.startsWith(trimmed, "队伍名称")
  })
  ->Js.Array2.map(parseLine)
  ->Array.keepMap(x => x)
}

/**
 * Import CSV text: generates Player and Team records.
 * For 掼蛋, players belong to teams; names are stored as fullName in firstName.
 * Returns (playerMap, teamMap) keyed by Id.t, ready to merge with existing data.
 */
let importData = (text: string): (Id.Map.t<Data_Player.t>, Id.Map.t<Data_Team.t>) => {
  let rows = parse(text)
  let mutablePlayers = ref(Map.make(~id=Id.id))
  let mutableTeams = ref(Map.make(~id=Id.id))

  Array.forEach(rows, row => {
    let p1: Data_Player.t = {
      id: Id.random(),
      firstName: row.player1Name,
      lastName: "",
      gender: row.player1Gender,
    }
    let p2: Data_Player.t = {
      id: Id.random(),
      firstName: row.player2Name,
      lastName: "",
      gender: row.player2Gender,
    }

    mutablePlayers := Map.set(mutablePlayers.contents, p1.id, p1)
    mutablePlayers := Map.set(mutablePlayers.contents, p2.id, p2)

    let team: Data_Team.t = {
      id: Id.random(),
      name: row.teamName,
      player1Id: p1.id,
      player2Id: p2.id,
      isBye: false,
      club: row.club,
      initialScore: row.score,
    }
    mutableTeams := Map.set(mutableTeams.contents, team.id, team)
  })

  (mutablePlayers.contents, mutableTeams.contents)
}
