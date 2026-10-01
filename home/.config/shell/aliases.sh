# =============================================================================
#  cyberArch-Dotfiles :: Mushoku Tensei
#  shell/aliases.sh  --  Aliases compartidos entre bash y zsh
# =============================================================================

# --- Sistema de archivos -----------------------------------------------------
alias ll='eza -lah --icons --group-directories-first'
alias la='eza -a --icons --group-directories-first'
alias lt='eza -lah --icons --sort=modified'
alias ls='eza --icons'
alias l='eza -l --icons'
alias tree='eza --tree --icons --level=2'

alias cat='bat --paging=never --style=numbers,header'
alias batn='bat --paging=never --style=plain'
alias du='dust -d 1 -h'
alias df='df -h'
alias free='free -h'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- --='cd -'

# --- Búsqueda ---------------------------------------------------------------
alias grep='rg'
alias rgrep='rg -i'
alias find='fd'
alias fd='fd'
alias ff='rg --files-with-matches'
alias historyy='rg --hidden --no-ignore --glob '!.git' -n'

# --- Git --------------------------------------------------------------------
alias g='git'
alias gs='git status -sb'
alias ga='git add'
alias gaall='git add -A'
alias gc='git commit -m'
alias gco='git checkout'
alias gsw='git switch'
alias gcl='git clone'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git pull --rebase'
alias gp='git push'
alias glg='git log --oneline --graph --decorate -20'
alias gsta='git stash'
alias gstaa='git stash push -u -m "wip"'

# --- Red / procesos ----------------------------------------------------------
alias pingg='ping -c 5 1.1.1.1'
alias ports='ss -tulpn'
alias pgrepf='pgrep -af'
alias watchproc='watch -n1 "ps aux --sort=-%cpu | head -15"'
alias htop='btop'

# --- Paquetes / Arch --------------------------------------------------------
alias y='yay -Syu'          # si usas yay
alias paru='paru -Syu'       # si usas paru
alias pacmanlog='pamac-log'

# --- Multimedia -------------------------------------------------------------
alias mpv='mpv --ytdl --hwdec=auto-safe --fs'
alias yt='yt-dlp --no-playlist'
alias spotify='spotify-launcher'
alias cya='pavucontrol'
alias screen='grim -g "$(slurp)" - | wl-copy'
alias screenf='grim - | wl-copy'

# --- Contenedores -----------------------------------------------------------
alias dp='docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"'
alias dps='docker ps -a'
alias dc='docker compose'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias k='kubectl'
alias kgp='kubectl get pods -A'

# --- Colores rapidos ---------------------------------------------------------
alias rojo='   echo -e "\033[91;1m"'
alias verde='  echo -e "\033[92;1m"'
alias azul='   echo -e "\033[94;1m"'
alias oro='    echo -e "\033[93;1m"'
alias violeta='echo -e "\033[95;1m"'
alias reset='  echo -e "\033[0m"'

# --- NVIDIA / PRIME (Arch sobre iGPU + RTX 3050) ---------------------------
alias gpuinfo='prime-run nvidia-smi'
alias gpuon='prime-run glxinfo -B 2>/dev/null | head -20 || glxinfo -B | head -20'
alias vkcube='vkcube --wayland 2>/dev/null || glxgears'
