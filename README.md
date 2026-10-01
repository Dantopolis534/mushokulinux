# cyberArch-Dotfiles :: Mushoku Tensei

> *"Quien guio mi destino fue la confianza de alguien."*
> — Rudeus Greyrat

Dotfiles para **Arch Linux** con **Hyprland** (Wayland), montados sobre una
paleta de colores y una estetica inspiradas en *Mushoku Tensei*.

Target: **ASUS TUF Gaming F15 FX506HCB** · i5-11400H · 24 GB · Intel UHD + RTX 3050
· MediaTek MT7921 · Dual boot con Windows 11.

---

## Que hay aqui

```
cyberArch-Dotfiles/
├── install.sh              Instalador idempotente (--dry-run, --only-dotfiles)
├── assets/
│   └── wallpapers/         Fondos SVG originales (se rasterizan a PNG)
├── docs/
│   ├── 00-preparar-windows.md      Backup, USB, verificar particiones
│   ├── 01-instalar-arch.md         Instalacion paso a paso en la FX506HCB
│   ├── 02-postinstall.md           GPU, wifi, audio, Secure Boot, autologin
│   ├── 03-tema-mushoku-tensei.md   Personalizar el tema
│   ├── 04-resolucion-problemas.md  Cuando algo se rompe
│   └── INSTALL-PRIMERA-VEZ.md      Guia autocontenida para instalar sin ayuda
├── HANDOFF.md              Contexto del proyecto para retomar en otra sesion
├── home/                   Lo que se enlaza a $HOME
│   ├── .bashrc .zshrc .profile
│   └── .config/
│       ├── hypr/           hyprland.conf + conf.d/ (7 modulos)
│       ├── waybar/         config.jsonc + style.css
│       ├── shell/          prompt, aliases y funciones
│       ├── rofi/ dunst/ kitty/ fastfetch/ gtk-3.0/ gtk-4.0/ fish/
│       └── starship/
├── scripts/
│   └── preparar-usb.ps1    Automatiza la preparacion desde Windows
└── themes/mushoku-tensei/
    ├── colors.json         FUENTE DE VERDAD de la paleta
    ├── colors.conf  colors.css  colors.rasi
    └── mushoku-tensei.txt Texto del lore para el manual de Hyprland
```

---

## Inicio rapido

Ya tenes Arch instalado:

Todavia no tienes el repo en GitHub, asi que copialo donde lo tengas
(copiar esta carpeta, un USB, o `git init` + remoto propio):

```bash
cd ~/ruta/del/repo/cyberArch-Dotfiles
./install.sh --dry-run     # ves quehara, no cambia nada
./install.sh
```

> Si lo subes a un remoto, sustituye el `git clone` de abajo por tu URL real:
> `git clone https://github.com/<TU-USUARIO>/cyberArch-Dotfiles ~/.dotfiles`

Todavia no tenes Arch instalado: empieza por
[`docs/00-preparar-windows.md`](docs/00-preparar-windows.md) y sigue la cadena
de documentos hasta `04`.

---

## La paleta

Cada color es un personaje. Cambiar el personaje del escritorio es cambiar de
color de acento.

| Personaje | Elemento | Hex | Donde se usa |
|---|---|---|---|
| **Roxy Migurdia** | Agua / Hielo | `#5BC8FF` | acento primario, foco, barras |
| **Eris Boreas Greyrat** | Fuego / Espada | `#FF5F56` | errores, alertas, urgente |
| **Sylphiette** | Viento | `#5FD98A` | exito, red, git limpio |
| **Ghislaine Dedoldia** | Plata | `#C9D4E8` | texto normal |
| **Rudeus Greyrat** | Oro / Magia | `#E0B354` | acento secundario, cwd |
| **Hitogami** | Vacio | `#9B7BD4` | acento terciario, hyprlock |
| **Lara Megmind** | Violeta | `#B47BD4` | notas |
| **Ruijerd** | Obsidiana | `#8C6BD4` | tareas largas |

