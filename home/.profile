# =============================================================================
#  cyberArch-Dotfiles :: Mushoku Tensei
#  .profile  --  Variables de sesion (login shell)
# =============================================================================

export XC_THEME="mushoku-tensei"

if [[ -d "$HOME/.local/share/fonts" ]]; then
    export XDG_DATA_DIRS="$HOME/.local/share/fonts:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
fi

export XDG_CACHE_HOME="$HOME/.cache"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/bin:$PATH"

# Tema oscuro por defecto en las apps Qt
export QT_QPA_PLATFORMTHEME=qt6ct
export QT_STYLE_OVERRIDE=kvantum

# Wayland por defecto
export SDL_VIDEO_MINIMIZE_ON_FOCUS_LOSS=0
export MOZ_ENABLE_WAYLAND=1
export QT_ENABLE_HIGHDPI_SCALING=1
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1

# No romper las apps que no saben usar Wayland
export QT_QPA_PLATFORMS=wayland;xcb

# fzf
if command -v fzf >/dev/null 2>&1 && [[ -r ~/.config/fzf/fzf.bash ]]; then
    source ~/.config/fzf/fzf.bash
fi

# Zoxide
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash)"
fi

if [[ -r ~/.bashrc ]]; then
    . ~/.bashrc
fi
