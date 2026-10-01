# Primera instalación — guía autocontenida

Para cuando NO tengas ayuda. Todo lo que necesitas está aquí.
Necesitas: el USB (`UFD 2.0 Silicon-Power8G`), cargador conectado, y la
contraseña de tu WiFi.

---

## Identifica tus discos POR TAMAÑO, no por el nombre

Windows y Arch numeran los discos de forma distinta. **La regla de oro es
el tamaño**, que no cambia:

| Tamaño | Disco en Linux | Contiene en Windows | QUÉ HACER |
|---|---|---|---|
| 476.9 GB | `/dev/nvme0n1` | `C:` | Solo tocar la partición de 100 MB (ESP) |
| 931.5 GB | `/dev/nvme1n1` | `D:` **y** `S:` | Formatear SOLO la de 195 GB |
| 7.2 GB | `/dev/sda` | `F:` (el USB) | Nada, es el arranque |

Compruébalo:

```bash
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT
lsblk -f
```

Debes ver algo así:

```
nvme0n1     476.9G
├─nvme0n1p1   100M   vfat   EFI System Partition   <-- ESP, se monta en /boot/efi
├─nvme0n1p2    16M   swap
└─nvme0n1p3  475.9G   ntfs   C:                     <-- NO TOCAR

nvme1n1     931.5G
├─nvme1n1p1  736.2G   ntfs   D:                     <-- NO TOCAR JAMAS
├─nvme1n1p2    16M
└─nvme1n1p3  195.3G   ntfs   S:                     <-- ESTE es el objetivo
```

### ⚠️ Prohibido absoluto

```bash
# NUNCA hagas esto: borraría D: y S: completos, 931 GB de tu vida
parted /dev/nvme1n1 mklabel gpt
fdisk /dev/nvme1n1     # y luego 'd' sobre la partición equivocada
```

La tabla de particiones de `nvme1n1` ya está perfecta. **No hay que
tocarla.** Solo formateamos `nvme1n1p3`, que ya existe con el tamaño
exacto que quieres.

---

## Paso 1 — Arrancar desde el USB

1. Reinicia con el USB conectado.
2. Entra a la BIOS con `F2` repetidamente al encender.
3. En `Boot`, baja `Boot Option #1` hasta `UFD 2.0 Silicon-Power8G`.
4. **Apaga Secure Boot** (`Secure Boot` → `Disabled`).
   Solo por ahora; se reactiva al final con `sbctl`.
5. Guarda y sal con `F10`.
6. Elige `Arch Linux (bootable USB)` (la primera opción, no la *fallback*).

---

## Paso 2 — WiFi (imprescindible)

`pacstrap` necesita internet para descargar los paquetes.

```bash
iwctl
```

Dentro del prompt de `iwctl`:

```
device list
station wlan0 connect "NOMBRE-DE-TU-WIFI"
# te pedirá la contraseña
quit
```

Confirma que entró:

```bash
ping -c 3 archlinux.org
```

Si `ping` responde, sigue. Si no, revisa que el nombre de la interfaz sea
correcto con `device list`.

Ajusta la hora (si pacstrap se queja de errores de certificado):

```bash
timedatectl set-timezone America/Mexico_City
timedatectl status
```

---

## Paso 3 — Formatear SOLO `S:`

Comprueba primero el tamaño de la partición. Debe decir ~195 GB:

```bash
parted /dev/nvme1n1 unit GB print
```

Confirma que `nvme1n1p3` mide ~195 GB y que `nvme1n1p1` mide ~736 GB.

Luego:

```bash
mkfs.ext4 -L arch /dev/nvme1n1p3
```

> Esto destruye lo que hubiera en `S:`. Dijiste que no te importa.
> No toca `D:`. No toca `C:`. No toca la tabla de particiones.

Comprueba que salió bien:

```bash
blkid /dev/nvme1n1p3
# debe mostrar TYPE="ext4" LABEL="arch"
```

---

## Paso 4 — Montar

