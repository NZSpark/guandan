type t = {
  id: Data_Id.t,
  name: string,
  player1Id: Data_Id.t,
  player2Id: Data_Id.t,
  isBye: bool,
  club: string,
  initialScore: float,
}

let fullName: t => string
let compareName: (t, t) => int

/** 轮空队伍常量 */
let bye: t

let encode: t => Js.Json.t
let decode: Js.Json.t => t

/** 获取队伍中两名选手的ID列表 */
let getPlayerIds: t => array<Data_Id.t>
