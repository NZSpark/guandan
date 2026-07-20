/*
  掼蛋级数体系：2,3,4,5,6,7,8,9,10,J,Q,K,A（共13级）
  2不必打，A必打。过A为最终胜利。
  数值映射: 2=2, 3=3, ..., 10=10, J=11, Q=12, K=13, A=14
*/
open! Belt

type t = Two | Three | Four | Five | Six
        | Seven | Eight | Nine | Ten
        | Jack | Queen | King | Ace

let toInt = x =>
  switch x {
  | Two => 2 | Three => 3 | Four => 4 | Five => 5
  | Six => 6 | Seven => 7 | Eight => 8 | Nine => 9
  | Ten => 10 | Jack => 11 | Queen => 12 | King => 13 | Ace => 14
  }

let fromInt = x =>
  switch x {
  | 2 => Two | 3 => Three | 4 => Four | 5 => Five
  | 6 => Six | 7 => Seven | 8 => Eight | 9 => Nine
  | 10 => Ten | 11 => Jack | 12 => Queen | 13 => King
  | 14 | _ => Ace
  }

let toString = x =>
  switch x {
  | Two => "2" | Three => "3" | Four => "4" | Five => "5"
  | Six => "6" | Seven => "7" | Eight => "8" | Nine => "9"
  | Ten => "10" | Jack => "J" | Queen => "Q" | King => "K" | Ace => "A"
  }

let fromString = s =>
  switch s {
  | "2" => Two | "3" => Three | "4" => Four | "5" => Five
  | "6" => Six | "7" => Seven | "8" => Eight | "9" => Nine
  | "10" => Ten | "J" => Jack | "Q" => Queen | "K" => King | "A" => Ace
  | _ => Two
  }

let encode = x => x->toString->Js.Json.string

let decode = json => Js.Json.decodeString(json)->Option.getExn->fromString

let levelDiff = (a, b) => toInt(a) - toInt(b)

let absDiff = (a, b) => abs(levelDiff(a, b))

@warning("-4")
let isAce = x =>
  switch x {
  | Ace => true
  | _ => false
  }

let all = [Two, Three, Four, Five, Six, Seven, Eight, Nine, Ten, Jack, Queen, King, Ace]

let next = x =>
  switch x {
  | Two => Three | Three => Four | Four => Five | Five => Six
  | Six => Seven | Seven => Eight | Eight => Nine | Nine => Ten
  | Ten => Jack | Jack => Queen | Queen => King | King => Ace
  | Ace => Ace
  }

/**
 * 净积小分 = 己方级数 - 对方级数
 * 例：A队打K(13)，B队打8 → A净积小分=13-8=5
 */
let netSmallScore = (myLevel, opponentLevel) => toInt(myLevel) - toInt(opponentLevel)

/**
 * 累积小分 = (己方级数 - 2) + 过A加分
 * 2是起始级数基准，过A者另加1分
 * 例：A队打K(13) → 累积小分=13-2=11
 *     A队打过A(14) → 累积小分=14-2+1=13
 */
@warning("-4")
let cumulativeSmallScore = (level: t): int => {
  let base = toInt(level) - 2
  switch level {
  | Ace => base + 1
  | _ => base
  }
}
