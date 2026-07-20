/*
  Copyright (c) 2022 John Jackson.
  CSV import for 掼蛋 tournament management.
*/

type row = {
  teamName: string,
  player1Name: string,
  player1Gender: string,
  player2Name: string,
  player2Gender: string,
  club: string,
  score: float,
}

let parse: string => array<row>

let importData: string => (Data_Id.Map.t<Data_Player.t>, Data_Id.Map.t<Data_Team.t>)
