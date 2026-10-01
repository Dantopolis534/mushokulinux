# =============================================================================
#  cyberArch-Dotfiles :: Mushoku Tensei
#  .zshrc
# =============================================================================

# Solo para shells interactivos
[[ -o interactive ]] || return

# --- Opciones ---------------------------------------------------------------
setopt AUTO_CD
setopt APPEND_HISTORY
setopt EXTENDED_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt INTERACTIVE_COMMENTS
setopt NO_GLOBAL_EXPORT
setopt SHARE_HISTORY
setopt PROMPT_SUBST
setopt COMPLETE_IN_WORD
setopt ALWAYS_TO_END
setopt PUSHD_IGNORE_DUPS

HISTSIZE=100000
HISTFILESIZE=200000

# --- Completion -------------------------------------------------------------
autoload -Uz compinit
autoload -Uz bashcompinit
compinit -d "$XDG_CACHE_HOME/zsh/zcompdump"
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' use-cache on

# --- Rutas ------------------------------------------------------------------
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"
export EDITOR=nvim
export VISUAL=nvim
export PAGER=less
export LESS='-R'
export MANPAGER='less -R -X -F'

# --- Tema -------------------------------------------------------------------
export XC_THEME="mushoku-tensei"
export MT_PERSONAJE="${MT_PERSONAJE:-rudeus}"

# --- Prompt y librerias -----------------------------------------------------
[[ -r ~/.config/shell/aliases.sh        ]] && source ~/.config/shell/aliases.sh
[[ -r ~/.config/shell/mushoku-prompt.sh ]] && source ~/.config/shell/mushoku-prompt.sh
[[ -r ~/.config/shell/functions.sh      ]] && source ~/.config/shell/functions.sh

# --- fzf --------------------------------------------------------------------
if command -v fzf >/dev/null 2>&1; then
    source <(fzf --zsh)
    export FZF_DEFAULT_OPTS="
      --height=60%
      --layout=reverse
      --border=rounded
      --border-label=' Busca en el destino '
      --color=border:#5BC8FF,label:#080A12,label-bg:#5BC8FF
      --color=bg+:#121729,bg:#0B0E1A,preview-bg:#1B2340,preview-border:#9B7BD4
      --color=fg+:#ECEFF8,fg:#8E9AB8,header-bg:#26304F,header-fg:#E0B354
      --color=info:#9B7BD4,prompt:#5BC8FF,pointer:#E0B354,marker:#5FD98A
      --prompt=' Magia > '
    "
fi

# --- Título de ventana dinámico (Mushoku) ------------------------------------
case $TERM in
    xterm*|rxvt*|st*|alacritty*|foot*)
        precmd() { print -Pn '\e]0;%~  |  $USER@%m\a' }
        ;;
esac