```bash
mt_persona            # lista los personajes
mt_persona roxy       # cambia el acento del escritorio y la shell
```

---

## Las seis paginas del laberinto

Los workspaces no son numeros, son lugares:

| Tecla | Workspace | Sitio |
|---|---|---|
| `Super+1` | `fittoa` | la sesion principal |
| `Super+2` | `millishion` | lo de Roxy |
| `Super+3` | `asura` | lo de Eris |
| `Super+4` | `sharia` | lo de Sylphie |
| `Super+5` | `bosque` | ventanas apiladas (layout master) |
| `Super+6` | `labyrinth` | sistemas, flotantes grandes |

---

## Atajos principales

| Tecla | Accion |
|---|---|
| `Super` (derecha) | tecla principal |
| `Super+Return` / `Super+T` | terminal |
| `Super+D` | lanzador |
| `Super+E` / `Super+B` | neovim / btop |
| `Super+HJKL` / flechas | mover ventana |
| `Super+Shift+HJKL` | cambiar foco |
| `Super+Alt+flechas` | redimensionar (20 px) |
| `Super+1..6` | paginas del laberinto |
| `Super+M` / `N` / `O` | dwindle / master / tiled |
| `Super+V` / `F` / `P` | flotante / pantalla completa / pseudo |
| `Super+Print` | captura de region al portapapeles |
| `Super+Shift+Print` | captura completa al portapapeles |
| `Super+Ctrl+L` | hyprlock |
| `Super+Shift+Q` | cerrar sesion |
| `Super+,` | recargar Hyprland |
| `Super+.` | activar/desactivar animaciones |

Mapa completo: [`home/.config/hypr/conf.d/binds.conf`](home/.config/hypr/conf.d/binds.conf)

---

## Fondos

Los fondos son **obra original** generada para este repo. Usan la paleta del
tema pero no contienen material del anime, asi que podes distribuirlos sin
problemas.

| Archivo | Tema |
|---|---|
| `fittoa.svg` | atardecer sobre el Gran Bosque (default) |
| `roxy.svg` | magia de agua |
| `eris.svg` | magia de fuego |
| `hitogami.svg` | el dios invisible |
| `sello-orsted.svg` | sello del Laberinto (usado por hyprlock) |

Para usar tus propios fondos (fanarts, capturas):

```bash
cp tu_fondo.png ~/.local/share/wallpapers/mushoku/
hyprctl hyprpaper reload
# o rotarlos cada 15 min:
swww img cycle --time 900 ~/.local/share/wallpapers/mushoku/*
```

`install.sh` convierte los SVG a PNG porque **hyprpaper no lee SVG**.

---

## Arquitectura tecnica

```
Hyprland  ── corre sobre la iGPU Intel UHD (sesion estable, sin problemas Wayland+NVIDIA)
   │
   ├── waybar          barra inferior con workspaces tematizados
   ├── rofi            lanzador (drun / ventanas / power menu)
   ├── dunst           notificaciones
   ├── kitty           terminal con el tema
   └── hyprlock        bloqueo con el sello de Orsted

RTX 3050  ── solo para juegos, via PRIME:
   prime-run steam / prime-run lutris
```

La sesion grafica **no** usa la RTX 3050. Es la combinacion estable en laptops con
GPU hibrida: Intel para el escritorio, NVIDIA unicamente cuando un juego lo exige.

---

## Requisitos

- Arch Linux (o cualquier distro basada en Arch, ajustando el gestor de paquetes)
- UEFI con Secure Boot (esta laptop lo trae activo; la guia usa `shim`)
- Driver de video: `intel-ucode`, `nvidia-dkms`, `mesa`

---

## Licencia

Codigo y recursos originales: MIT.
Los nombres de personajes y el nombre de la obra pertenecen a sus titulares.
Este repo es un homenaje de fan sin vinculo con los titulares de la obra.