```bash
mount /dev/nvme1n1p3 /mnt

# La partición EFI es la de 100 MB del disco de 476 GB, compartida con Windows
mkdir -p /mnt/boot
mkdir -p /mnt/boot/efi
mount /dev/nvme0n1p1 /mnt/boot/efi

# que sea de 100 MB
ls /mnt/boot/efi
# debe listar: EFI  Microsoft
```

Si `ls` **no** muestra `EFI`, te equivocaste de partición. Para atrás.

Ojo: `/mnt/boot` y `/mnt/boot/efi` son dos cosas distintas. `/boot` es la
raíz de Arch; `/boot/efi` es el EFI compartido con Windows.

---

## Paso 5 — Sistema base

```bash
pacstrap -K /mnt base linux linux-firmware intel-ucode
```

`intel-ucode` es el microcódigo de tu i5-11400H. Sin él el CPU puede
inestabilizarse.

Esto tarda 5-15 minutos y descarga ~500 MB.

```bash
genfstab -U /mnt >> /mnt/etc/fstab
cat /mnt/etc/fstab
```

Debe tener 3 líneas que mencionen `/`, `/boot` y `/boot/efi`. Si falta
alguna, no sigas.

---

## Paso 6 — Configurar dentro del chroot

```bash
arch-chroot /mnt
```

Ahora el prompt cambia a `[root@archiso /]#`.

### Hora y nombre

```bash
ln -sf /usr/share/zoneinfo/America/Mexico_City /etc/localtime
hwclock --hctosys
echo "fittoa" > /etc/hostname
```

### Localización

```bash
echo 'LANG=es_MX.UTF-8' > /etc/locale.conf
echo 'KEYMAP=la-latin1' > /etc/vconsole.conf
```

### Contraseñas

```bash
passwd                 # root
```

### Tu usuario

```bash
useradd -m -G wheel,audio,video,storage,power,input,network,usb,bluetooth,printer -s /bin/bash rudeus
passwd rudeus
```

### Que `rudeus` pueda usar sudo

```bash
EDITOR=nano visudo
```

Busca la línea que empieza por `%wheel` (suele estar al final, o comentada
con `#`) y quítale el `#` para que quede:

```
%wheel ALL=(ALL:ALL) ALL
```

Guarda en nano con `Ctrl+O`, `Enter`, y sal con `Ctrl+X`.

### Red (NetworkManager, lo más fácil)

```bash
pacman -S --needed networkmanager
systemctl enable NetworkManager
```

---

## Paso 7 — Kernel y microcódigo

Abre el initramfs:

```bash
nano /etc/mkinitcpio.conf
```

En la línea `HOOKS=(...)` debe incluir `microcode`. Déjala así (los demás
hooks se conservan):

```
HOOKS=(base microcode udev autodetect modconf kms keyboard keymap console-font)
```

Genera el initramfs:

```bash
mkinitcpio -P
```

Debe terminar con algo parecido a `initramfs-linux.img generado`.

---

## Paso 8 — GRUB (arranque desde la ESP compartida)

```bash
pacman -S --needed grub efibootmgr
```

```bash
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --modules="part_gpt fat ext4"
```

Debe decir `Installation finished. No error reported.`

Regístralo en el firmware:

```bash
efibootmgr --create --disk /dev/nvme0n1 --part 1 --label ARCH --loader '\EFI\GRUB\grubx64.efi'
```

Mira que existan ambas entradas (Windows y Arch):

```bash
efibootmgr -v
```

Debes ver `Windows Boot Manager` y `ARCH`. Si no aparece `ARCH`, repite el
`efibootmgr --create` de arriba.

> No usamos `--removable`: escribir en `EFI/BOOT/BOOTX64.EFI` puede pisar el
> cargador de Windows en la ESP compartida.

---

## Paso 9 — Red de arranque (imprescindible, si no, no tendrás red)

Dentro del chroot, para que el sistema encuentre la wifi al arrancar:

