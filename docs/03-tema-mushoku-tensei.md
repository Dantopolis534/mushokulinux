# 03 · El tema Mushoku Tensei

Como customize cada parte sin romper nada. La regla es simple:
**la paleta vive en un solo archivo** y el resto la consume.

---

## 3.1 · La fuente de verdad

```
themes/mushoku-tensei/colors.json     <- edita esto
```

De ahi se generan los demas formatos:

| Archivo | Consumido por |
|---|---|
| `colors.json` | referencia, `~/.config/cyberarch/colors.json` |
| `colors.conf` | Hyprland (`#RRGGBB` / `rgba()`) |
| `colors.css` | Waybar, apps GTK4 web |
| `colors.rasi` | dunst, rofi |

Los exportadores viven en `themes/export.py`. Despues de editar:

```bash
cd ~/.dotfiles/themes
python3 export.py
cd ~/.dotfiles && ./install.sh --no-paquetes
```

---

## 3.2 · Cambiar el personaje (lo mas comun)

```bash
mt_persona              # lista
mt_persona roxy         # aplica
```

Eso cambia:

- El acento de la ventana enfocada
- El color del workspace activo
- El rune del prompt
- El nombre en el prompt

Abre una shell nueva o `exec bash`.

### Que personaje va con que color

| Personaje | Color | Sensacion |
|---|---|---|
| `rudeus` | oro `#E0B354` | calido, magician, default |
| `roxy` | azul `#5BC8FF` | frio, agua, productivo |
| `eris` | rojo `#FF5F56` | intenso, ilegible si hay mucho rojo |
| `sylphie` | verde `#5FD98A` | naturaleza, tranquilo |
| `hitogami` | violeta `#9B7BD4` | mistico, oscuro |
| `lara` | violeta claro `#B47BD4` | suave |

### Cambiarlo permanentemente para una sesion

```bash
# ~/.config/hypr/hyprland.conf
$acento_principal  = #5BC8FF
$acento_secundario = #E0B354
```

Despues: `hyprctl reload`

---

## 3.3 · El prompt

### Cambiar el prompt

```bash
nano ~/.config/shell/mushoku-prompt.sh
```

La funcion `mt_rune` decide el simbolo:

```bash
mt_rune() {
    case "$(mt_personaje)" in
        roxy)     printf '%s' "◈" ;;   #circulo relleno
        eris)     printf '%s' "✦" ;;   # estrella de cuatro puntas
        sylphie)  printf '%s' "❈" ;;   # flor de ocho petalos
        hitogami) printf '%s' "✧" ;;   # estrella contour
        *)        printf '%s' "✧" ;;
    esac
}
```

Candidatos: `◆ ✦ ◈ ❈ ✧ ⚔ ✶ ✷ ☾ ⚘ ⚡ 🔮`

### Desactivar el banner de inicio

```bash
echo 'export MT_NO_BANNER=1' >> ~/.bashrc
```

### Cambiar de shell

```bash
sudo pacman -S zsh fish
chsh -l                 # o:  chsh -s /bin/zsh

# zsh ya esta configurado en .zshrc
# fish en ~/.config/fish/
```

---

## 3.4 · Waybar

### Editar la barra

```bash
nano ~/.config/waybar/config.jsonc
```

Requiere waybar 0.11 o superior por la sintaxis `fmt`. Para versiones viejas,
cambia `"format": "..."` por `"format"` + `"format-alt"`.

### Modulos que puedes quitar

Si quieres menos cosas en la barra, quita el modulo de `modules-right`:

```jsonc
"modules-right": [
    "network",
    "battery",
    "clock"
]
```

### Cambiar los iconos

Los iconos son glifos **Nerd Font**. Cambia el codepoint por el que quieras:

```jsonc
"format-icons": {
    "1": "󰲋",     // puedes poner "" y quedara solo el numero
    "2": "󰊢"
}
```

### Reordenar

```jsonc
"modules-left":   ["custom/sello", "hyprland/workspaces"],
"modules-center": ["hyprland/window"],
"modules-right":  ["network", "battery", "clock"]
```

---

## 3.5 · Fondos

### Anadir un fondo tuyo

```bash
cp tu_fondo.png ~/.local/share/wallpapers/mushoku/
hyprctl hyprpaper reload
```

Hyprpaper **no lee SVG**. Si tienes un SVG:

```bash
rsvg-convert -w 1920 -h 1080 -o salida.png entrada.svg
# o
magick -background none -resize 1920x1080! entrada.svg salida.png
```

### Rotar fondos

```bash
# Rotar cada 15 minutos
swww img cycle --time 900 ~/.local/share/wallpapers/mushoku/*

# Volver a hyprpaper
hyprctl hyprpaper reload
```

### Cambiar el fondo fijo por defecto

```bash
nano ~/.config/hypr/hyprpaper.conf
```

```ini
paper = ~/.local/share/wallpapers/mushoku/eris.png
```

Despues: `hyprctl reload`

### Los fondos incluidos

