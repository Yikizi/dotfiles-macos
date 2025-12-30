source $HOME/.zprofile
source $HOME/.env

zmodload zsh/complist
autoload -U compinit && compinit
autoload edit-command-line; zle -N edit-command-line

export GOPATH=$HOME/go
export PATH=$GOPATH/bin:$PATH
export PATH=$HOME/.local/bin:$PATH
export JAVA_HOME='/opt/homebrew/opt/openjdk@23/'

# export PROMPT=" %U%h%u %(?.%F{green}%?%f.%F{red}%?%f) %F{blue}%n@%m%f %B%~%b %F{yellow}%D{%b%e %a} %T%f %F{#008000}$>%f "

eval "$(/opt/homebrew/bin/brew shellenv)"

# history improvements
setopt append_history inc_append_history share_history hist_ignore_space hist_ignore_all_dups hist_save_no_dups hist_ignore_dups # better history
# setopt auto_menu menu_complete
setopt auto_pushd
setopt multios
setopt pushd_ignore_dups
setopt autocd
setopt no_case_glob no_case_match
setopt globdots
setopt extended_glob
setopt interactive_comments
unsetopt prompt_sp
stty stop undef

HISTSIZE=1000000
SAVEHIST=1000000
HISTCONTROL=ignoreboth
HISTDUP=erase

source <(fzf --zsh)