```bash
cat > /etc/systemd/network/20-wifi.network <<'EOF'
[Match]
Name=wlan0 wlp*wl* enp*

[Network]
DHCP=yes
EOF

pacman -S --needed iwd
systemctl enable iwd
systemctl enable systemd-networkd
```

> Si al arrancar tu interfaz se llama distinto, edita el `Name=` y pon el
> nombre real (lo ves con `ip link`).

---

## Paso 10 — Salir y reiniciar

```bash
exit
```

Vuelves al prompt del instalador. Antes de reiniciar, **desmonta**:

```bash
umount -R /mnt
sync
```

```bash
reboot
```

---

## Si aparece el menú de arranque

Deberías ver `arch` y `Windows Boot Manager`. Elige `arch` con las flechas.

Para que Arch sea el primero:

1. `F2` en el próximo reinicio
2. En `Boot`, `Boot Option #1` = `arch`
3. `F10` para guardar

Para volver a Windows: quita `arch` del `Boot Option #1`, o usa `F12` en el
arranque y elige `Windows Boot Manager`.

---

## Si arranca y quieres internet ya

```bash
sudo ip link set wlan0 up
sudo iwctl device wlan0 connect "TU-WIFI"
```

O, más fácil, con NetworkManager ya debería estar:

```bash
nmcli device wifi list
nmcli device wifi connect "TU-WIFI" password "TU-PASSWORD"
```

---

## Primeros pasos tras el primer arranque

```bash
sudo pacman -Syu
```

Después sigue `docs/02-postinstall.md` (NVIDIA/PRIME, ASUS, Hyprland) y
luego el tema con `./install.sh`.

---

## Resumen en un bloque

```bash
# WiFi
iwctl
#   station wlan0 connect "TU-WIFI"

# Formatear S: (NO el de 736 GB)
mkfs.ext4 -L arch /dev/nvme1n1p3

# Montar
mount /dev/nvme1n1p3 /mnt
mkdir -p /mnt/boot/efi
mount /dev/nvme0n1p1 /mnt/boot/efi

# Base
pacstrap -K /mnt base linux linux-firmware intel-ucode
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt

# Dentro:
ln -sf /usr/share/zoneinfo/America/Mexico_City /etc/localtime
echo fittoa > /etc/hostname
echo 'LANG=es_MX.UTF-8' > /etc/locale.conf
echo 'KEYMAP=la-latin1' > /etc/vconsole.conf
passwd
useradd -m -G wheel,audio,video,storage,power,input,network,usb -s /bin/bash rudeus
passwd rudeus
EDITOR=nano visudo            # descomenta %wheel ALL=(ALL:ALL) ALL
pacman -S --needed networkmanager iwd
systemctl enable NetworkManager iwd systemd-networkd
# nano /etc/mkinitcpio.conf  -> anade 'microcode' a HOOKS
mkinitcpio -P
pacman -S --needed grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --modules="part_gpt fat ext4"
efibootmgr --create --disk /dev/nvme0n1 --part 1 --label ARCH --loader '\EFI\GRUB\grubx64.efi'
exit

umount -R /mnt
sync
reboot
```

---

## Errores frecuentes

| Síntoma | Causa | Solución |
|---|---|---|
| No aparece `wlan0` | Falta el firmware | `pacstrap -K /mnt base linux linux-firmware` (el firmware va en la base, no en el host) |
| `pacstrap` falla con errores de certificado | Reloj desfasado | `timedatectl set-timezone America/Mexico_City` y `hwclock --hctosys` |
| No arranca tras instalar | Secure Boot quedó activo | Vuelve a la BIOS y ponlo en `Disabled` |
| `grub-install` dice que no encuentra ESP | Montaste mal | `ls /mnt/boot/efi` debe mostrar `EFI` |
| Pantalla negra / se congela | Falta `intel-ucode` | `mkinitcpio -P` y `grub-install` de nuevo |
| No ves `arch` en el menú | No se registró | Repite `efibootmgr --create ...` |