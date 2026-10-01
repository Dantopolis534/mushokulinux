# =============================================================================
#  cyberArch-Dotfiles :: Mushoku Tensei
#  .bashrc
# =============================================================================

# Solo para shells interactivos
[[ $- != *i* ]] && return

export HISTCONTROL=ignoreboth:erasedups
export HISTSIZE=100000
export HISTFILESIZE=200000
export HISTIGNORE='ls:ll:la:cd:clear:pwd:exit:h:* --help'

shopt -s histappend
shopt -s checkwinsize
shopt -s autocd
shopt -s cdspell
shopt -s dirspell
shopt -s globstar
shopt -s nocaseglob
shopt -s cmdhist
shopt -s lithist

# --- Rutas ------------------------------------------------------------------
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/.npm-global/bin:$PATH"
export EDITOR=nvim
export VISUAL=nvim
export PAGER=less

# --- Variables del tema ------------------------------------------------------
export XC_THEME="mushoku-tensei"
export MT_PERSONAJE="${MT_PERSONAJE:-rudeus}"

# --- Prompt y librerias ------------------------------------------------------
[[ -r ~/.config/shell/aliases.sh   ]] && source ~/.config/shell/aliases.sh
[[ -r ~/.config/shell/mushoku-prompt.sh ]] && source ~/.config/shell/mushoku-prompt.sh
[[ -r ~/.config/shell/functions.sh ]] && source ~/.config/shell/functions.sh

# --- Completado --------------------------------------------------------------
if command -v bash-completion >/dev/null 2>&1; then
    source /usr/share/bash-completion/bash_completion
fi
[[ -r ~/.local/share/bash-completion/completions/fzf ]] && \
    source ~/.local/share/bash-completion/completions/fzf
[[ -r ~/.config/fzf/fzf.bash ]] && source ~/.config/fzf/fzf.bash

# --- Colores en less / man --------------------------------------------------
export LESS='-R'
export MANPAGER='less -R -X -F'
export LESSHISTFILE='-'

# --- fzf con el tema del laberinto ------------------------------------------
if command -v fzf >/dev/null 2>&1; then
    export FZF_DEFAULT_OPTS="
      --height=60%
      --layout=reverse
      --border=rounded
      --border-label=' Busca en el destino '
      --color=border:#5BC8FF,label:#080A12,label-bg:#5BC8FF
      --color=bg+:#121729,bg:#0B0E1A,preview-bg:#1B2340,preview-border:#9B7BD4
      --color=fg+:#ECEFF8,fg:#8E9AB8,header-bg:#26304F,header-fg:#E0B354
      --color=info:#9B7BD4,prompt:#5BC8FF,pointer:#E0B354,marker:#5FD98A
      --color=spinner:#5FD98A,header:#E0B354,query:#ECEFF8
      --info=inline-right
      --prompt=' Magia > '
      --separator='│'
    "
    bind -M emacs-standard '"\C-t":fzf-file-widget' 2>/dev/null
fi

# --- Bienvenida --------------------------------------------------------------
command -v fastfetch >/dev/null 2>&1 && mt_bienvenida
