# 02 · Post-instalacion

De un Arch recien instalado a una sesion Hyprland con tema Mushoku Tensei.
Sigue los bloques en orden: cada uno depende del anterior.

---

## 2.0 · Logueate primero

```bash
rudeus@fittoa
[root password]
[rudeus password]
```

Actualiza el sistema y el shell por defecto:

```bash
sudo pacman -Syu

sudo chsh -s /bin/bash rudeus
```

---

## 2.1 · GPU · el nucleo de la laptop

Tu laptop es hibrida: Intel UHD 11th gen (sesion) + RTX 3050 Laptop (juegos).
La sesion Wayland corre **solo con Intel**. Es la combinacion estable: NVIDIA
en Wayland todavia tiene problemas de sincronizacion y tearing.

```bash
sudo pacman -S --needed \
    mesa vulkan-intel libva-intel-driver intel-media-driver \
    nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings \
    gst-plugin-nvdec gstreamer-vaapi switcheroo-control
```

### Parametros de arranque

```bash
sudo nano /etc/kernel/cmdline
```

Reemplaza todo el contenido por:

```
root=UUID=TU_UUID_DE_RAIZ rw
```

Agrega al final:

```
quiet loglevel=3 rd.systemd.show_status=auto
```

Y despues, parametros de modulos:

```bash
sudo mkdir -p /etc/modprobe.d
sudo tee /etc/modprobe.d/xe-nvidia-powersave.conf > /dev/null <<'EOF'
# NVIDIA: permitir gestion de energia cuando no se usa
options nvidia_dkms power_suppression=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia_drm modeset=1
EOF
```

Verifica que toma los parametros:

```bash
cat /etc/kernel/cmdline
```

### mkinitcpio

```bash
sudo nano /etc/mkinitcpio.conf
```

Tu `/etc/mkinitcpio.conf` deberia verse asi:

```ini
MODULES=(intel-ucode)
# Uncomment 'microcode' hook if you use Intel CPU
HOOKS=(base microcode udev autodetect modconf kms keyboard keymap console_font block filesystems fsck)
```

```bash
sudo mkinitcpio -P
```

> Si `/etc/kernel/cmdline` no existe en tu instalacion (algunos `archinstall`
> lo omiten), crealo con la UUID de tu raiz:
> ```bash
> echo "root=UUID=$(blkid -s UUID -o value /dev/nvme1n1p3) rw" | sudo tee /etc/kernel/cmdline
> ```

---

## 2.2 · NVIDIA PRIME · usar la RTX 3050 para juegos

Arch usa `switcheroo-control` para PRIME. Verifica las dos GPUs:

```bash
lspci -k | grep -A 3 -Ei 'VGA|3D controller'
```

Deberias ver:

```
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation ... [GeForce RTX 3050]
        Kernel driver in use: nvidia
0a:00.0 VGA compatible controller [0300]: Intel Corporation ... [UHD Graphics]
        Kernel driver in use: i915
```

Forzar NVIDIA bajo demanda para apps concretas:

```bash
mkdir -p ~/.config
tee ~/.config/prime-run.conf > /dev/null <<'EOF'
# prime-run.conf: rutas que deben correr con la NVIDIA
# Vive en el HOME del usuario, no en /etc
/usr/bin/steam
/usr/bin/gamescope
EOF
```

> **Ojo:** `prime-run` lee `~/.config/prime-run.conf` (por usuario), **no**
> `/etc/prime-run.conf` ni `/etc/prime-run.conf.d`. Ese archivo en `/etc` no lo
> lee nada.

`switcheroo-control` se activa **por D-Bus**, no es un servicio de systemd:
**no** hay que hacer `systemctl enable` ni crear overrides. `switcherooctl` lo
levanta solo cuando lo invocas.

Comprueba que PRIME ofrece las dos:

```bash
switcherooctl list
```

Deberia dar:

```
Device: 0
  Description: Mesa IntelGraphics
  Vendor: Intel
  Driver: i915
Device: 1
  Description: NVIDIA GeForce RTX 3050 Laptop GPU
  Vendor: NVIDIA
  Driver: nvidia
```

Probalo:

```bash
prime-run glxinfo -B     # debe decir "NVIDIA Corporation" (si lo compilas con NVIDIA)
prime-run nvidia-smi     # informacion de la RTX
```

Si `glxinfo` no esta compilado con NVIDIA, `prime-run nvidia-smi` basta como
prueba de que el offload funciona.

### Sustituto de `prime-run` (opcional)

```bash
sudo pacman -S supergfxctl
sudo supergfxctl -s hybrid
```