function append_pipe() {
  BUFFER="${BUFFER} | "
  CURSOR=${#BUFFER}
}
zle -N append_pipe
bindkey '^P' append_pipe

function command_not_found_handler {
  # Skip in non-interactive shells (fixes Claude Code spurious triggers)
  [[ ! -o interactive ]] && return 127

  echo "Did you mean any of these?"
  brew search "$1" 2>/dev/null
  return 127
}

function dstack() {
  dirs -v
  echo "Where do you want to go?"
  read num
  [[ -n "$num" ]] && cd +$num
}
alias ds=dstack

function cdmenu() {
    select dir in $(dirs -lp); do
        [[ -n "$dir" ]] && cd "$dir" && break
    done
}

# binds
bindkey -v

function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"<$TTY
	IFS= read -r -d '' cwd < "$tmp"
	[ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
	rm -f -- "$tmp"
  # zle redisplay
}

source $HOME/.config/broot/launcher/bash/br

function brr() {
  br<$TTY
}

zle -N brr
bindkey "^f" brr
bindkey "^e" edit-command-line
bindkey "^k" kill-line

function set-alias {
  [[ $# -eq 2 ]] && echo "alias $1='$2'" >> $HOME/.alias
}

function mcd {
  mkdir -p $1 && cd $1
}

function _git-status-widget {
  zle push-input
  BUFFER="git status"
  zle accept-line
}
zle -N _git-status-widget
bindkey '^Xs' _git-status-widget

function _yank-line-clipboard {
  echo "$BUFFER" | pbcopy
}
zle -N _yank-line-clipboard
bindkey "^Xy" _yank-line-clipboard

source $HOME/.alias

### Added by Zinit's installer
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit

# Load a few important annexes, without Turbo
# (this is currently required for annexes)
zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

### End of Zinit's installer chunk
eval "$(fzf --zsh)"
zinit light Aloxaf/fzf-tab
zinit light zsh-users/zsh-autosuggestions
zinit light zdharma-continuum/fast-syntax-highlighting
zinit light zsh-users/zsh-completions

# snippets
zinit snippet OMZP::git

# disable sort when completing `git checkout`
zstyle ':completion:*:git-checkout:*' sort false
# set descriptions format to enable group support
# NOTE: don't use escape sequences (like '%F{red}%d%f') here, fzf-tab will ignore them
zstyle ':completion:*:descriptions' format '[%d]'
# set list-colors to enable filename colorizing
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
# force zsh not to show completion menu, which allows fzf-tab to capture the unambiguous prefix
zstyle ':completion:*' menu no
# preview directory's content with eza when completing cd
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
# custom fzf flags
# NOTE: fzf-tab does not follow FZF_DEFAULT_OPTS by default
zstyle ':fzf-tab:*' fzf-flags --color=fg:1,fg+:2 --bind=tab:accept
# To make fzf-tab follow FZF_DEFAULT_OPTS.
# NOTE: This may lead to unexpected behavior since some flags break this plugin. See Aloxaf/fzf-tab#455.
zstyle ':fzf-tab:*' use-fzf-default-opts yes
# switch group using `<` and `>`
zstyle ':fzf-tab:*' switch-group '<' '>'

(( ${+_comps} )) && _comps[zinit]=_zinit
zinit cdreplay -q

eval "$(zoxide init zsh)"
eval "$(starship init zsh)"

# Added by Windsurf
export PATH="$HOME/.codeium/windsurf/bin:$PATH"

# The next line updates PATH for the Google Cloud SDK.
if [ -f "$HOME/Downloads/google-cloud-sdk/path.zsh.inc" ]; then . "$HOME/Downloads/google-cloud-sdk/path.zsh.inc"; fi

# The next line enables shell command completion for gcloud.
if [ -f "$HOME/Downloads/google-cloud-sdk/completion.zsh.inc" ]; then . "$HOME/Downloads/google-cloud-sdk/completion.zsh.inc"; fi

[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"

# opencode
export PATH=$HOME/.opencode/bin:$PATH

source $HOME/.config/broot/launcher/bash/br

# alias claude="$HOME/.claude/local/claude"

# bit
case ":$PATH:" in
  *":$HOME/bin:"*) ;;
  *) export PATH="$PATH:$HOME/bin" ;;
esac
# bit end

# opencode
export PATH=$HOME/.opencode/bin:$PATH
export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
export ZEPHYR_TOOLCHAIN_PATH=/opt/homebrew

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

function new-kaver-hw () {
  glab repo create -s "icd0022-25f-$1"
  glab api -X POST "/projects/taltech%2Ficd0022-25f-$1/members" -f user_id=$GITLAB_USER_KAVER1 -f access_level=20
  glab api -X POST "/projects/taltech%2Ficd0022-25f-$1/members" -f user_id=$GITLAB_USER_KAVER2 -f access_level=20
  glab repo clone "icd0022-25f-$1" "taltech/icd0022-25f-$1"
  cp $HOME/readme-base.md "$HOME/taltech/icd0022-25f-$1/README.md"
  git -C "$HOME/taltech/icd0022-25f-$1" add -A
  git -C "$HOME/taltech/icd0022-25f-$1" commit -m "init with readme"
  git -C "$HOME/taltech/icd0022-25f-$1" push
}

export PATH=$PATH:/Users/mattias/.spicetify

function qp {
  claude --dangerously-skip-permissions --mcp-config $HOME/sheets-agent.json -p "$*" --append-system-prompt "$SHEET_ID_PYTHON is the google sheet id for MY python course point tracking table - use the sheet called PUNKTITABEL with properly formatted id inside quotes. You are a useful assistant who helps keep the table up to date by adding things that I tell you. $SHEET_ID_ATTENDANCE - this is the SHARED google sheet where to mark attendance, ONLY modify rows with my name $MY_FULL_NAME - row $MY_SHEET_ROW ONLY in sheet called Tundides käimine, always use the correct date and time. ONLY allowed to modify sheets PUNKTITABEL and Tundides käimine as necessary, one at a time. All times when I mentioned I helped somebody that goes into MY table in sheet PUNKTITABEL. NEVER overwrite a row that already contains data in my PUNKTITABEL, always add helping a student on the next empty row. Current empty row is $(cat $HOME/.helper_row). Update the file $HOME/.helper_row after adding a new entry."
}

function cdr {
  local dir=$(fd -d 5 ".git" | xargs -n1 dirname | fzf)
  [[ -n "$dir" ]] && cd "$dir"
}

export PATH=$HOME/.cargo/bin:$PATH

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
