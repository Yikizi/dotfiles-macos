source $HOME/.zprofile
source $HOME/.env

zmodload zsh/complist
autoload -U compinit && compinit
autoload edit-command-line; zle -N edit-command-line

export GOPATH=$HOME/go
export PATH=$GOPATH/bin:$PATH
export PATH=$HOME/.local/bin:$PATH
export JAVA_HOME='/opt/homebrew/opt/openjdk@23/'

eval "$(/opt/homebrew/bin/brew shellenv)"

# history improvements
setopt append_history inc_append_history share_history hist_ignore_space hist_ignore_all_dups hist_save_no_dups hist_ignore_dups # better history
# setopt auto_menu menu_complete
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

# fastfetch
# task

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
