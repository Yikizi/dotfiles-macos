
export def abbr [content: string position: int] {
  commandline edit $content
  commandline set-cursor $position
}
