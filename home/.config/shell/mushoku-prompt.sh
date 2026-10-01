#!/usr/bin/env bash
# =============================================================================
#  cyberArch-Dotfiles :: Mushoku Tensei
#  shell/mushoku-prompt.sh
#  Libreria compartida por bash, zsh y (adaptada) fish.
#
#  Cambia tu "personaje" con:
#      export MT_PERSONAJE=roxy     # roxy|eris|sylphie|rudeus|hitogami|lara
#  o edita ~/.config/shell/mushoku-personaje
# =============================================================================

# --- Paleta ------------------------------------------------------------------
MT_ROXY='#5BC8FF'
MT_ERIS='#FF5F56'
MT_SYLPHIE='#5FD98A'
MT_RUDEUS='#E0B354'
MT_HITOGAMI='#9B7BD4'
MT_LARA='#B47BD4'
MT_FG='#C9D4E8'
MT_FG2='#8E9AB8'
MT_BG='#080A12'
MT_MAGIC=$'\033[38;2;91;200;255m'

if [[ -n "${ZSH_VERSION:-}" ]]; then
    _mt_reset='%{'"$MT_MAGIC"'%}'   # el %{...} le dice a zsh que no cuenta
    _mt_c()   { printf "%%{%s}" "$1"; }
else
    _mt_reset=''
    _mt_c()   { printf '%b' "$1"; }
fi

# --- Personaje activo --------------------------------------------------------
mt_personaje() {
    if [[ -r ~/.config/shell/mushoku-personaje ]]; then
        local p; p=$(tr -d '[:space:]' < ~/.config/shell/mushoku-personaje)
        printf '%s' "$p"; return
    fi
    printf '%s' "${MT_PERSONAJE:-rudeus}"
}

# Cada personaje trae: acento, acento 2, nombre, subtitulo y rune del prompt.
mt_avatar() {
    local p; p=$(mt_personaje)
    case "$p" in
        roxy)
            _mt_c "$MT_ROXY";     printf '%s' "ROXY";    ;;
        eris)
            _mt_c "$MT_ERIS";     printf '%s' "ERIS";    ;;
        sylphie)
            _mt_c "$MT_SYLPHIE";  printf '%s' "SYLPHIE"; ;;
        hitogami)
            _mt_c "$MT_HITOGAMI"; printf '%s' "HITOGAMI";;
        lara)
            _mt_c "$MT_LARA";     printf '%s' "LARA";    ;;
        *)
            _mt_c "$MT_RUDEUS";   printf '%s' "RUDEUS";  ;;
    esac
}

mt_sub() {
    local p; p=$(mt_personaje)
    case "$p" in
        roxy)     printf '%s' "Migrudia"    ;;
        eris)     printf '%s' "Boreas"      ;;
        sylphie)  printf '%s' "Fittoa"      ;;
        hitogami) printf '%s' "Laberinto"   ;;
        lara)     printf '%s' "Megmind"     ;;
        *)        printf '%s' "Greyrat"     ;;
    esac
}

# El rune del prompt: el "hechizo activo" de cada personaje
mt_rune() {
    local p; p=$(mt_personaje)
    case "$p" in
        roxy)     _mt_c "$MT_ROXY";     printf '%s' "◈" ;;   # agua
        eris)     _mt_c "$MT_ERIS";     printf '%s' "✦" ;;   # fuego
        sylphie)  _mt_c "$MT_SYLPHIE";  printf '%s' "❈" ;;   # viento
        hitogami) _mt_c "$MT_HITOGAMI"; printf '%s' "✧" ;;   # vacio
        lara)     _mt_c "$MT_LARA";     printf '%s' "❖" ;;   # violeta
        *)        _mt_c "$MT_RUDEUS";   printf '%s' "✧" ;;   # oro
    esac
}

