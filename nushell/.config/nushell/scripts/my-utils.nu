# NOTE: put this script in your nushell modules folder
# for me its ~/.config/nushell/scripts/
# then it can be called via `use my-utils *`
export def fzf-launch [data: string, cmd: string = "fzf.sh"] {
  let tmpfile = (mktemp -t)
  $data | save -f $tmpfile
  alacritty -T fzf-launcher -e tmux -c $"cat ($tmpfile) | ($cmd)" out+err> /dev/null
  rm $tmpfile
  return (open --raw /tmp/fzf.status)
}
