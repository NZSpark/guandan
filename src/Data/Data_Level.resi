/** 掼蛋级数体系。数值映射: 2=2, 3=3, ..., 10=10, J=11, Q=12, K=13, A=14 */
type t =
  | Two | Three | Four | Five | Six
  | Seven | Eight | Nine | Ten
  | Jack | Queen | King | Ace

let toInt: t => int
let fromInt: int => t
let toString: t => string
let fromString: string => t

let encode: t => Js.Json.t
let decode: Js.Json.t => t

/** 级差 = a级数 - b级数 */
let levelDiff: (t, t) => int

/** 级差绝对值 */
let absDiff: (t, t) => int

/** 是否为A（过A判定） */
let isAce: t => bool

/** 所有级数列表 */
let all: array<t>

/** 下一级 */
let next: t => t

/** 单场净积小分 */
let netSmallScore: (t, t) => int

/** 单场累积小分 */
let cumulativeSmallScore: t => int
