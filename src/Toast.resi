type level = Success | Warning | Error | Info

type t = {
  visible: bool,
  level: level,
  message: string,
}

let initial: t

let useToast: unit => (t, (level, string) => unit, unit => unit)

let levelClass: level => string
let levelIcon: level => string

@react.component
let make: (~toast: t, ~onDismiss: unit => unit) => React.element
