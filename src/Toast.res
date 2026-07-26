/*
  Toast notification system for 掼蛋 tournament management.
  Simple hook-based toast — each consuming page creates its own instance.

  Usage:
    let (toastState, showToast) = Toast.useToast()
    showToast(Toast.Success, "操作成功")
    // In JSX:
    <Toast.Container toast=toastState />
*/

type level = Success | Warning | Error | Info

type t = {
  visible: bool,
  level: level,
  message: string,
}

let initial = {visible: false, level: Info, message: ""}

let useToast = () => {
  let (toast, setToast) = React.useState(() => initial)
  let timerRef = React.useRef(None: option<Js.Global.timeoutId>)

  let show = (level: level, message: string) => {
    /* Clear any existing timer */
    switch timerRef.current {
    | Some(id) => Js.Global.clearTimeout(id)
    | None => ()
    }
    setToast(_ => {visible: true, level, message})
    let id = Js.Global.setTimeout(() => {
      setToast(_ => initial)
    }, 3000)
    timerRef.current = Some(id)
  }

  let dismiss = () => {
    switch timerRef.current {
    | Some(id) => Js.Global.clearTimeout(id)
    | None => ()
    }
    setToast(_ => initial)
  }

  (toast, show, dismiss)
}

let levelClass = level =>
  switch level {
  | Success => "toast-success"
  | Warning => "toast-warning"
  | Error => "toast-error"
  | Info => "toast-info"
  }

let levelIcon = level =>
  switch level {
  | Success => "✓"
  | Warning => "⚠"
  | Error => "✕"
  | Info => "ℹ"
  }

@react.component
let make = (~toast: t, ~onDismiss: unit => unit) =>
  if toast.visible {
    <div className={"toast-container"} role="status" ariaLive=#polite>
      <div className={"toast " ++ levelClass(toast.level)}>
        <span className="toast-icon"> {React.string(levelIcon(toast.level))} </span>
        <span className="toast-body"> {React.string(toast.message)} </span>
        <button className="toast-close" onClick={_ => onDismiss()} ariaLabel="关闭">
          {React.string("×")}
        </button>
      </div>
    </div>
  } else {
    React.null
  }