Esto ademas te deja elegir el perfil de energia:

```bash
supergfxctl -p balanced
supergfxctl -p performance
```

---

## 2.3 · Audio · Intel SST + Realtek

Tu Realtek usa un codec **Soficiniado** (SOF), que necesita firmware de
`alsa-firmware`:

```bash
sudo pacman -S --needed \
    pipewire pipewire-jack pipewire-alsa wireplumber \
    alsa-firmware alsa-utils pavucontrol playerctl wireplumber-tui
```

Crea el override de WirePlumber para que no toque el volumen de la microfono:

```bash
sudo mkdir -p /etc/wireplumber/wireplumber.conf.d
sudo tee /etc/wireplumber/wireplumber.conf.d/50-mushoku.conf > /dev/null <<'EOF'
monitor.alsa-restore-session = false
monitor.alsa-store-session = false
```

Si no sale audio, mira el kernel log:

```bash
sudo dmesg | grep -i snd | tail -30
```

Verificacion:

```bash
wpctl status
```

---

## 2.4 · WiFi · MediaTek MT7921

El MT7921 funciona directo con el driver `mt7921e` del kernel (5.15+) y con
`linux-firmware`. NetworkManager + iwd es la combinacion mas estable en
laptops.

```bash
sudo pacman -S --needed networkmanager networkmanager-applet \
    networkmanager-wifi iwd wireless_regdb iw
```

El kernel nuevo (6.x) usa la familia `mt7925e`, no `mt7921e`:

```bash
lsmod | grep mt79
# deberia mostrar mt7925e / mt7925_common / mt76_connac
```

Si tu kernel fuera antiguo o el firmware faltara:

```bash
sudo pacman -S --needed linux-firmware-other
```

---

## 2.5 · ASUS TUF · asusctl

```bash
sudo pacman -S asusctl brightnessctl
```

Lo que controla en esta laptop:

```bash
asusctl                       # ver todo
asusctl kbd_led get           # nivel de luz del teclado
asusctl kbd_led set 2
asusctl set_charge_limit_start 60    # deja de cargar al 60%
asusctl set_charge_limit_end 80
```

Aplica el limite de bateria automaticamente:

```bash
sudo systemctl enable asusctl-charge-limit.service   # si existe
# o
sudo tee /etc/systemd/system/asus-charge-limit.service > /dev/null <<'EOF'
[Unit]
Description=Limite de carga de bateria al 60% (ASUS TUF)
After=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/asusctl set_charge_limit 60

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable --now asus-charge-limit.service
```

### Frecuencia y perfiles energeticos

```bash
sudo pacman -S power-profiles-daemon
sudo systemctl enable power-profiles-daemon

powerprofilesctl list
powerprofilesctl set performance     # cuando estas jugando con la RTX
powerprofilesctl set balanced        # uso normal
powerprofilesctl set power-saver     # en la batería
```

---

## 2.6 · Touchpad · ASUS Precision

El touchpad es ELAN por I2C, debería funcionar solo. Si no:

```bash
sudo modprobe elants_i2c
echo "elants_i2c" | sudo tee /etc/modules-load.d/touchpad.conf
```

```bash
# En Hyprland ya esta configurado con natural-scroll y tap-to-click
# Verifica:
sudo libinput list-devices | grep -A5 "ELAN"
```

---

## 2.7 · Ethernet · Realtek GbE

```bash
sudo pacman -S r8169-dkms      # si el driver del kernel falla
# o prueba el de Realtek cerrado:
sudo pacman -S r8168-dkms
```

En el 90% de los casos `r8169` del kernel funciona sin tocar nada.

---

## 2.8 · El compositor · Hyprland

```bash
sudo pacman -S --needed \
    hyprland hyprpaper hyprlock hypridle hyprcursor \
    waybar xdg-desktop-portal-hyprland wtype \
    dunst rofi kitty \
    grim slurp swappy wl-clipboard \
    fonts-jetbrains-mono ttf-jetbrains-mono-nerd noto-fonts-emoji \
    qt5-wayland qt6-wayland
```

### Fuentes de iconos y temas (recomendado)

```bash
sudo pacman -S --needed papirus papirus-icon-theme \
    ttf-font-awesome-adl-nerd
```

Si quieres una GTK oscura completa:

```bash
sudo pacman -S --needed adw-gtk-theme kvantum
```

### Sesion de escritorio para el login

```bash
sudo mkdir -p /usr/share/wayland-sessions
sudo tee /usr/share/wayland-sessions/hyprland.desktop > /dev/null <<'EOF'
[Desktop Entry]
Name=Hyprland (Mushoku Tensei)
Comment=Escritorio Hyprland con tema Mushoku Tensei
Exec=Hyprland
Type=Application
DesktopNames=Hyprland
EOF
```