| Archivo | Paleta | Ambiente |
|---|---|---|
| `fittoa` | oro / azul / violeta | atardecer tranquilo |
| `roxy` | azul hielo | agua, foco |
| `eris` | rojo / dorado | fuego, intenso |
| `hitogami` | violeta / negro | oscuro, mistico |

Son obra original de este repo: sin material del anime, libres de usar.

---

## 3.6 · Ro-fi (lanzador)

```bash
nano ~/.config/rofi/theme.rasi
```

```rasi
* {
    roxy:     #5BC8FF;   /* acento */
    rudeus:   #E0B354;
    hitogami: #9B7BD4;
    selected: #26304F;   /* fondo de la fila elegida */
    radius:   12;        /* esquinas redondeadas */
}
```

Atajos utiles dentro de rofi:

```
Ctrl+Shift+Enter    hoja de calculadora
Alt+n               cambiar entre apps / ventanas
Ctrl+f, Alt+f       buscar en la lista completa
Alt+w               limpiar
Shift+Esc           matar la ventana elegida
Alt+Shift+Enter     ventana de terminal
```

---

## 3.7 · Dunst (notificaciones)

Dunst **no** usa archivos `.rasi` (eso es rofi). Los colores van dentro de
`dunstrc`, en formato `#RRGGBB`:

```bash
nano ~/.config/dunst/dunstrc
```

Los colores estan ya escritos; para cambiarlos:

```ini
[urgency_normal]
    background_color = "#121729"   ; Roxy / agua
    text_color       = "#ECEFF8"
    frame_color      = "#5BC8FF"

[urgency_critical]
    frame_color      = "#FF5F56"   ; Eris / fuego
```

Cambiar la posicion de las notificaciones:

```ini
[global]
    corner = top-right        # top-left, bottom-right, ...
    follow = mouse            # mouse o keyboard
    notification_timeout = 6
```

---

## 3.8 · Kitty (terminal)

```bash
nano ~/.config/kitty/kitty.conf
```

Cambiar la fuente:

```
font_family      JetBrainsMono Nerd Font
font_size        13.0
```

Fuentes Nerd Font disponibles en Arch:

```bash
sudo pacman -S \
    ttf-jetbrains-mono-nerd \
    ttf-meslo-nerd \
    otf-hack-nerd \
    otf-firacode-nerd \
    ttf-cascadia-code-nerd \
    otf-herculanum-nerd
```

Para ver todas:

```bash
pacman -Ss nerd-font
```

---

## 3.9 · Fastfetch

```bash
# Probar el tema
fastfetch --config ~/.config/fastfetch/mushoku.jsonc

# Dejarlo como default
ln -sf ~/.config/fastfetch/mushoku.jsonc ~/.config/fastfetch/config.jsonc
```

Personalizar los textos (que dicen "Continente", "Fortaleza", etc.):

```bash
nano ~/.config/fastfetch/mushoku.jsonc
```

Los campos clave son `"key"`. Cambia `"Runa"` por lo que quieras.

Cambiar los colores:

```jsonc
"console": {
    "key_prefix": "\033[38;2;91;200;255m  Magia \033[38;2;92;104;138m",
    "key_color": "cyan"
}
```

---

## 3.10 · Hyprlock

```bash
nano ~/.config/hypr/hyprlock.conf
```

El reloj, el nombre de usuario y los botones:

```ini
label {
    text = $USER
    color = 5bc8ffff
    font_size = 22
    position = 0, -20
}
```

Si el sello de Orsted no aparece, genera el PNG:

```bash
rsvg-convert -w 512 -h 512 \
  -o ~/.local/share/wallpapers/mushoku/sello-orsted.png \
  ~/.dotfiles/assets/wallpapers/sello-orsted.svg
```

---

## 3.11 · Apps GTK

```bash
nano ~/.config/gtk-4.0/gtk.css
nano ~/.config/gtk-4.0/settings.ini
```

Cambiar tema de icono:

```ini
gtk-icon-theme-name=Papirus-Dark     # oscuro
gtk-icon-theme-name=Papirus-Light    # claro
gtk-icon-theme-name=Bibata-Modern-Classic
```

Temas de icono disponibles:

```bash
pacman -Ss icon-theme
sudo pacman -S papirus papirus-icon-theme adwaita-icon-theme breeze-icon-theme
```

---

## 3.12 · Reconstruir la paleta completa

```bash
cd ~/.dotfiles/themes
python3 export.py           # regenera .conf, .css, .rasi
cd ..
./install.sh --no-paquetes
hyprctl reload
```

---

## 3.13 · Workflow recomendado

```
themes/mushoku-tensei/colors.json    <- edita UNA vez
        │
        ├─ export.py genera ─> colors.conf
        │                    -> colors.css
        │                    -> colors.rasi
        │
        ├─ install.sh los copia a:
        │     ~/.config/hypr/colors.conf
        │     ~/.config/waybar/colors.css
        │     ~/.config/dunst/colors.rasi
        │
        └─ hyprctl reload
```

Nunca edites los archivos generados directamente. Se pisan.
