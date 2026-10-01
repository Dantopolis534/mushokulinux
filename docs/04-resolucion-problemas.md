# 04 · Resolucion de problemas

Sintoma → causa → solucion. Ordenado por frecuencia real.

---

## Arranque

### El menu de GRUB no aparece

**Causa:** Secure Boot esta rechazando `grubx64.efi` porque no esta firmado.

```bash
# Monta la ESP y revisa
mount /dev/nvme0n1p1 /mnt
ls -R /mnt/EFI/
```

Debes ver:

```
/mnt/EFI/arch/shimx64.efi
/mnt/EFI/arch/mmx64.efi
/mnt/EFI/arch/grubx64.efi
/mnt/EFI/GRUB/grubx64.efi
/mnt/EFI/Microsoft/Boot/bootmgfw.efi
```

Si `shimx64.efi` no esta, reinstalalo:

```bash
sudo pacman -S shim
sudo mkdir -p /boot/efi/EFI/arch
sudo cp /usr/share/shim/x64/{shimx64,mmx64,fbx64}.efi /boot/efi/EFI/arch/
sudo cp /boot/efi/EFI/GRUB/grubx64.efi /boot/efi/EFI/arch/
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

Si el problema sigue siendo Secure Boot, desactivalo en el BIOS y reinstala GRUB
**sin** Secure Boot:

```bash
sudo grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

---

### GRUB no muestra Windows

```bash
# 1. Verifica que os-prober esta habilitado
grep OS_PROBER /etc/default/grub
# debe decir: GRUB_DISABLE_OS_PROBER=false

# 2. Regenera
sudo grub-mkconfig -o /boot/grub/grub.cfg

# 3. Confirma que Windows sigue en la ESP
ls /boot/efi/EFI/Microsoft/Boot/bootmgfw.efi
```

Si el archivo de Windows no esta en tu ESP, quiza Windows lo tenga en otro
disco:

```bash
sudo mount /dev/nvme1n1p1 /mnt   # si tu ESP esta en el otro disco
find /mnt/EFI -name 'bootmgfw.efi'
```

---

### Arch arranca pero `emergency shell`

**Causa:** UUID equivocado en `/etc/kernel/cmdline`, o falta el modulo de
microcodigo en el initramfs.

```bash
# En el shell de emergencia, monta el sistema
mount /dev/nvme1n1p3 /mnt
mount /dev/nvme0n1p1 /mnt/boot/efi
arch-chroot /mnt

# Revisa la UUID
cat /etc/kernel/cmdline
blkid -s UUID -o value /dev/nvme1n1p3

# Corrige
echo "root=UUID=LA_UUID_CORRECTA rw" > /etc/kernel/cmdline

# Reconstruye el initramfs
grep -E 'MODULES|HOOKS' /etc/mkinitcpio.conf
# MODULES=(intel-ucode)
# HOOKS=(base microcode udev autodetect modconf kms keyboard keymap console_font block filesystems fsck)
mkinitcpio -P
```

---

### Pantalla negra despues del logo

```bash
# 1. Desactiva el logo de la GPU
sudo nano /etc/kernel/cmdline
# agrega al final:  video=efifb:off   (o quita nvidia-drm modeset=1 temporalmente)

# 2. Si cambiaste algo de NVIDIA, recompila
sudo mkinitcpio -P

# 3. O arranca en modo texto puro
sudo nano /etc/kernel/cmdline
# quita "quiet" y "splash"
```

---

## Grafica

### La sesion va lenta, hay tirones

**Causa 1:** se esta usando la RTX 3050 para la sesion en vez de Intel.

```bash
glxinfo -B | grep "OpenGL renderer"
```

Si dice NVIDIA, forzalo a Intel:

```bash
# prime-run.conf vive en el HOME, no en /etc ni en /etc/gdm
nano ~/.config/prime-run.conf
```

**Causa 2:** falta el parametro de modeset de NVIDIA.

