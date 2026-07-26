/*
  Breadcrumb navigation for tournament pages.
*/
open Router

type crumb = {
  label: string,
  to_: t,
}

@react.component
let make = (~items: array<crumb>) => {
  let n = Array.length(items)
  <nav ariaLabel="面包屑导航" className="breadcrumbs">
    {items->Array.mapWithIndex((item, i) => {
      let isLast = i == n - 1
      <>
        {if isLast {
          <span key={Int.toString(i)} className="breadcrumbs-current body-20">
            {React.string(item.label)}
          </span>
        } else {
          <Link key={Int.toString(i)} to_={item.to_}>
            {React.string(item.label)}
          </Link>
        }}
        {if !isLast {
          <span key={"sep-" ++ Int.toString(i)} className="breadcrumbs-sep">
            {React.string(" / ")}
          </span>
        } else {
          React.null
        }}
      </>
    })->React.array}
  </nav>
}