# --- Contexto de git ---------------------------------------------------------
mt_git() {
    command -v git >/dev/null 2>&1 || return 0
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0

    local rama estado
    rama=$(git symbolic-ref --short HEAD 2>/dev/null) \
        || rama=$(git rev-parse --short HEAD 2>/dev/null) || return 0

    printf '%s' "$rama"

    local st
    st=$(git status --porcelain --untracked-files=no 2>/dev/null)
    [[ -n "$st" ]] || return 0

    local add mod del
    add=$(printf '%s' "$st" | grep -c '^ *A'   || true)
    mod=$(printf '%s' "$st" | grep -c '^ *M'   || true)
    del=$(printf '%s' "$st" | grep -c '^ *D'   || true)

    (( add > 0 )) && { _mt_c "$MT_SYLPHIE"; printf ' +%s' "$add"; }
    (( mod > 0 )) && { _mt_c "$MT_RUDEUS";  printf ' ~%s' "$mod"; }
    (( del > 0 )) && { _mt_c "$MT_ERIS";     printf ' -%s' "$del"; }
    return 0
}

# --- Prompt principal -------------------------------------------------------
mt_prompt() {
    local code=$?

    local rune acc
    rune=$(mt_rune)
    acc=$(mt_avatar)

    _mt_c "$MT_FG2"
    printf '\n '

    # rune del hechizo + usuario en acento
    printf '%s' "$rune"
    printf ' '
    _mt_c "$MT_ROXY"; printf '%s' "${USER}"
    _mt_c "$MT_FG2";  printf '@'
    _mt_c "$MT_ROXY"; printf '%s' "${HOSTNAME%%.*}"

    # cwd en dorado
    _mt_c "$MT_FG2";  printf '  '
    _mt_c "$MT_RUDEUS"; printf '%s' '~'
    _mt_c "$MT_RUDEUS"; printf '%s' "${PWD/#$HOME/~}"

    # git
    local g; g=$(mt_git)
    if [[ -n "$g" ]]; then
        printf '  '
        _mt_c "$MT_HITOGAMI"; printf 'git:'
        _mt_c "$MT_FG1";     printf '%s' "${g%% *}"
        _mt_c "$MT_FG2";     printf '%s' "${g#* }"
    fi

    printf '\n%s ' "$(printf '\033[38;2;91;200;255m╭▊%s' "$(mt_rune)")"
    return $code
}

PS1='$(mt_prompt)'
if [[ -n "${ZSH_VERSION:-}" ]]; then
    setopt PROMPT_SUBST
    PS1="$(mt_prompt)"
fi

# --- Aliases de la vida real -------------------------------------------------
alias ll='eza -lah --icons --group-directories-first'
alias la='eza -a --icons --group-directories-first'
alias l='eza -l --icons'
alias ls='eza --icons'
alias cat='bat --paging=never --style=numbers,header'
alias batcat='bat --paging=never'
alias grep='rg'
alias find='fd'
alias cd..='cd ..'
alias cd...='cd ../..'
alias ...='cd ../..'
alias g='git'
alias gs='git status -sb'
alias gc='git commit'
alias gco='git checkout'
alias gcm='git commit -m'
alias gp='git push'
alias gl='git pull'
alias t='tail -f'
alias h='history'
alias j='z'
alias ..='cd ..'
alias ...='cd ../..'

alias mpv='mpv --ytdl --hwdec=auto-safe'
alias rojo='   echo -e "\033[91m\033[1m"'
alias verde=' echo -e "\033[92m\033[1m"'
alias azul='  echo -e "\033[94m\033[1m"'
alias oro='   echo -e "\033[93m\033[1m"'
alias violeta='echo -e "\033[95m\033[1m"'
alias reset='echo -e "\033[0m"'

alias prime='prime-run'
alias gamescope-run='gamescope -f --expose-wayland -- %command%'

# --- Banner de inicio --------------------------------------------------------
mt_bienvenida() {
    [[ -n "${MT_NO_BANNER:-}" ]] && return 0
    [[ -t 1 ]] || return 0

    cat <<'EOF'

        _..-"""-.._                 M U S H O K U   T E N S E I
     .'`  .-~~~-.  `'.              cyberArch-Dotfiles
    /   /  o o  \   \             "Quien guio mi destino
   |   |   >^<    |   |              fue la confianza de alguien."
    \   \  `~~~  /   /            Destino reescrito con Arch Linux.
     `._ `-.___.-' _'                       F I T T O A
         '-._.-'

EOF
}
