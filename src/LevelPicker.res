/*
  Visual poker level picker — 2 through A as pill buttons.
  More intuitive than a dropdown for selecting guandan levels.
*/

@react.component
let make = (
  ~value: Data_Level.t,
  ~onChange: Data_Level.t => unit,
  ~label: string="级数",
  ~disabled: bool=false,
) => {
  let levels = Data_Level.all

  <div className="level-picker">
    <span className="level-picker-label"> {React.string(label)} </span>
    <div className="level-picker-pills">
      {levels->Array.map(l => {
        let isSelected = Data_Level.toInt(l) == Data_Level.toInt(value)
        let levelStr = Data_Level.toString(l)
        <button
          key={levelStr}
          type_="button"
          className={"level-pill" ++ (isSelected ? " level-pill-selected" : "")}
          onClick={_ => if !disabled { onChange(l) }}
          disabled=disabled
          title={"级数 " ++ levelStr}>
          {React.string(levelStr)}
        </button>
      })->React.array}
    </div>
  </div>
}
