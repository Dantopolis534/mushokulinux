#!/usr/bin/env bash
# =============================================================================
#  cyberArch-Dotfiles :: Mushoku Tensei
#  shell/functions.sh -- Utilidades del sistema
# =============================================================================

# --- Cambio de personaje -----------------------------------------------------
# usage: mt_persona roxy | eris | sylphie | rudeus | hitogami | lara
mt_persona() {
    local p="${1:-}"
    local validos=(roxy eris sylphie rudeus hitogami lara)

    if [[ -z "$p" ]]; then
        echo "Personajes disponibles:"
        printf '  %-10s %s\n' "${validos[@]}"
        echo
        echo "  actual: $(cat ~/.config/shell/mushoku-personaje 2>/dev/null || echo rudeus)"
        return 0
    fi

    local v
    for v in "${validos[@]}"; do
        if [[ "$p" == "$v" ]]; then
            echo "$v" > ~/.config/shell/mushoku-personaje
            export MT_PERSONAJE="$v"
            printf '\033[%dm%s\033[0m  -> %s elegido. Recarga la shell para verlo.\n' \
                5 "$v" "$(tr '[:lower:]' '[:upper:]' <<< "$v")"
            return 0
        fi
    done

    echo "Personaje invalido: $p"
    printf '  Opciones: %s\n' "${validos[*]}"
    return 1
}

# --- Fondo aleatorio del laberinto ------------------------------------------
mt_fondo() {
    local dir="${1:-$HOME/.local/share/wallpapers/mushoku}"
    local img
    img=$(find "$dir" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.webp' \) 2>/dev/null | shuf -n1)
    if [[ -z "$img" ]]; then
        echo "No hay fondos en $dir"
        return 1
    fi
    hyprctl hyprpaper wallpaper ",\"$img\"" >/dev/null 2>&1 \
        && notify-send "Fondo" "$(basename "$img")" \
        || swaybg -i "$img"
}

# --- Rotar fondos cada N segundos -------------------------------------------
mt_rotar_fondos() {
    local intervalo="${1:-900}"
    while true; do
        mt_fondo
        sleep "$intervalo"
    done
}

# --- Diagnostico del sistema -------------------------------------------------
mt_diagnostico() {
    echo "=== Hardware ==="
    hostnamectl 2>/dev/null | sed 's/^/  /'

    echo
    echo "=== GPUs ==="
    lspci -k 2>/dev/null | grep -A3 -Ei 'VGA|3D|Display' | sed 's/^/  /'

    echo
    echo "=== Sesion grafica ==="
    echo "  compositor : ${XDG_CURRENT_DESKTOP:-?}"
    echo "  gpu sesion : $(lspci -k | grep -A1 'VGA compatible' | grep driver)"
    command -v nvidia-smi >/dev/null 2>&1 && {
        echo "  nvidia     : $(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null | head -1)"
    }

    echo
    echo "=== Red ==="
    ip -br a 2>/dev/null | sed 's/^/  /'
    rfkill list 2>/dev/null | sed 's/^/  /'

    echo
    echo "=== Audio ==="
    wpctl status 2>/dev/null | head -20 | sed 's/^/  /'

    echo
    echo "=== Almacenamiento ==="
    lsblk -f 2>/dev/null | sed 's/^/  /'
    df -h / /home 2>/dev/null | sed 's/^/  /'

    echo
    echo "=== Bateria / Temperatura ==="
    upower -i "$(upower -e 2>/dev/null | grep BAT | head -1)" 2>/dev/null | sed 's/^/  /'
    sensors 2>/dev/null | grep -E 'core|package' | head -5 | sed 's/^/  /'
}

# --- Buscar en el historial --------------------------------------------------
mt_historial() {
    local q="${1:-}"
    if [[ -n "$q" ]]; then
        history | grep -i -- "$q" | tail -20
    else
        history | tail -30
    fi
}

# --- Crear proyecto con estructura de dotfiles --------------------------------
mt_nuevo_dotfiles() {
    local dir="${1:-$HOME/dotfiles}"
    mkdir -p "$dir"/{assets,docs,home,themes,scripts}
    git -C "$dir" init -q 2>/dev/null
    echo "Creado: $dir"
    echo
    echo "Siguiente:"
    echo "  1. Copia tus configs actuales a  $dir/home/"
    echo "  2. git -C $dir add . && git -C $dir commit -m 'primer commit'"
    echo "  3. git clone https://github.com/TUUSU/cyberArch-Dotfiles \$HOME/.dotfiles"
    echo "  4. cd \$HOME/.dotfiles && ./install.sh"
}

# --- Limpieza rapida ---------------------------------------------------------
mt_limpiar() {
    echo "Limpiando cachés de paquetes..."
    sudo pacman -Sc --noconfirm
    echo "Limpiando cache de usr..."
    sudo paccache -rk2 2>/dev/null || sudo pacman -Sc --noconfirm
    echo "Limpiando logs..."
    sudo journalctl --vacuum-time=2weeks 2>/dev/null
    echo "Limpiando /tmp..."
    sudo rm -rf /tmp/* 2>/dev/null
    echo "Listo. Revisa el espacio con:  df -h"
}

# --- Reiniciar servicios de la sesion ----------------------------------------
mt_reiniciar() {
    command -v "$1" >/dev/null 2>&1 || { echo "No existe: $1"; return 1; }
    pkill -x "$1"
    sleep 1
    "$1" >/dev/null 2>&1 &
    echo "$1 reiniciado"
}