### Gestor de sesion grafica

Instala uno o ninguno. Puedes arrancar la sesion direct desde TTY con `Hyprland`.

```bash
sudo pacman -S --needed greetd greetd-tuigreet
```

```bash
sudo tee /etc/greetd/config.toml > /dev/null <<'EOF'
[terminal]
vt = 1

[default_session]
# tuigreet necesita --command para lanzar la sesion, y un usuario REAL.
command = "tuigreet --time --remember --greeting 'Fittoa :: el Continente Magico' --command Hyprland"
user = "greeter"
EOF
```

**Crea el usuario `greeter`** si no existe, o la sesion fallara al arrancar:

```bash
sudo useradd -m -G wheel,audio,video,input,storage,power,network,usb,rfkill -s /bin/bash greeter
sudo passwd greeter
```

`greetd` toma el control de la VT1, asi que **toma `wheel`**: es como conectas
el cable de red si Hyprland no arranca y necesitas entrar.

```bash
sudo systemctl enable --now greetd
```

> No instales a mano un `.desktop` en `/usr/share/wayland-sessions/`: el paquete
> `hyprland` ya trae `hyprland.desktop` y greetd lo encuentra solo.
> Si prefieres no usar gestor de sesion, desactiva greetd (`systemctl disable
> --now greetd`) y arranca Hyprland desde TTY con `Hyprland`.

### Configura Hyprland ahora

```bash
mkdir -p ~/.config/hypr
cp -r ~/.dotfiles/home/.config/hypr/* ~/.config/hypr/

# Fondos
mkdir -p ~/.local/share/wallpapers/mushoku
cp ~/.dotfiles/assets/wallpapers/*.svg ~/.local/share/wallpapers/mushoku/
cd ~/.local/share/wallpapers/mushoku
for f in *.svg; do rsvg-convert -w 1920 -h 1080 -o "${f%.svg}.png" "$f"; done
```

> No instales un paquete `librsvg` explicitamente: `rsvg-convert` viene con
> `librsvg` que `hyprpaper` ya requiere.

---

## 2.9 · Autologin (opcional)

```bash
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf > /dev/null <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin rudeus --noclear %I 38400x38400 vt1
Type=idle
EOF

sudo systemctl daemon-reload
```

> Con autologin NO hay contrasena al abrir la sesion. `hyprlock` protege la
> sesion viva, pero cualquiera con acceso fisico al teclado puede reiniciar y
> entrar directo. Decide tu si es aceptable.

---

## 2.10 · Los dotfiles

```bash
cd ~/.dotfiles
./install.sh --dry-run
./install.sh
```

Ver [`README.md`](../README.md) para el detalle.

---

## 2.11 · Verificacion final

```bash
hyprctl version
waybar --version
echo $XDG_SESSION_TYPE      # debe decir: wayland
glxinfo -B | grep "OpenGL renderer"    # Intel
prime-run glxinfo -B | grep "OpenGL renderer"   # NVIDIA
```

Si todo dice lo correcto, cierra Windows desde el menu de GRUB y sientete
orgulloso. Siguiente: [`03-tema-mushoku-tensei.md`](03-tema-mushoku-tensei.md)

---

## 2.12 · Resumen de paquetes instalados

| Area | Paquetes |
|---|---|
| **Boot** | `grub` `shim` `efibootmgr` `os-prober` |
| **Microcodigo** | `intel-ucode` |
| **GPU Intel** | `mesa` `vulkan-intel` `libva-intel-driver` `intel-media-driver` |
| **GPU NVIDIA** | `nvidia-dkms` `nvidia-utils` `lib32-nvidia-utils` `switcheroo-control` |
| **Red** | `networkmanager` `networkmanager-wifi` `iwd` `wireless_regdb` |
| **Audio** | `pipewire` `pipewire-jack` `wireplumber` `alsa-firmware` |
| **ASUS** | `asusctl` `brightnessctl` |
| **Escritorio** | `hyprland` `hyprpaper` `hyprlock` `hypridle` `waybar` `rofi` `dunst` `kitty` |
| **Herramientas** | `ripgrep` `fd` `bat` `eza` `fzf` `zoxide` `fastfetch` `btop` `thunar` `nvim` |
| **Capturas** | `grim` `slurp` `swappy` `wl-clipboard` |
| **Fuentes** | `ttf-jetbrains-mono-nerd` `noto-fonts-emoji` `otf-noto-cjk` |
