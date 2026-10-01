# =============================================================================
#  cyberArch-Dotfiles :: Mushoku Tensei
#  .config/fish/conf.d/aliases.fish
# =============================================================================

# --- Archivos ---
alias ll   'eza -lah --icons --group-directories-first'
alias la   'eza -a --icons --group-directories-first'
alias lt   'eza -lah --icons --sort=modified'
alias ls   'eza --icons'
alias tree 'eza --tree --icons --level=2'
alias cat  'bat --paging=never --style=numbers,header'
alias du   'dust -d 1 -h'
alias df   'df -h'

# --- Busqueda ---
alias grep 'rg'
alias find 'fd'

# --- Git ---
alias g    'git'
alias gs   'git status -sb'
alias ga   'git add'
alias gc   'git commit -m'
alias gco  'git checkout'
alias gsw  'git switch'
alias gd   'git diff'
alias gl   'git pull --rebase'
alias gp   'git push'
alias glg  'git log --oneline --graph --decorate -20'

# --- Sistema ---
alias ports 'ss -tulpn'
alias cya   'pavucontrol'
alias screen  'grim -g (slurp) - | wl-copy'
alias screenf 'grim - | wl-copy'

# --- Contenedores ---
alias dp  'docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"'
alias dcu 'docker compose up -d'
alias dcd 'docker compose down'
alias k   'kubectl'

# --- PRIME (iGPU Intel para la sesion, RTX 3050 para juegos) ---
alias gpuinfo 'prime-run nvidia-smi'
alias vkcube  'vkcube --wayland 2>/dev/null; or glxgears'