```bash
# El modulo es nvidia_drm, no nvidia_dkms:
#   /etc/modprobe.d/nvidia.conf
#     options nvidia_drm modeset=1
# El nombre de la opcion NO lleva el punto: nvidia_drm.modeset es el parametro
# de linea de comandos del kernel, no una opcion de modprobe.
grep -r modeset /etc/modprobe.d/
```

**Causa 3:** compositing por software.

```bash
# Debe decir "Intel" y "GLX" o "Wayland", nunca "softpipe"
glxinfo -B
echo $LIBGL_ALWAYS_SOFTWARE   # vacio es lo correcto
```

**Causa 4:** escalado por software. A 1080p con `scale=1.25` Hyprland renderiza
a 2400x1350 y escala. En una Intel UHD eso pesa.

```bash
# Opcion rapida: renderiza a nativo
nano ~/.config/hypr/conf.d/monitor.conf
monitor = eDP-1, 1920x1080@144, position auto, 1
hyprctl reload
```

---

### No arranca `nvidia-dkms`

```bash
uname -r
dkms status
ls /usr/lib/modules/$(uname -r)/build/
```

Si el directorio `build` no existe, no tenes los headers:

```bash
sudo pacman -S linux-headers
sudo mkinitcpio -P
```

Si falla al compilar:

```bash
sudo pacman -S nvidia-dkms
sudo dkms autoinstall
dmesg | grep -i nvidia | head -30
```

---

### En juegos sale "no Vulkan device"

```bash
vulkaninfo --summary
```

Debe listar tu Intel. Si no:

```bash
sudo pacman -S vulkan-intel vulkan-icd-loader
sudo modprobe i915
```

El driver de la iGPU en 11th gen necesita **Guc**:

```bash
echo "options i915 enable_guc=3" | sudo tee /etc/modprobe.d/i915.conf
```

---

## Red

### La MT7921 no aparece

```bash
rfkill unblock wifi
ip link set wlan0 up
ip addr
```

Si sigue igual:

```bash
lsmod | grep mt79
dmesg | grep -i mt7921
```

En los ultimos kernels el driver se llama `mt7925e` (renombrado desde
`mt7921e`). Si no carga:

```bash
sudo modprobe mt7925e
```

O falta el firmware:

```bash
ls /usr/lib/firmware/mediatek/mediatek/mt7921e.bin
sudo pacman -S --needed linux-firmware
sudo modprobe -r mt7925e && sudo modprobe mt7925e
```

Para ver si funciona:

```bash
iw dev wlan0 scan | grep SSID
```

---

### NetworkManager no levanta la interfaz

```bash
systemctl status NetworkManager
nmcli general status
nmcli device wifi list
```

En_AVISO: si tienes otro gestor (Networkd, connman, dhcpcd) corriendo, matalo:

```bash
sudo systemctl disable --now systemd-resolved   # solo si lo usas de otra forma
systemctl list-units | grep -Ei 'networkmanager|systemd-networkd|connman|iwd'
```

---

### DNS no resuelve

```bash
cat /etc/resolv.conf
```

Si es un symlink a `stub-resolv.conf` y no resuelve:

```bash
sudo systemctl restart systemd-resolved
resolvectl status
resolvectl query archlinux.org
```

---

## Audio

### No hay sonido

```bash
wpctl status
```

Lista vacia = el cable de WirePlumber no arrancó:

```bash
systemctl --user restart wireplumber
systemctl --user restart pipewire pipewire-pulse
```

SOF (el codec Realtek de esta laptop) necesita firmware:

```bash
ls /usr/lib/firmware/sof/
sudo pacman -S alsa-firmware
```

Microfono no funciona (un bug de PipeWire con duplex):

```bash
# Crea el override de WirePlumber
mkdir -p ~/.config/wireplumber/wireplumber.conf.d
cat > ~/.config/wireplumber/wireplumber.conf.d/50-mic.conf <<'EOF'
monitor.alsa-restore-session = false
pulse.client.enable-mute = false
pulse.client.enable-volume = false
EOF

systemctl --user restart wireplumber
```

---

## Suspender

### No se suspende, o al reanudar se congela

Es el problema clasico de NVIDIA hibrida:

```bash
cat /sys/module/nvidia/parameters/NVreg_PreserveVideoMemoryAllocations
# si dice N: falta el parametro
```

```bash
sudo mkdir -p /etc/modprobe.d
echo "options nvidia NVreg_PreserveVideoMemoryAllocations=1" \
  | sudo tee /etc/modprobe.d/nvidia-power.conf
sudo mkinitcpio -P
```

Verifica que el parametro esta:

```bash
cat /proc/driver/nvidia/params | grep -i preserve
```

---

## Escritorio

### Hyprland no arranca

```bash
cat /etc/hypr/hyprland.conf   # config global
~/.config/hypr/hyprland.conf  # config de usuario
```

Como empezar de cero:

```bash
mv ~/.config/hypr/hyprland.conf ~/.config/hypr/hyprland.conf.bak
hyprland
# Si abre una sesion minima, el problema esta en tu config.
```

Si el problema es un modulo de `conf.d/`:

```bash
mv ~/.config/hypr/conf.d/theme.conf ~/.config/hypr/conf.d/theme.conf.bak
hyprctl reload
```

### El wallpaper no cambia

```bash
hyprctl hyprpaper status
ls ~/.local/share/wallpapers/mushoku/
```

Hyprpaper no lee SVG:

```bash
rsvg-convert -w 1920 -h 1080 -o ~/salida.png entrada.svg
```

### La barra no aparece

```bash
waybar &
tail -f /tmp/waybar.log
```

Causas comunes:

```bash
# Falta el modulo custom
ls -l ~/.local/bin/mt-temperatura
chmod +x ~/.local/bin/mt-temperatura

# Falta fuente de iconos
fc-list | grep "Nerd Font" | head
sudo pacman -S ttf-font-awesome-adl-nerd

# Waybar >= 0.11 necesita el modulo "backlight" con intel
```

### El prompt sale raro / sin color

```bash
echo $TERM          # debe decir algo con -256color o kitty
echo $SHELL
source ~/.config/shell/mushoku-prompt.sh
```

En kitty el TERM es `xterm-kitty`. En TTY es `linux` y los colores RGB no
funcionan: por eso el prompt usa secuencias ANSI de 24 bits, que tampoco se ven
bien en TTY pero no rompen nada.

---

## Comandos de diagnostico rapido

```bash
# Sistema completo
mt_diagnostico

# Solo GPUs
lspci -k | grep -A3 -Ei 'VGA|3D'

# Log del kernel en vivo (lo mas util)
sudo dmesg -w

# Hyprland en detalle
hyprctl monitors
hyprctl devices
hyprctl version

# Driver en uso
prime-run glxinfo -B   # NVIDIA
glxinfo -B              # Intel

# Quien esta usando la GPU
watch -n1 nvidia-smi
```

---

## Reiniciar sin miedo

```bash
# Los drivers
sudo mkinitcpio -P

# El bootloader
sudo grub-mkconfig -o /boot/grub/grub.cfg

# Los servicios
sudo systemctl daemon-reload
sudo systemctl restart NetworkManager

# Hyprland
hyprctl reload

# Todo
sudo reboot
```

---

## Nuclear: volver a instalador

Si la laptop no arranca:

1. USB de Arch conectado
2. Reinicia, entra al BIOS con `F2`, pon el USB primero
3. Monta Windows:

```bash
mount /dev/nvme0n1p1 /mnt          # ESP
mkdir -p /mnt/EFI/Microsoft/Boot  # el directorio tiene que existir
mount /dev/nvme0n1p3 /mnt2          # C:
```

Si la ESP de Windows esta en otro disco:

```bash
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT
# busca la de 100 MB con FAT32
```

4. Reinstala GRUB:

```bash
grub-install --target=x86_64-efi --efi-directory=/mnt --bootloader-id=GRUB
grub-mkconfig -o /mnt/EFI/GRUB/grub.cfg
umount -R /mnt
reboot
```

O como plan B, arranca Windows y repara el arranque desde PowerShell
(administrador):

```powershell
mountvol C: /S
bcdboot C:\Windows /s C: /f UEFI
mountvol C: /D
```
