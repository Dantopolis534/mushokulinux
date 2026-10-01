#!/usr/bin/env bash
# =============================================================================
#  cyberArch-Dotfiles :: Mushoku Tensei
#  install.sh  --  Instalador idempotente
#
#  Uso:
#      ./install.sh                 # instala todo
#      ./install.sh --dry-run       # muestra que haría, no toca nada
#      ./install.sh --no-paquetes   # solo enlaza dotfiles, no instala nada
#      ./install.sh --only-dotfiles
#      ./install.sh --ayuda
#
#  Diseñado para: Arch Linux sobre ASUS TUF Gaming F15 FX506HCB
#  Sesion Hyprland/Wayland en la iGPU Intel, RTX 3050 via PRIME para juegos.
# =============================================================================

set -uo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="$REPO_DIR/home"
THEMES="$REPO_DIR/themes/mushoku-tensei"
ASSETS="$REPO_DIR/assets"

# ---- Colores -----------------------------------------------------------------
R=$'\033[38;2;224;179;84m'   # Rudeus  - oro
C=$'\033[38;2;91;200;255m'   # Roxy    - azul
G=$'\033[38;2;95;217;138m'   # Sylphie - verde
E=$'\033[38;2;255;95;86m'     # Eris    - rojo
V=$'\033[38;2;155;123;212m'   # Hitogami- violeta
D=$'\033[38;2;142;154;184m'   # texto
N=$'\033[0m'

