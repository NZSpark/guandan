type icon = Clipboard | Users | Trophy | Settings | Alert | Calendar

@react.component
let make: (~icon: icon=?, ~title: string, ~description: string=?) => React.element
