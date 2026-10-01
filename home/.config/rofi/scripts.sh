#!/usr/bin/env bash
# =============================================================================
#  rofi/scripts.sh  --  Lanzadores del grimorio
#  Hyper + Super -> este script
#  El binario es `rofi-script`, no `rofi`.
# =============================================================================

# --- Aplicaciones ------------------------------------------------------------
case "$1" in
    apps)
        rofi-script -show drun -theme "$HOME/.config/rofi/theme.rasi" \
            -modi "drun,run" -show-icons -show-emoji
        ;;
    window)
        rofi-script -show window -theme "$HOME/.config/rofi/theme.rasi" \
            -show-icons -cycle
        ;;
    workspaces)
        rofi-script -modi "window,drun,srun,power" -show drun \
            -theme "$HOME/.config/rofi/theme.rasi" -show-icons
        ;;
    powermenu)
        rofi-script -modi "power:suspend,power:off,power:reboot,power:logoff" \
            -show power -theme "$HOME/.config/rofi/theme.rasi" \
            -separator " " -i -no-custom
        ;;
    calculator)
        rofi-script -modi "calc" -show drun -no-dmenu -i \
            -theme "$HOME/.config/rofi/theme.rasi"
        ;;
    *)
        rofi-script -show drun -theme "$HOME/.config/rofi/theme.rasi" -show-icons
        ;;
esac