banner() {
    cat <<EOF

  ${R}_..-"""-.._${N}        ${V}MUSHOKU TENSEI${N}
 ${C}.'\`  .-~~~-.  '\`.${N}     cyberArch-Dotfiles
${C}/   /  o o  \\   \\${N}    "Quien guio mi destino fue
${C}|   |   >^<    |   |${N}    la confianza de alguien."
${C}\\   \\  '\`~~~\`  /   /${N}
 ${C}\`._ \`-.___.-' _'${N}    Destino reescrito con Arch Linux.

EOF
}

info()    { printf '%s[*]%s %s\n' "$C" "$N" "$*"; }
ok()      { printf '%s[+]%s %s\n' "$G" "$N" "$*"; }
aviso()   { printf '%s[!]%s %s\n' "$R" "$N" "$*"; }
error()   { printf '%s[x]%s %s\n' "$E" "$N" "$*" >&2; }
paso()    { printf '\n%s==>%s %s%s%s\n' "$V" "$N" "$C" "$*" "$N"; }

# ---- Opciones ----------------------------------------------------------------
DRY_RUN=0
SOLO_DOTFILES=0
NO_PAQUETES=0

parsear_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)       DRY_RUN=1 ;;
            --no-paquetes)   NO_PAQUETES=1 ;;
            --only-dotfiles) SOLO_DOTFILES=1; NO_PAQUETES=1 ;;
            --ayuda|-h|--help)
                sed -n '2,20p' "$0" | sed 's/^# \?//'
                exit 0 ;;
            *)
                error "Opción desconocida: $1"
                echo "Usa --ayuda para ver las opciones."
                exit 1 ;;
        esac
        shift
    done
}

ejecutar() {
    if (( DRY_RUN )); then
        printf '%s    [dry-run]%s %s\n' "$D" "$N" "$*"
        return 0
    fi
    "$@"
}

# ---- Comprobaciones ----------------------------------------------------------
comprobar_sistema() {
    paso "Comprobando el sistema"

    local distro
    distro=$(grep -oP '(?<=^NAME=).*' /etc/os-release 2>/dev/null | tr -d '"')

    if [[ "$distro" != "Arch Linux" && "$distro" != "Arch Linux ARM" ]]; then
        error "Este instalador esta pensado para Arch Linux (detectado: ${distro:-desconocido})"
        aviso "Continuando de todos modos. Las rutas de paquetes podrian fallar."
    else
        ok "Arch Linux detectado"
    fi

    if [[ "$(uname -m)" != "x86_64" ]]; then
        aviso "Arquitectura $(uname -m). Las notas de GPU asumen x86_64."
    fi
}

comprobar_dependencias() {
    paso "Comprobando herramientas"

    local faltan=()
    local cmd
    for cmd in bash mkdir cp ln rm find sed awk grep tar; do
        command -v "$cmd" >/dev/null 2>&1 || faltan+=("$cmd")
    done

    if (( ${#faltan[@]} > 0 )); then
        error "Faltan herramientas basicas: ${faltan[*]}"
        return 1
    fi
    ok "Herramientas basicas presentes"
}

comprobar_stow() {
    if command -v stow >/dev/null 2>&1; then
        ok "stow disponible"
        return 0
    fi
    aviso "stow no instalado. Se usara 'cp -r' como alternativa."
    return 1
}

# ---- Paquetes ----------------------------------------------------------------
instalar_paquetes() {
    (( NO_PAQUETES )) && { aviso "Instalacion de paquetes omitida (--no-paquetes)"; return 0; }

    paso "Instalando paquetes"

    localRepo() {
        info "paquete: $*"
        if (( DRY_RUN )); then return 0; fi
        # sudo -v para cachear credenciales una sola vez
        sudo pacman -S --needed --noconfirm "$@" 2>&1 | sed 's/^/    /'
    }

    # -- Base minima para el instalador
    localRepo stow

    # -- Fuentes
    if ! grep -q 'fzf' /etc/pacman.conf 2>/dev/null; then
        aviso "Los repos de abajo son opcionales. El script sigue sin ellos."
    fi

    # -- Sistema y kernel
    localRepo \
        linux-headers \
        intel-ucode \
        linux-firmware \
        efibootmgr

    # -- Boot (Secure Boot activo en esta laptop -> shim)
    localRepo \
        grub \
        shim \
        os-prober

    # -- GPU: Intel para la sesion, NVIDIA para juegos
    localRepo \
        mesa \
        libva-intel-driver \
        libva-mesa-driver \
        intel-media-driver \
        vulkan-intel \
        vulkan-radeon \
        nvidia-dkms \
        nvidia-utils \
        nvidia-settings \
        lib32-nvidia-utils \
        gstreamer-vaapi \
        gst-plugin-nvdec \
        switcheroo-control

    # -- Red (MediaTek MT7921)
    localRepo \
        networkmanager \
        iwd \
        wpa_supplicant \
        wireless_regdb \
        iw

    # -- Audio (Intel SST + Realtek)
    localRepo \
        pipewire \
        pipewire-jack \
        pipewire-alsa \
        wireplumber \
        alsa-firmware \
        alsa-utils \
        pavucontrol \
        playerctl \
        wireplumber-tui

    # -- ASUS TUF
    localRepo \
        asusctl \
        brightnessctl

    # -- Compositor y barra
    localRepo \
        hyprland \
        waybar \
        hyprpaper \
        hyprlock \
        hypridle \
        hyprcursor \
        xdg-desktop-portal-hyprland \
        wtype

    # -- Herramientas del escritorio
    localRepo \
        kitty \
        rofi \
        dunst \
        fzf \
        ripgrep \
        fd \
        bat \
        eza \
        zoxide \
        fzy \
        jq \
        yq \
        fastfetch \
        ttf-jetbrains-mono-nerd \
        noto-fonts-emoji \
        otf-noto-cjk \
        gnu-free-fonts \
        ttf-liberation

    # -- Capturas y portapapeles
    localRepo \
        grim \
        slurp \
        swappy \
        wl-clipboard

    # -- Escritorio
    localRepo \
        thunar \
        mousepad \
        gvfs \
        xdg-user-dirs \
        xdg-utils

    # -- Fuentes del sistema
    localRepo \
        lsd \
        btop \
        neofetch \
        smartmontools \
        lm_sensors \
        pciutils \
        usbutils

    # -- Extras utiles
    localRepo \
        man-db \
        man-pages \
        wget \
        curl \
        git \
        base-devel \
        vim \
        neovim \
        tmux \
        tree \
        htop

    # -- Herramientas de conversion SVG -> PNG
    localRepo librsvg

    ok "Paquetes procesados"
}

# ---- Enlazado de dotfiles ----------------------------------------------------
instalar_dotfiles() {
    paso "Enlazando dotfiles a \$HOME"

    if ! [[ -d "$DOTFILES" ]]; then
        error "No existe $DOTFILES"
        return 1
    fi

    local usar_stow=0
    command -v stow >/dev/null 2>&1 && usar_stow=1

    if (( usar_stow )); then
        info "Usando GNU Stow"
        # stow --dir=home --target=$HOME
        local destino="$HOME"
        local actual
        # Recorre home/ y hace stow de cada entrada
        actual="$(pwd)"
        cd "$DOTFILES" || return 1
        local item
        for item in .* *; do
            [[ "$item" == "." || "$item" == ".." ]] && continue
            [[ -e "$item" ]] || continue
            info "stow: $item"
            (( DRY_RUN )) || stow --dir="$DOTFILES" --target="$destino" "$item" 2>&1 | sed 's/^/    /'
        done
        cd "$actual" || return 1
    else
        aviso "stow ausente: copiando archivos (sin gestion de enlaces)"
        if (( ! DRY_RUN )); then
            cp -rv "$DOTFILES"/. "$HOME"/ 2>&1 | sed 's/^/    /'
        fi
    fi

    ok "Dotfiles enlazados"
}

# ---- Permisos de ejecutables -------------------------------------------------
ajustar_permisos() {
    paso "Ajustando permisos"

    if (( DRY_RUN )); then
        info "chmod +x en home/.local/bin/"
        return 0
    fi

    if [[ -d "$HOME/.local/bin" ]]; then
        find "$HOME/.local/bin" -type f -exec chmod +x {} + 2>/dev/null
        ok "Permisos de ~/.local/bin ajustados"
    fi

    for f in "$HOME/.config/rofi/scripts.sh" "$HOME/.config/shell"/*.sh; do
        [[ -f "$f" ]] && chmod +x "$f" 2>/dev/null
    done
}

# ---- Fondos ------------------------------------------------------------------
convertir_fondos() {
    paso "Preparando los fondos (Mushoku Tensei)"

    local destino="$HOME/.local/share/wallpapers/mushoku"

    if (( DRY_RUN )); then
        info "mkdir -p $destino"
        info "SVG -> PNG en $destino"
        info "copiar temas a ~/.config/waybar, ~/.config/hypr, ~/.config/dunst"
        return 0
    fi

    mkdir -p "$destino"

    local conversor=""
    if   command -v rsvg-convert >/dev/null 2>&1; then conversor="rsvg-convert"
    elif command -v magick     >/dev/null 2>&1; then conversor="magick"
    elif command -v convert    >/dev/null 2>&1; then conversor="convert"
    elif command -v inkscape   >/dev/null 2>&1; then conversor="inkscape"
    fi

    if [[ -z "$conversor" ]]; then
        aviso "No hay conversor SVG. Copiando los SVG tal cual."
        aviso "hyprpaper NO lee SVG: instala 'librsvg' y ejecuta de nuevo:"
        aviso "    sudo pacman -S librsvg && ~/.dotfiles/install.sh"
        cp -v "$ASSETS"/wallpapers/*.svg "$destino"/ 2>/dev/null
        return 1
    fi

    ok "Usando conversor: $conversor"

    local svg base salida
    for svg in "$ASSETS"/wallpapers/*.svg; do
        [[ -e "$svg" ]] || continue
        base="$(basename "${svg%.svg}")"
        salida="$destino/$base.png"

        case "$conversor" in
            rsvg-convert)
                rsvg-convert -w 1920 -h 1080 -o "$salida" "$svg" 2>/dev/null \
                    || rsvg-convert -o "$salida" "$svg" 2>/dev/null ;;
            magick)
                magick -background none -resize 1920x1080! "$svg" "$salida" ;;
            convert)
                convert -background none -resize 1920x1080! "$svg" "$salida" ;;
            inkscape)
                inkscape "$svg" --export-type=png --export-filename="$salida" \
                    --export-width=1920 2>/dev/null ;;
        esac

        if [[ -f "$salida" ]]; then
            ok "fondo: $base.png"
        else
            aviso "No se pudo convertir $base.svg"
        fi
    done

    # sello-orsted es cuadrado (512)
    if [[ -f "$ASSETS/wallpapers/sello-orsted.svg" ]]; then
        case "$conversor" in
            rsvg-convert) rsvg-convert -w 512 -h 512 -o "$destino/sello-orsted.png" \
                            "$ASSETS/wallpapers/sello-orsted.svg" 2>/dev/null ;;
            magick|convert) $conversor -background none -resize 512x512 \
                            "$ASSETS/wallpapers/sello-orsted.svg" "$destino/sello-orsted.png" ;;
            inkscape) inkscape "$ASSETS/wallpapers/sello-orsted.svg" --export-type=png \
                        --export-filename="$destino/sello-orsted.png" --export-width=512 ;;
        esac
        [[ -f "$destino/sello-orsted.png" ]] && ok "sello: sello-orsted.png"
    fi

    ok "Fondos listos en $destino"
}

# ---- Temas -------------------------------------------------------------------
instalar_temas() {
    paso "Instalando los temas"

    if (( DRY_RUN )); then
        info "copiar $THEMES/ -> destinos"
        return 0
    fi

    # Referencia canonica para consultar la paleta
    mkdir -p "$HOME/.config/cyberarch"
    cp -v "$THEMES/colors.json" "$HOME/.config/cyberarch/" 2>/dev/null
    cp -v "$THEMES/colors.css"  "$HOME/.config/cyberarch/" 2>/dev/null

    # Waybar usa sus propios @define-color, pero dejamos la copia por si
    # prefieres importar el CSS directamente.
    [[ -d "$HOME/.config/waybar" ]] && \
        cp -v "$THEMES/colors.css" "$HOME/.config/waybar/colors.css" 2>/dev/null

    # Hyprland (formato *.conf)
    [[ -d "$HOME/.config/hypr" ]] && \
        cp -v "$THEMES/colors.conf" "$HOME/.config/hypr/colors.conf" 2>/dev/null

    # rofi (formato *.rasi) -- dunst NO lee rasi, ver home/.config/dunst/dunstrc
    [[ -d "$HOME/.config/rofi" ]] && \
        cp -v "$THEMES/colors.rasi" "$HOME/.config/rofi/colors.rasi" 2>/dev/null

    ok "Temas instalados"
}

# ---- Fastfetch ----------------------------------------------------------------
configurar_fastfetch() {
    paso "Configurando fastfetch"

    if (( DRY_RUN )); then
        info "ln -sf mushoku.jsonc ~/.config/fastfetch/config.jsonc"
        return 0
    fi

    mkdir -p "$HOME/.config/fastfetch"
    if [[ ! -e "$HOME/.config/fastfetch/config.jsonc" ]]; then
        ln -sf "$HOME/.config/fastfetch/mushoku.jsonc" \
               "$HOME/.config/fastfetch/config.jsonc"
        ok "fastfetch usa el tema Mushoku Tensei"
    else
        aviso "~/.config/fastfetch/config.jsonc ya existe. No se toco."
        aviso "Para usarlo:  fastfetch --config ~/.config/fastfetch/mushoku.jsonc"
    fi
}

# ---- Fastfetch: logo original ------------------------------------------------
generar_logo_fastfetch() {
    local destino="$HOME/.config/fastfetch/rudeus.txt"

    if (( DRY_RUN )); then info "crear $destino"; return 0; fi
    [[ -f "$destino" ]] && { ok "Logo fastfetch ya existe"; return 0; }

    mkdir -p "$HOME/.config/fastfetch"
    cat > "$destino" <<'LOGO'
        ,---.
       (  o o )
       \  >^<  /       MUSHOKU TENSEI
      __| || |__       El hechicero de Fittoa
     /_.-'   '-._\
        | | |
LOGO
    ok "Logo fastfetch creado (rudeus.txt)"
}

# ---- Rutas del sistema -------------------------------------------------------
configurar_rutas() {
    paso "Creando directorios de trabajo"

    if (( DRY_RUN )); then
        info "mkdir -p capturas, documentos, proyectos, WALL"
        return 0
    fi

    mkdir -p "$HOME"/{capturas,documentos,proyectos,descargas,videos,música,imágenes}
    ok "Directorios creados"
}

# ---- Comprobaciones finales de la sesion -------------------------------------
verificar_sesion() {
    paso "Resumen de la sesion"

    local falta=()

    local c
    for c in hyprctl waybar hyprpaper rofi dunst kitty; do
        command -v "$c" >/dev/null 2>&1 || falta+=("$c")
    done

    if (( ${#falta[@]} == 0 )); then
        ok "Todos los componentes de la sesion estan instalados"
    else
        aviso "Faltan componentes: ${falta[*]}"
        aviso "Instala con:  sudo pacman -S ${falta[*]}"
    fi

    echo
    aviso "ULTIMO PASO MANUAL (no lo hace este script):"
    echo "  1) Anade una entrada de Hyprland al gestor de arranque de Windows:"
    echo "     bcdedit /enum firmware   (desde PowerShell como administrador)"
    echo "  2) O activa os-prober en GRUB y reinstala grub."
    echo "  3) Reinicia y elige 'Arch Linux' en el menu de arranque."
    echo
    aviso "Consulta docs/01-instalar-arch.md (arranque dual) y docs/02-postinstall.md."
}

# ---- Menu principal ----------------------------------------------------------
main() {
    parsear_args "$@"

    banner
    (( DRY_RUN )) && aviso "MODO SIMULACION: no se modificara nada.\n"

    comprobar_sistema
    comprobar_dependencias
    comprobar_stow

    (( SOLO_DOTFILES == 0 )) && instalar_paquetes

    instalar_dotfiles
    ajustar_permisos
    convertir_fondos
    instalar_temas
    configurar_fastfetch
    generar_logo_fastfetch
    configurar_rutas
    verificar_sesion

    echo
    ok "Instalacion completada."
    echo
    info "Personaje activo:  $(cat "$HOME/.config/shell/mushoku-personaje" 2>/dev/null || echo rudeus)"
    info "Cambiarlo:         mt_persona roxy|eris|sylphie|hitogami|lara"
    info "Fondos:            ~/.local/share/wallpapers/mushoku/"
    info "Paleta:            ~/.config/cyberarch/colors.json"
    echo
    info "Reinicia la sesion o ejecuta:  hyprctl reload"
    echo
}

main "$@"
